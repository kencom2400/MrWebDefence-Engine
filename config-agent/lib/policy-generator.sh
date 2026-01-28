#!/bin/bash

# OpenAppSecポリシー生成スクリプト
# JSONデータからlocal_policy.yamlを生成

set -e

# OpenAppSec設定ファイル（local_policy.yaml）を生成
generate_openappsec_policy() {
    local config_data="$1"
    local output_file="$2"
    
    if [ -z "$config_data" ] || [ -z "$output_file" ]; then
        echo "❌ エラー: 引数が不足しています" >&2
        return 1
    fi
    
    # 出力ディレクトリを作成
    mkdir -p "$(dirname "$output_file")"
    
    # JSON形式の検証
    if ! echo "$config_data" | jq empty 2>/dev/null; then
        local json_error
        json_error=$(echo "$config_data" | jq . 2>&1 | head -5 || echo "JSONパースエラー")
        echo "❌ エラー: 設定データが有効なJSON形式ではありません" >&2
        echo "❌ JSONエラー詳細: $json_error" >&2
        return 1
    fi
    
    # デフォルトモードを取得（jqで安全に取得）
    local default_mode
    default_mode=$(echo "$config_data" | jq -r '.default_mode // "detect-learn"')
    if [ $? -ne 0 ] || [ -z "$default_mode" ]; then
        echo "❌ エラー: default_modeの取得に失敗しました" >&2
        return 1
    fi
    
    # デフォルトモードの検証（YAML Injection対策）
    if ! echo "$default_mode" | grep -qE '^(detect-learn|prevent-learn|detect|prevent|inactive)$'; then
        echo "❌ エラー: 無効なdefault_mode: $default_mode" >&2
        return 1
    fi
    
    # デフォルトカスタムレスポンスを取得（jqで安全に取得）
    local default_custom_response
    default_custom_response=$(echo "$config_data" | jq -r '.default_custom_response // 403')
    if [ $? -ne 0 ] || [ -z "$default_custom_response" ]; then
        echo "❌ エラー: default_custom_responseの取得に失敗しました" >&2
        return 1
    fi
    
    # デフォルトカスタムレスポンスの検証（YAML Injection対策）
    if ! echo "$default_custom_response" | grep -qE '^[0-9]+$'; then
        echo "❌ エラー: 無効なdefault_custom_response: $default_custom_response" >&2
        return 1
    fi
    
    # FQDN別設定（specificRules）を生成
    # 必須フィールドの検証: .fqdnは必須、欠落している場合はエラー
    local fqdns_check
    fqdns_check=$(echo "$config_data" | jq -r '.fqdns[]? | select(.is_active == true) | if .fqdn == null or .fqdn == "" then "ERROR: fqdn is required" else empty end' 2>/dev/null)
    if [ -n "$fqdns_check" ]; then
        echo "❌ エラー: FQDN設定に必須フィールド（fqdn）が欠落しています" >&2
        echo "❌ エラー詳細: $fqdns_check" >&2
        return 1
    fi
    
    local specific_rules_json
    local jq_error
    jq_error=$(mktemp)
    trap 'rm -f -- "$jq_error"' RETURN
    specific_rules_json=$(echo "$config_data" | jq -r '.fqdns[]? | select(.is_active == true) | {
        host: .fqdn,
        mode: (.waf_mode // "detect-learn"),
        customResponse: (.custom_response // 403),
        accessControlPractice: (.access_control_practice // "rate-limit-default")
    }' 2>"$jq_error" | jq -s '.' 2>>"$jq_error")
    local jq_status=$?
    
    if [ $jq_status -ne 0 ]; then
        local error_msg
        error_msg=$(cat "$jq_error" 2>/dev/null || echo "jqエラー")
        echo "❌ エラー: FQDN設定の取得に失敗しました" >&2
        echo "❌ jqエラー詳細: $error_msg" >&2
        trap - RETURN
        rm -f "$jq_error"
        return 1
    fi
    
    # 生成されたJSONが空でないことを確認
    if [ -z "$specific_rules_json" ] || [ "$specific_rules_json" = "[]" ]; then
        echo "⚠️  警告: 有効なFQDN設定がありません（空の配列）" >&2
        # 空の配列でも処理は続行（デフォルト設定のみが適用される）
    fi
    
    trap - RETURN
    rm -f "$jq_error"
    
    # accessControlPracticesの使用判定（rateLimit設定がある場合は使用）
    local use_access_control="false"
    if echo "$specific_rules_json" | jq -e '.[] | select(.accessControlPractice != null and .accessControlPractice != "")' >/dev/null 2>&1; then
        use_access_control="true"
    fi
    
    # threatPreventionPracticesの使用判定（prevent/prevent-learnモードの場合は使用）
    local use_threat_prevention="false"
    if [[ "$default_mode" == "prevent"* ]] || echo "$specific_rules_json" | jq -e '.[] | select(.mode | startswith("prevent"))' >/dev/null 2>&1; then
        use_threat_prevention="true"
    fi
    
    # accessControlPracticesの生成（rateLimit設定がある場合）
    local default_access_control="[]"
    if [ "$use_access_control" = "true" ]; then
        default_access_control="[rate-limit-default]"
    fi
    
    # YAML生成用のヘルパー関数（コード重複排除）
    generate_specific_rules_yaml() {
        local threat_practices="$1"
        local access_control_practices="$2"
        local triggers="$3"
        
        echo "$specific_rules_json" | jq -r --arg threat_practices "$threat_practices" \
            --arg access_control_practices "$access_control_practices" \
            --arg triggers "$triggers" '.[] | 
            "    - host: " + (.host | @json) + "\n" +
            "      mode: " + (.mode | @json) + "\n" +
            "      threatPreventionPractices: " + $threat_practices + "\n" +
            "      accessControlPractices: " + (if .accessControlPractice != null and .accessControlPractice != "" then 
                "[" + (.accessControlPractice | split(",") | map(" " + (. | ltrimstr(" ") | rtrimstr(" ") | @json)) | join(",")) + " ]" 
            else "[]" end) + "\n" +
            "      triggers: " + $triggers + "\n" +
            "      customResponse: " + (.customResponse | @json) + "\n" +
            "      sourceIdentifiers: \"\"\n" +
            "      trustedSources: \"\"\n" +
            "      exceptions: []"'
    }
    
    # YAMLファイルを生成（公式ドキュメントのv1beta2スキーマに準拠）
    # jqの@jsonを使用してYAML Injectionを防止
    local yaml_mode
    yaml_mode=$(echo "$default_mode" | jq -R .)
    local yaml_custom_response
    yaml_custom_response=$(echo "$default_custom_response" | jq -R .)
    
    # accessControlPractices定義を生成する関数
    generate_access_control_practices_yaml() {
        if [ "$use_access_control" = "true" ]; then
            cat << 'ACCESS_CONTROL_EOF'

# アクセス制御プラクティス定義
accessControlPractices:
  - name: rate-limit-default
    practiceMode: inherited
    rateLimit:
      overrideMode: inherited
      rules:
        - uri: "/login"
          limit: 10
          unit: minute
          action: prevent
          comment: "ログイン試行のレート制限"
        - uri: "/api/*"
          limit: 100
          unit: minute
          action: detect
          comment: "API呼び出しのレート制限"
ACCESS_CONTROL_EOF
        fi
    }
    
    if [ "$use_threat_prevention" = "true" ]; then
        cat > "$output_file" << EOF
apiVersion: v1beta2
policies:
  default:
    mode: $(echo "$default_mode" | jq -R .)
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: ${default_access_control}
    triggers: [log-trigger-basic]
    customResponse: $(echo "$default_custom_response" | jq -R .)
    sourceIdentifiers: ""
    trustedSources: ""
    exceptions: []

  specificRules:
$(generate_specific_rules_yaml "[threat-prevention-basic]" "$default_access_control" "[log-trigger-basic]")

# 脅威防止プラクティス定義
threatPreventionPractices:
  - name: threat-prevention-basic
    practiceMode: prevent
    webAttacks:
      overrideMode: prevent
      minimumConfidence: medium
      maxUrlSizeBytes: 32768
      maxObjectDepth: 40
      maxBodySizeKb: 10000
      maxHeaderSizeBytes: 102400
      protections:
        csrfProtection: prevent
        errorDisclosure: prevent
        openRedirect: prevent
        nonValidHttpMethods: true
    intrusionPrevention:
      overrideMode: inherited
      maxPerformanceImpact: medium
      minSeverityLevel: medium
      minCveYear: 2016
      highConfidenceEventAction: prevent
      mediumConfidenceEventAction: prevent
      lowConfidenceEventAction: detect
    fileSecurity:
      overrideMode: inherited
      minSeverityLevel: medium
      highConfidenceEventAction: prevent
      mediumConfidenceEventAction: prevent
      lowConfidenceEventAction: detect
    snortSignatures:
      overrideMode: inherited
      configmap: []
      files: []
    schemaValidation:
      overrideMode: inherited
      configmap: []
      files: []
    antiBot:
      overrideMode: inherited
      injectedUris: []
      validatedUris: []

# ログトリガー定義
logTriggers:
  - name: log-trigger-basic
    accessControlLogging:
      allowEvents: false
      dropEvents: true
    appsecLogging:
      detectEvents: true
      preventEvents: true
      allWebRequests: false
    extendedLogging:
      urlPath: true
      urlQuery: true
      httpHeaders: false
      requestBody: false
    additionalSuspiciousEventsLogging:
      enabled: true
      minSeverity: high
      responseBody: false
      responseCode: true
    logDestination:
      cloud: false
      logToAgent: true
      stdout:
        format: json
$(generate_access_control_practices_yaml)
EOF
    else
        cat > "$output_file" << EOF
apiVersion: v1beta2
policies:
  default:
    mode: $(echo "$default_mode" | jq -R .)
    threatPreventionPractices: []
    accessControlPractices: ${default_access_control}
    triggers: []
    customResponse: $(echo "$default_custom_response" | jq -R .)
    sourceIdentifiers: ""
    trustedSources: ""
    exceptions: []

  specificRules:
$(generate_specific_rules_yaml "[]" "$default_access_control" "[]")
$(generate_access_control_practices_yaml)
EOF
    fi
    
    # ファイル生成の確認
    if [ ! -f "$output_file" ]; then
        echo "❌ エラー: 設定ファイルの生成に失敗しました（ファイルが存在しません）" >&2
        return 1
    fi
    
    if [ ! -s "$output_file" ]; then
        echo "❌ エラー: 設定ファイルが空です: $output_file" >&2
        return 1
    fi
    
    # YAML構文の検証（yqまたはpythonを使用）
    if command -v yq >/dev/null 2>&1; then
        local yq_error
        yq_error=$(mktemp)
        trap 'rm -f -- "$yq_error"' RETURN
        if yq eval . "$output_file" >/dev/null 2>"$yq_error"; then
            trap - RETURN
            rm -f "$yq_error"
            echo "✅ OpenAppSec設定ファイルを生成しました: $output_file"
            return 0
        else
            local error_msg
            error_msg=$(cat "$yq_error" 2>/dev/null || echo "YAML構文エラー")
            echo "❌ エラー: YAML構文エラーが検出されました: $output_file" >&2
            echo "❌ YAMLエラー詳細: $error_msg" >&2
            trap - RETURN
            rm -f "$yq_error"
            return 1
        fi
    else
        # yqが利用できない場合は、基本的な検証のみ
            echo "✅ OpenAppSec設定ファイルを生成しました: $output_file"
        echo "⚠️  YAML構文の検証にはyqが必要です（オプション）" >&2
            return 0
    fi
}
