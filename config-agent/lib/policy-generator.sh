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
    
    # YAMLファイルを生成
    cat > "$output_file" << EOF
apiVersion: v1beta2
kind: LocalPolicy
metadata:
  name: default-policy
policies:
  default:
    mode: ${default_mode}
    customResponse: ${default_custom_response}
    threatPreventionPractices: []
    accessControlPractices: []
    triggers: []
    sourceIdentifiers: {}
    trustedSources: []
    exceptions: []

  specificRules:
$(echo "$specific_rules_json" | jq -r '.[] | "    - host: \"\(.host)\"\n      mode: \(.mode)\n      customResponse: \(.customResponse)\n      threatPreventionPractices: []\n      accessControlPractices: []\n      triggers: []"')
EOF
    
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
