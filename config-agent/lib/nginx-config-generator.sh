#!/bin/bash

# Nginx設定生成スクリプト
# JSONデータからNginx設定ファイルを生成

set -e

# バックエンドホストのバリデーション（設定インジェクション・SSRF対策）
# 許可: ドメイン名（英数字・ハイフン・ドット）、localhost、IPv4
# 拒否: 空白・改行・;|$`<>() 等のシェル/設定に危険な文字
validate_backend_host() {
    local host="$1"
    local fqdn_label="$2"
    if [ -z "$host" ]; then
        echo "httpbin.org"
        return
    fi
    # 長さ制限（ホスト名は253文字まで）
    if [ "${#host}" -gt 253 ]; then
        echo "⚠️  警告: FQDN '$fqdn_label' のbackend_hostが長すぎます。デフォルト値を使用します" >&2
        echo "httpbin.org"
        return
    fi
    # 許可パターン: 各ラベルが英数字で始まり英数字またはハイフンのみ、英数字で終わる（a..b, a-.com 等を拒否）、localhost、IPv4
    if echo "$host" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$|^localhost$|^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        # IPv4の各オクテットが0-255であることを確認
        if echo "$host" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
            local o1 o2 o3 o4
            IFS='.' read -r o1 o2 o3 o4 << EOF
$host
EOF
            if [ "$o1" -gt 255 ] 2>/dev/null || [ "$o2" -gt 255 ] 2>/dev/null || [ "$o3" -gt 255 ] 2>/dev/null || [ "$o4" -gt 255 ] 2>/dev/null; then
                echo "⚠️  警告: FQDN '$fqdn_label' のbackend_hostが無効なIPv4です。デフォルト値を使用します" >&2
                echo "httpbin.org"
                return
            fi
        fi
        echo "$host"
    else
        echo "⚠️  警告: FQDN '$fqdn_label' のbackend_hostに無効な文字が含まれています。デフォルト値を使用します" >&2
        echo "httpbin.org"
    fi
}

# バックエンドポートのバリデーション（1-65535の整数のみ許可）
validate_backend_port() {
    local port="$1"
    local fqdn_label="$2"
    if [ -z "$port" ] || [ "$port" = "null" ]; then
        echo "80"
        return
    fi
    if echo "$port" | grep -qE '^[0-9]+$'; then
        local p
        p=$((port + 0))
        if [ "$p" -ge 1 ] 2>/dev/null && [ "$p" -le 65535 ]; then
            echo "$p"
        else
            echo "⚠️  警告: FQDN '$fqdn_label' のbackend_portが範囲外です（1-65535）。デフォルト値を使用します" >&2
            echo "80"
        fi
    else
        echo "⚠️  警告: FQDN '$fqdn_label' のbackend_portが数値ではありません。デフォルト値を使用します" >&2
        echo "80"
    fi
}

