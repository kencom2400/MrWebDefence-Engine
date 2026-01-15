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
    
    # アクティブなFQDNのリストを取得
    local active_fqdns
    active_fqdns=$(echo "$config_data" | jq -r '.fqdns[]? | select(.is_active == true) | .fqdn')
    
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
        fqdn_config=$(echo "$config_data" | jq -r --arg fqdn "$fqdn" '.fqdns[] | select(.fqdn == $fqdn)')
        
        # バックエンド設定を取得
        local backend_host
        backend_host=$(echo "$fqdn_config" | jq -r '.backend_host // "httpbin.org"')
        local backend_port
        backend_port=$(echo "$fqdn_config" | jq -r '.backend_port // 80')
        local backend_path
        backend_path=$(echo "$fqdn_config" | jq -r '.backend_path // ""')
        
        # バックエンドURLを構築
        local backend_url
        if [ -n "$backend_path" ]; then
            backend_url="http://${backend_host}:${backend_port}${backend_path}"
        else
            backend_url="http://${backend_host}:${backend_port}"
        fi
        
        local config_file="${output_dir}/${fqdn}.conf"
        
        # Nginx設定ファイルを生成
        cat > "$config_file" << EOF
# FQDN設定: ${fqdn}
# 自動生成: $(date +'%Y-%m-%d %H:%M:%S')

server {
    listen 80;
    server_name ${fqdn};

    # アクセスログ（FQDN別）
    access_log /var/log/nginx/${fqdn}.access.log main;
    error_log /var/log/nginx/${fqdn}.error.log warn;

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
