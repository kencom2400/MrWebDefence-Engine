#!/bin/bash

# Nginx設定生成スクリプト
# JSONデータからNginx設定ファイルを生成

set -e

# Nginx設定ファイルを生成
generate_nginx_configs() {
    local config_data="$1"
    local output_dir="$2"
    
    if [ -z "$config_data" ] || [ -z "$output_dir" ]; then
        echo "❌ エラー: 引数が不足しています" >&2
        return 1
    fi
    
    # 出力ディレクトリを作成
    mkdir -p "$output_dir"
    
    # JSON形式の検証
    if ! echo "$config_data" | jq empty 2>/dev/null; then
        local json_error
        json_error=$(echo "$config_data" | jq . 2>&1 | head -5 || echo "JSONパースエラー")
        echo "❌ エラー: 設定データが有効なJSON形式ではありません" >&2
        echo "❌ JSONエラー詳細: $json_error" >&2
        return 1
    fi
    
    # アクティブなFQDNのリストを取得
    local active_fqdns
    local jq_error
    jq_error=$(mktemp)
    trap 'rm -f -- "$jq_error"' RETURN
    active_fqdns=$(echo "$config_data" | jq -r '.fqdns[]? | select(.is_active == true) | .fqdn' 2>"$jq_error")
    local jq_status=$?
    
    if [ $jq_status -ne 0 ]; then
        local error_msg
        error_msg=$(cat "$jq_error" 2>/dev/null || echo "jqエラー")
        echo "❌ エラー: FQDNリストの取得に失敗しました" >&2
        echo "❌ jqエラー詳細: $error_msg" >&2
        trap - RETURN
        rm -f "$jq_error"
        return 1
    fi
    trap - RETURN
    rm -f "$jq_error"
    
    if [ -z "$active_fqdns" ]; then
        echo "⚠️  アクティブなFQDNが見つかりません" >&2
        return 0
    fi
    
    # 各FQDNごとに設定ファイルを生成
    echo "$active_fqdns" | while read -r fqdn; do
        if [ -z "$fqdn" ]; then
            continue
        fi
        
        # FQDN設定を取得
        local fqdn_config
        local jq_error
        jq_error=$(mktemp)
        trap 'rm -f -- "$jq_error"' RETURN
        fqdn_config=$(echo "$config_data" | jq -r --arg fqdn "$fqdn" '.fqdns[] | select(.fqdn == $fqdn)' 2>"$jq_error")
        local jq_status=$?
        
        if [ $jq_status -ne 0 ] || [ -z "$fqdn_config" ]; then
            local error_msg
            error_msg=$(cat "$jq_error" 2>/dev/null || echo "jqエラー")
            echo "⚠️  警告: FQDN '$fqdn' の設定取得に失敗しました: $error_msg" >&2
            trap - RETURN
            rm -f "$jq_error"
            continue
        fi
        trap - RETURN
        rm -f "$jq_error"
        
        # バックエンド設定を取得
        local backend_host
        backend_host=$(echo "$fqdn_config" | jq -r '.backend_host // "httpbin.org"')
        if [ $? -ne 0 ] || [ -z "$backend_host" ]; then
            echo "⚠️  警告: FQDN '$fqdn' のbackend_hostが取得できません。デフォルト値を使用します" >&2
            backend_host="httpbin.org"
        fi
        
        local backend_port
        backend_port=$(echo "$fqdn_config" | jq -r '.backend_port // 80')
        if [ $? -ne 0 ] || [ -z "$backend_port" ]; then
            echo "⚠️  警告: FQDN '$fqdn' のbackend_portが取得できません。デフォルト値を使用します" >&2
            backend_port="80"
        fi
        
        local backend_path
        backend_path=$(echo "$fqdn_config" | jq -r '.backend_path // ""')
        if [ $? -ne 0 ]; then
            echo "⚠️  警告: FQDN '$fqdn' のbackend_pathが取得できません。空文字列を使用します" >&2
            backend_path=""
        fi
        
        # 顧客名を取得（ログに含めるため）
        local customer_name
        if ! customer_name=$(echo "$config_data" | jq -r '.customer_name // "default"'); then
            echo "⚠️  警告: customer_nameの取得中にjqエラーが発生しました。デフォルト値を使用します" >&2
            customer_name="default"
        elif [ -z "$customer_name" ] || [ "$customer_name" = "null" ]; then
            echo "⚠️  警告: customer_nameが設定されていません。デフォルト値を使用します" >&2
            customer_name="default"
        fi
        
        # バックエンドURLを構築
        local backend_url
        if [ -n "$backend_path" ]; then
            backend_url="http://${backend_host}:${backend_port}${backend_path}"
        else
            backend_url="http://${backend_host}:${backend_port}"
        fi
        
        local config_file="${output_dir}/${fqdn}.conf"
        
        # FQDN別ログディレクトリを作成（Nginx起動時に必要）
        # 注意: /var/log/nginxはdocker-compose.ymlでマウントされている必要がある
        local log_dir="/var/log/nginx/${fqdn}"
        if ! mkdir -p "$log_dir" 2>/dev/null; then
            echo "⚠️  警告: ログディレクトリの作成に失敗しました: $log_dir" >&2
            echo "⚠️  注意: docker-compose.ymlでNginxログボリュームがマウントされていることを確認してください" >&2
        else
            echo "✅ ログディレクトリを作成しました: $log_dir"
        fi
        
        # Nginx設定ファイルを生成
        if ! cat > "$config_file" << EOF
# FQDN設定: ${fqdn}
# 自動生成: $(date +'%Y-%m-%d %H:%M:%S')

server {
    listen 80;
    server_name ${fqdn};

    # 顧客名を変数に設定（ログフォーマットで使用）
    set \$customer_name "${customer_name}";

    # アクセスログ（FQDN別ディレクトリ、JSON形式）
    # ログディレクトリを自動作成（Nginx起動時に必要）
    access_log /var/log/nginx/${fqdn}/access.log json_combined;
    error_log /var/log/nginx/${fqdn}/error.log warn;

    location / {
        # バックエンドへのプロキシ
        proxy_pass ${backend_url};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # タイムアウト設定
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # ヘルスチェック用エンドポイント
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
        then
            echo "❌ エラー: Nginx設定ファイルの書き込みに失敗しました: $config_file" >&2
            continue
        fi
        
        # ファイル生成の確認
        if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
            echo "❌ エラー: Nginx設定ファイルが正しく生成されませんでした: $config_file" >&2
            continue
        fi
        
        echo "✅ Nginx設定ファイルを生成しました: $config_file"
    done
    
    # 無効化されたFQDNの設定ファイルを削除
    local all_config_files
    all_config_files=$(find "$output_dir" -name "*.conf" -type f 2>/dev/null || true)
    
    if [ -n "$all_config_files" ]; then
        echo "$all_config_files" | while read -r config_file; do
            local fqdn_from_file
            fqdn_from_file=$(basename "$config_file" .conf)
            
            # アクティブなFQDNリストに含まれているか確認
            if ! echo "$active_fqdns" | grep -q "^${fqdn_from_file}$"; then
                echo "🗑️  無効化されたFQDNの設定ファイルを削除: $config_file"
                rm -f "$config_file"
            fi
        done
    fi
    
    echo "✅ Nginx設定ファイルの生成が完了しました"
}