# GeoIP設定を生成
generate_geoip_config() {
    local fqdn_config="$1"
    local fqdn="$2"
    
    # GeoIP設定が有効かチェック
    local geoip_enabled
    geoip_enabled=$(echo "$fqdn_config" | jq -r '.geoip.enabled // false')
    
    if [ "$geoip_enabled" != "true" ]; then
        # GeoIP無効の場合は空文字列を返す
        echo ""
        return
    fi
    
    # GeoIP設定を構築
    local geoip_config=""
    
    # X-Forwarded-For設定
    local xff_enabled
    xff_enabled=$(echo "$fqdn_config" | jq -r '.geoip.x_forwarded_for.enabled // false')
    
    if [ "$xff_enabled" = "true" ]; then
        # 信頼できるプロキシのIPレンジを取得
        local trusted_proxies
        trusted_proxies=$(echo "$fqdn_config" | jq -r '.geoip.x_forwarded_for.trusted_proxies[]? // empty' 2>/dev/null)
        
        if [ -n "$trusted_proxies" ]; then
            geoip_config+="
    # X-Forwarded-Forから実IPを取得
    # 信頼できるプロキシからのX-Forwarded-Forヘッダーを使用
"
            while IFS= read -r proxy; do
                geoip_config+="    set_real_ip_from $proxy;
"
            done <<< "$trusted_proxies"
            
            geoip_config+="    real_ip_header X-Forwarded-For;
    real_ip_recursive on;
"
        fi
    fi
    
    # IP AllowList設定
    local ip_allowlist
    ip_allowlist=$(echo "$fqdn_config" | jq -r '.geoip.ip_allowlist[]? // empty' 2>/dev/null)
    
    if [ -n "$ip_allowlist" ]; then
        geoip_config+="
    # IP AllowList（geoディレクティブ）
    geo \$ip_allowlist {
        default 0;
"
        while IFS= read -r ip; do
            geoip_config+="        $ip 1;
"
        done <<< "$ip_allowlist"
        
        geoip_config+="    }
"
    fi
    
    # IP BlockList設定
    local ip_blocklist
    ip_blocklist=$(echo "$fqdn_config" | jq -r '.geoip.ip_blocklist[]? // empty' 2>/dev/null)
    
    if [ -n "$ip_blocklist" ]; then
        geoip_config+="
    # IP BlockList（geoディレクティブ）
    geo \$ip_blocklist {
        default 0;
"
        while IFS= read -r ip; do
            geoip_config+="        $ip 1;
"
        done <<< "$ip_blocklist"
        
        geoip_config+="    }
"
    fi
    
    # 国コード AllowList設定
    local country_allowlist
    country_allowlist=$(echo "$fqdn_config" | jq -r '.geoip.country_allowlist[]? // empty' 2>/dev/null)
    
    if [ -n "$country_allowlist" ]; then
        geoip_config+="
    # 国コード AllowList（mapディレクティブ）
    map \$geoip2_data_country_iso_code \$country_allowlist {
        default 0;
"
        while IFS= read -r country; do
            geoip_config+="        $country 1;
"
        done <<< "$country_allowlist"
        
        geoip_config+="    }
"
    fi
    
    # 国コード BlockList設定
    local country_blocklist
    country_blocklist=$(echo "$fqdn_config" | jq -r '.geoip.country_blocklist[]? // empty' 2>/dev/null)
    
    if [ -n "$country_blocklist" ]; then
        geoip_config+="
    # 国コード BlockList（mapディレクティブ）
    map \$geoip2_data_country_iso_code \$country_blocklist {
        default 0;
"
        while IFS= read -r country; do
            geoip_config+="        $country 1;
"
        done <<< "$country_blocklist"
        
        geoip_config+="    }
"
    fi
    
    # アクセス制御ロジック
    local allowlist_priority
    allowlist_priority=$(echo "$fqdn_config" | jq -r '.geoip.allowlist_priority // true')
    
    if [ -n "$ip_allowlist" ] || [ -n "$country_allowlist" ] || [ -n "$ip_blocklist" ] || [ -n "$country_blocklist" ]; then
        geoip_config+="
    # アクセス制御ロジック
    set \$access_allowed 1;  # デフォルトは許可
"
        
        if [ "$allowlist_priority" = "true" ] && ([ -n "$ip_allowlist" ] || [ -n "$country_allowlist" ]); then
            geoip_config+="
    # AllowListが定義されている場合、デフォルトを拒否に変更
"
            if [ -n "$ip_allowlist" ]; then
                geoip_config+="    if (\$ip_allowlist) {
        set \$access_allowed 0;
    }
"
            fi
            if [ -n "$country_allowlist" ]; then
                geoip_config+="    if (\$country_allowlist) {
        set \$access_allowed 0;
    }
"
            fi
            
            geoip_config+="
    # IP AllowListに含まれる場合は許可
    if (\$ip_allowlist = \"1\") {
        set \$access_allowed 1;
    }
    
    # 国コード AllowListに含まれる場合は許可
    if (\$country_allowlist = \"1\") {
        set \$access_allowed 1;
    }
"
        fi
        
        # BlockList判定
        geoip_config+="
    # IP BlockListに含まれる場合は拒否
    if (\$ip_blocklist = \"1\") {
        set \$access_allowed 0;
    }
    
    # 国コード BlockListに含まれる場合は拒否
    if (\$country_blocklist = \"1\") {
        set \$access_allowed 0;
    }
    
    # アクセス拒否
    if (\$access_allowed = \"0\") {
        return 403 '{\"error\": \"Access denied\", \"reason\": \"GeoIP policy violation\"}';
        add_header Content-Type application/json always;
    }
"
    fi
    
    echo "$geoip_config"
}

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
        
        # バックエンド設定を取得（API値はバリデーション・サニタイズを適用）
        local backend_host_raw
        backend_host_raw=$(echo "$fqdn_config" | jq -r '.backend_host // "httpbin.org"')
        if [ $? -ne 0 ] || [ -z "$backend_host_raw" ] || [ "$backend_host_raw" = "null" ]; then
            backend_host_raw="httpbin.org"
        fi
        local backend_host
        backend_host=$(validate_backend_host "$backend_host_raw" "$fqdn")

        local backend_port_raw
        backend_port_raw=$(echo "$fqdn_config" | jq -r '.backend_port // 80')
        if [ $? -ne 0 ] || [ -z "$backend_port_raw" ] || [ "$backend_port_raw" = "null" ]; then
            backend_port_raw="80"
        fi
        local backend_port
        backend_port=$(validate_backend_port "$backend_port_raw" "$fqdn")
        
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
        # 注意: RateLimit機能をテストするため、パスを保持する必要がある
        # proxy_passの末尾にパスを含めないことで、リクエストパスが保持される
        local backend_url
        backend_url="http://${backend_host}:${backend_port}"
        
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
        
        # GeoIP設定を生成
        local geoip_config
        geoip_config=$(generate_geoip_config "$fqdn_config" "$fqdn")
        
        # Nginx設定ファイルを生成
        if ! cat > "$config_file" << EOF
# FQDN設定: ${fqdn}
# 自動生成: $(date +'%Y-%m-%d %H:%M:%S')

server {
    listen 80;
    server_name ${fqdn};

    # 顧客名を変数に設定（ログフォーマットで使用）
    set \$customer_name "${customer_name}";
${geoip_config}
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
        proxy_set_header X-GeoIP-Country \$geoip2_data_country_iso_code;

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
