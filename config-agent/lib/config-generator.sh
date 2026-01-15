#!/bin/bash

# 設定ファイル生成の統合スクリプト
# policy-generator.shとnginx-config-generator.shを呼び出す

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 他のライブラリを読み込み
if [ -f "${SCRIPT_DIR}/policy-generator.sh" ]; then
    source "${SCRIPT_DIR}/policy-generator.sh"
fi

if [ -f "${SCRIPT_DIR}/nginx-config-generator.sh" ]; then
    source "${SCRIPT_DIR}/nginx-config-generator.sh"
fi

# 設定ファイルを生成（OpenAppSecとNginxの両方）
generate_configs() {
    local config_data="$1"
    local openappsec_output="$2"
    local nginx_output_dir="$3"
    
    if [ -z "$config_data" ] || [ -z "$openappsec_output" ] || [ -z "$nginx_output_dir" ]; then
        echo "❌ エラー: 引数が不足しています" >&2
        return 1
    fi
    
    echo "🔄 設定ファイルを生成中..."
    
    # OpenAppSec設定ファイルを生成
    if generate_openappsec_policy "$config_data" "$openappsec_output"; then
        echo "  ✅ OpenAppSec設定ファイルを生成しました"
    else
        echo "  ❌ OpenAppSec設定ファイルの生成に失敗しました" >&2
        return 1
    fi
    
    # Nginx設定ファイルを生成
    if generate_nginx_configs "$config_data" "$nginx_output_dir"; then
        echo "  ✅ Nginx設定ファイルを生成しました"
    else
        echo "  ❌ Nginx設定ファイルの生成に失敗しました" >&2
        return 1
    fi
    
    echo "✅ すべての設定ファイルの生成が完了しました"
    return 0
}

# メイン関数（config-agent.shから呼び出される）
main() {
    # この関数はconfig-agent.shで定義されているため、ここでは定義しない
    # このファイルはライブラリとして使用される
    :
}
