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
    
    # デフォルトモードを取得
    local default_mode
    default_mode=$(echo "$config_data" | jq -r '.default_mode // "detect-learn"')
    if [ $? -ne 0 ] || [ -z "$default_mode" ]; then
        echo "❌ エラー: default_modeの取得に失敗しました" >&2
        return 1
    fi
    
    # デフォルトカスタムレスポンス
    local default_custom_response
    default_custom_response=$(echo "$config_data" | jq -r '.default_custom_response // 403')
    if [ $? -ne 0 ] || [ -z "$default_custom_response" ]; then
        echo "❌ エラー: default_custom_responseの取得に失敗しました" >&2
        return 1
    fi
    
    # FQDN別設定（specificRules）を生成
    local specific_rules_json
    local jq_error
    jq_error=$(mktemp)
    specific_rules_json=$(echo "$config_data" | jq -r '.fqdns[]? | select(.is_active == true) | {
        host: .fqdn,
        mode: (.waf_mode // "detect-learn"),
        customResponse: (.custom_response // 403)
    }' 2>"$jq_error" | jq -s '.' 2>>"$jq_error")
    local jq_status=$?
    
    if [ $jq_status -ne 0 ]; then
        local error_msg
        error_msg=$(cat "$jq_error" 2>/dev/null || echo "jqエラー")
        echo "❌ エラー: FQDN設定の取得に失敗しました" >&2
        echo "❌ jqエラー詳細: $error_msg" >&2
        rm -f "$jq_error"
        return 1
    fi
    rm -f "$jq_error"
    
    # threatPreventionPracticesの使用判定（prevent/prevent-learnモードの場合は使用）
    local use_threat_prevention="false"
    if [[ "$default_mode" == "prevent"* ]] || echo "$specific_rules_json" | jq -e '.[] | select(.mode | startswith("prevent"))' >/dev/null 2>&1; then
        use_threat_prevention="true"
    fi
    
    # YAMLファイルを生成（公式ドキュメントのv1beta2スキーマに準拠）
    if [ "$use_threat_prevention" = "true" ]; then
        cat > "$output_file" << EOF
apiVersion: v1beta2
policies:
  default:
    mode: ${default_mode}
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: []
    triggers: [log-trigger-basic]
    customResponse: ${default_custom_response}
    sourceIdentifiers: ""
    trustedSources: ""
    exceptions: []

  specificRules:
$(echo "$specific_rules_json" | jq -r '.[] | 
    "    - host: \"\(.host)\"\n" +
    "      mode: \(.mode)\n" +
    "      threatPreventionPractices: [threat-prevention-basic]\n" +
    "      accessControlPractices: []\n" +
    "      triggers: [log-trigger-basic]\n" +
    "      customResponse: \(.customResponse)\n" +
    "      sourceIdentifiers: \"\"\n" +
    "      trustedSources: \"\"\n" +
    "      exceptions: []"')

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
EOF
    else
        cat > "$output_file" << EOF
apiVersion: v1beta2
policies:
  default:
    mode: ${default_mode}
    threatPreventionPractices: []
    accessControlPractices: []
    triggers: []
    customResponse: ${default_custom_response}
    sourceIdentifiers: ""
    trustedSources: ""
    exceptions: []

  specificRules:
$(echo "$specific_rules_json" | jq -r '.[] | "    - host: \"\(.host)\"\n      mode: \(.mode)\n      threatPreventionPractices: []\n      accessControlPractices: []\n      triggers: []\n      customResponse: \(.customResponse)\n      sourceIdentifiers: \"\"\n      trustedSources: \"\"\n      exceptions: []"')
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
        if yq eval . "$output_file" >/dev/null 2>"$yq_error"; then
            rm -f "$yq_error"
            echo "✅ OpenAppSec設定ファイルを生成しました: $output_file"
            return 0
        else
            local error_msg
            error_msg=$(cat "$yq_error" 2>/dev/null || echo "YAML構文エラー")
            echo "❌ エラー: YAML構文エラーが検出されました: $output_file" >&2
            echo "❌ YAMLエラー詳細: $error_msg" >&2
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
