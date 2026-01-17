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
    
    # デフォルトモードを取得
    local default_mode
    default_mode=$(echo "$config_data" | jq -r '.default_mode // "detect-learn"')
    
    # デフォルトカスタムレスポンス
    local default_custom_response
    default_custom_response=$(echo "$config_data" | jq -r '.default_custom_response // 403')
    
    # FQDN別設定（specificRules）を生成
    local specific_rules_json
    specific_rules_json=$(echo "$config_data" | jq -r '.fqdns[]? | select(.is_active == true) | {
        host: .fqdn,
        mode: (.waf_mode // "detect-learn"),
        customResponse: (.custom_response // 403)
    }' | jq -s '.')
    
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
    
    # YAML構文の検証（yqまたはpythonを使用）
    if command -v yq >/dev/null 2>&1; then
        if yq eval . "$output_file" >/dev/null 2>&1; then
            echo "✅ OpenAppSec設定ファイルを生成しました: $output_file"
            return 0
        else
            echo "⚠️  YAML構文エラーの可能性があります: $output_file" >&2
            return 1
        fi
    else
        # yqが利用できない場合は、基本的な検証のみ
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            echo "✅ OpenAppSec設定ファイルを生成しました: $output_file"
            echo "⚠️  YAML構文の検証にはyqが必要です（オプション）"
            return 0
        else
            echo "❌ 設定ファイルの生成に失敗しました" >&2
            return 1
        fi
    fi
}
