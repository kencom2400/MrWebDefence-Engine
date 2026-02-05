#!/bin/bash

# Nginx設定生成スクリプト（GeoIP機能対応版）
# JSONデータからNginx設定ファイルを生成
# アーキテクチャ: Hybrid Approach (MWD-42-geoip-architecture.md)

set -euo pipefail

# ========================================
# 入力検証関数（セキュリティ対策）
# ========================================

# FQDN名の検証
validate_fqdn() {
    local fqdn="$1"
    # FQDNの形式検証（RFC 1035準拠）
    if ! echo "$fqdn" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'; then
        echo "⚠️  警告: 無効なFQDN形式: $fqdn" >&2
        return 1
    fi
    # 変数名として安全な文字のみ許可
    if echo "$fqdn" | grep -qE '[^a-zA-Z0-9.-]'; then
        echo "⚠️  警告: FQDNに危険な文字が含まれています: $fqdn" >&2
        return 1
    fi
    return 0
}

# IP/CIDR範囲の厳密な検証
validate_ip_cidr() {
    local ip_cidr="$1"
    # IPv4 CIDR形式の検証
    if ! echo "$ip_cidr" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'; then
        echo "⚠️  警告: 無効なIP/CIDR形式: $ip_cidr" >&2
        return 1
    fi
    # IPアドレスの範囲検証（0-255）
    local IFS='.'
    local ip_part="${ip_cidr%/*}"
    read -ra OCTETS <<< "$ip_part"
    for octet in "${OCTETS[@]}"; do
        if [[ $octet -gt 255 ]]; then
            echo "⚠️  警告: 無効なIPオクテット: $octet in $ip_cidr" >&2
            return 1
        fi
    done
    # CIDR範囲の検証（0-32）
    if [[ "$ip_cidr" =~ / ]]; then
        local cidr="${ip_cidr##*/}"
        if [[ $cidr -gt 32 ]] || [[ $cidr -lt 0 ]]; then
            echo "⚠️  警告: 無効なCIDR範囲: $cidr" >&2
            return 1
        fi
    fi
    return 0
}

# 国コードの厳密な検証（ISO 3166-1 alpha-2）
validate_country_code() {
    local country_code="$1"
    # 大文字2文字の検証
    if ! echo "$country_code" | grep -qE '^[A-Z]{2}$'; then
        echo "⚠️  警告: 無効な国コード形式: $country_code" >&2
        return 1
    fi
    return 0
}

# バックエンドホストのバリデーション
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
    # 許可パターン
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

# バックエンドポートのバリデーション
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

# ========================================
# 変数名サニタイズ
# ========================================

# FQDNから変数名を生成（ドットとハイフンをアンダースコアに変換）
sanitize_fqdn_for_variable() {
    local fqdn="$1"
    echo "$fqdn" | tr '.-' '__' | tr '[:upper:]' '[:lower:]'
}

# ========================================
# GeoIP設定生成関数
# ========================================

# X-Forwarded-For設定を生成
generate_xff_config() {
    local fqdn_config="$1"
    
    local xff_enabled
    xff_enabled=$(echo "$fqdn_config" | jq -r '.geoip.x_forwarded_for.enabled // false')
    
    if [ "$xff_enabled" != "true" ]; then
        return 0
    fi
    
    local trusted_proxies
    trusted_proxies=$(echo "$fqdn_config" | jq -r '.geoip.x_forwarded_for.trusted_proxies[]? // empty' 2>/dev/null)
    
    if [ -z "$trusted_proxies" ]; then
        return 0
    fi
    
    echo "# X-Forwarded-Forヘッダー処理（信頼できるプロキシ設定）"
    while IFS= read -r proxy; do
        if [ -n "$proxy" ] && validate_ip_cidr "$proxy"; then
            echo "set_real_ip_from $proxy;"
        fi
    done <<< "$trusted_proxies"
    echo "real_ip_header X-Forwarded-For;"
    echo "real_ip_recursive on;"
}

# IP AllowList設定を生成
generate_ip_allowlist() {
    local fqdn_config="$1"
    
    local ip_allowlist
    ip_allowlist=$(echo "$fqdn_config" | jq -r '.geoip.ip_allowlist[]? // empty' 2>/dev/null)
    
    if [ -z "$ip_allowlist" ]; then
        return 0
    fi
    
    while IFS= read -r ip; do
        if [ -n "$ip" ] && validate_ip_cidr "$ip"; then
            echo "    $ip 1;"
        fi
    done <<< "$ip_allowlist"
}

# IP BlockList設定を生成
generate_ip_blocklist() {
    local fqdn_config="$1"
    
    local ip_blocklist
    ip_blocklist=$(echo "$fqdn_config" | jq -r '.geoip.ip_blocklist[]? // empty' 2>/dev/null)
    
    if [ -z "$ip_blocklist" ]; then
        return 0
    fi
    
    while IFS= read -r ip; do
        if [ -n "$ip" ] && validate_ip_cidr "$ip"; then
            echo "    $ip 1;"
        fi
    done <<< "$ip_blocklist"
}

# 国コード AllowList設定を生成
generate_country_allowlist() {
    local fqdn_config="$1"
    
    local country_allowlist
    country_allowlist=$(echo "$fqdn_config" | jq -r '.geoip.country_allowlist[]? // empty' 2>/dev/null)
    
    if [ -z "$country_allowlist" ]; then
        return 0
    fi
    
    while IFS= read -r country; do
        if [ -n "$country" ] && validate_country_code "$country"; then
            echo "    $country 1;"
        fi
    done <<< "$country_allowlist"
}

# 国コード BlockList設定を生成
generate_country_blocklist() {
    local fqdn_config="$1"
    
    local country_blocklist
    country_blocklist=$(echo "$fqdn_config" | jq -r '.geoip.country_blocklist[]? // empty' 2>/dev/null)
    
    if [ -z "$country_blocklist" ]; then
        return 0
    fi
    
    while IFS= read -r country; do
        if [ -n "$country" ] && validate_country_code "$country"; then
            echo "    $country 1;"
        fi
    done <<< "$country_blocklist"
}

# アクセス制御ロジックを生成（アプローチ2: シンプル版）
generate_access_decision_logic() {
    local sanitized_fqdn="$1"
    local fqdn_config="$2"
    
    # AllowList/BlockListの有無を確認
    local has_ip_allowlist has_ip_blocklist has_country_allowlist has_country_blocklist
    has_ip_allowlist=$(echo "$fqdn_config" | jq -r '.geoip.ip_allowlist | length > 0' 2>/dev/null || echo "false")
    has_ip_blocklist=$(echo "$fqdn_config" | jq -r '.geoip.ip_blocklist | length > 0' 2>/dev/null || echo "false")
    has_country_allowlist=$(echo "$fqdn_config" | jq -r '.geoip.country_allowlist | length > 0' 2>/dev/null || echo "false")
    has_country_blocklist=$(echo "$fqdn_config" | jq -r '.geoip.country_blocklist | length > 0' 2>/dev/null || echo "false")
    
    # いずれかのリストが定義されている場合のみアクセス制御ロジックを生成
    if [ "$has_ip_allowlist" = "false" ] && [ "$has_ip_blocklist" = "false" ] && \
       [ "$has_country_allowlist" = "false" ] && [ "$has_country_blocklist" = "false" ]; then
        return 0
    fi
    
    # デフォルトアクションを決定
    # AllowListが1つでも定義されている場合は、デフォルトで拒否（ホワイトリストモード）
    # BlockListのみの場合は、デフォルトで許可（ブラックリストモード）
    local default_action=0
    if [ "$has_ip_allowlist" = "true" ] || [ "$has_country_allowlist" = "true" ]; then
        default_action=1
    fi
    
    cat << EOF

# 最終的なアクセス許可判定（AllowList優先ロジック - アプローチ2）
map "\$${sanitized_fqdn}_ip_allowed:\$${sanitized_fqdn}_ip_blocked:\$${sanitized_fqdn}_country_allowed:\$${sanitized_fqdn}_country_blocked" \$${sanitized_fqdn}_access_denied {
    # IP AllowList優先: 即座に許可
    "1:0:0:0" 0;  # IP AllowList のみ一致
    "1:1:0:0" 0;  # IP AllowList + IP BlockList → AllowList優先
    "1:0:1:0" 0;  # IP AllowList + 国コード AllowList
    "1:0:0:1" 0;  # IP AllowList + 国コード BlockList → AllowList優先
    "1:1:1:0" 0;  # IP AllowList + その他 → AllowList優先
    "1:1:0:1" 0;  # IP AllowList + その他 → AllowList優先
    "1:0:1:1" 0;  # IP AllowList + その他 → AllowList優先
    "1:1:1:1" 0;  # すべて一致 → AllowList優先
    
    # IP BlockList: 拒否（AllowListがない場合のみ）
    "0:1:0:0" 1;  # IP BlockList のみ一致
    "0:1:1:0" 1;  # IP BlockList + 国コード AllowList → BlockList優先
    "0:1:0:1" 1;  # IP BlockList + 国コード BlockList
    "0:1:1:1" 1;  # IP BlockList + 国コード両方
    
    # 国コード AllowList: 許可（IP判定なし）
    "0:0:1:0" 0;  # 国コード AllowList のみ一致
    "0:0:1:1" 0;  # 国コード両方 → AllowList優先
    
    # 国コード BlockList: 拒否（AllowListがない場合のみ）
    "0:0:0:1" 1;  # 国コード BlockList のみ一致
    
    # デフォルト: どのリストにも一致しない場合
    # AllowListが存在する場合は拒否（ホワイトリストモード）、BlockListのみの場合は許可（ブラックリストモード）
    default ${default_action};
}
EOF
}

# ========================================
# GeoIP設定ファイル生成（httpコンテキスト用）
# ========================================

generate_geoip_config_file() {
    local fqdn="$1"
    local fqdn_config="$2"
    local output_dir="$3"
    
    # FQDN検証
    if ! validate_fqdn "$fqdn"; then
        echo "❌ エラー: 無効なFQDN、スキップします: $fqdn" >&2
        return 1
    fi
    
    local sanitized_fqdn
    sanitized_fqdn=$(sanitize_fqdn_for_variable "$fqdn")
    
    local geoip_file="${output_dir}/geoip/${fqdn}-geoip.conf"
    
    # GeoIP設定が有効かチェック
    local geoip_enabled
    geoip_enabled=$(echo "$fqdn_config" | jq -r '.geoip.enabled // false')
    
    if [[ "$geoip_enabled" != "true" ]]; then
        # GeoIP無効の場合、ファイルを削除（存在すれば）
        rm -f "$geoip_file"
        return 0
    fi
    
    # X-Forwarded-For設定を生成
    local xff_config
    xff_config=$(generate_xff_config "$fqdn_config")
    
    # IP AllowList設定を生成
    local ip_allowlist_entries
    ip_allowlist_entries=$(generate_ip_allowlist "$fqdn_config")
    
    # IP BlockList設定を生成
    local ip_blocklist_entries
    ip_blocklist_entries=$(generate_ip_blocklist "$fqdn_config")
    
    # 国コード AllowList設定を生成
    local country_allowlist_entries
    country_allowlist_entries=$(generate_country_allowlist "$fqdn_config")
    
    # 国コード BlockList設定を生成
    local country_blocklist_entries
    country_blocklist_entries=$(generate_country_blocklist "$fqdn_config")
    
    # アクセス制御ロジックを生成
    local access_logic
    access_logic=$(generate_access_decision_logic "$sanitized_fqdn" "$fqdn_config")
    
    # GeoIP設定ファイルを生成
    cat > "$geoip_file" << EOF
# GeoIP設定: ${fqdn}
# 自動生成: $(date '+%Y-%m-%d %H:%M:%S')
# このファイルはhttpコンテキストにincludeされます

EOF

    # X-Forwarded-For設定を出力
    if [ -n "$xff_config" ]; then
        cat >> "$geoip_file" << EOF
$xff_config

EOF
    fi
    
    # IP AllowList判定
    cat >> "$geoip_file" << EOF
# IP/CIDR AllowList判定
geo \$${sanitized_fqdn}_ip_allowed {
    default 0;
EOF
    if [ -n "$ip_allowlist_entries" ]; then
        echo "$ip_allowlist_entries" >> "$geoip_file"
    fi
    cat >> "$geoip_file" << EOF
}

EOF
    
    # IP BlockList判定
    cat >> "$geoip_file" << EOF
# IP/CIDR BlockList判定
geo \$${sanitized_fqdn}_ip_blocked {
    default 0;
EOF
    if [ -n "$ip_blocklist_entries" ]; then
        echo "$ip_blocklist_entries" >> "$geoip_file"
    fi
    cat >> "$geoip_file" << EOF
}

EOF
    
    # 国コード AllowList判定
    cat >> "$geoip_file" << EOF
# 国コード AllowList判定
map \$geoip2_data_country_iso_code \$${sanitized_fqdn}_country_allowed {
    default 0;
EOF
    if [ -n "$country_allowlist_entries" ]; then
        echo "$country_allowlist_entries" >> "$geoip_file"
    fi
    cat >> "$geoip_file" << EOF
}

EOF
    
    # 国コード BlockList判定
    cat >> "$geoip_file" << EOF
# 国コード BlockList判定
map \$geoip2_data_country_iso_code \$${sanitized_fqdn}_country_blocked {
    default 0;
EOF
    if [ -n "$country_blocklist_entries" ]; then
        echo "$country_blocklist_entries" >> "$geoip_file"
    fi
    cat >> "$geoip_file" << EOF
}
EOF
    
    # アクセス制御ロジックを出力
    if [ -n "$access_logic" ]; then
        echo "$access_logic" >> "$geoip_file"
    fi
    
    echo "✅ GeoIP設定ファイルを生成しました: $geoip_file"
}

# ========================================
# FQDN設定ファイル生成（serverコンテキスト用）
# ========================================

generate_fqdn_config_file() {
    local fqdn="$1"
    local fqdn_config="$2"
    local customer_name="$3"
    local output_dir="$4"
    
    # FQDN検証
    if ! validate_fqdn "$fqdn"; then
        echo "❌ エラー: 無効なFQDN、スキップします: $fqdn" >&2
        return 1
    fi
    
    local sanitized_fqdn
    sanitized_fqdn=$(sanitize_fqdn_for_variable "$fqdn")
    
    # バックエンド設定を取得（バリデーション済み）
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
    
    # バックエンドURLを構築
    local backend_url
    backend_url="http://${backend_host}:${backend_port}"
    
    local config_file="${output_dir}/conf.d/${fqdn}.conf"
    
    # FQDN別ログディレクトリを作成
    local log_dir="/var/log/nginx/${fqdn}"
    if ! mkdir -p "$log_dir" 2>/dev/null; then
        echo "⚠️  警告: ログディレクトリの作成に失敗しました: $log_dir" >&2
    fi
    
    # GeoIP設定が有効かチェック
    local geoip_enabled
    geoip_enabled=$(echo "$fqdn_config" | jq -r '.geoip.enabled // false')
    
    # GeoIPアクセス制御ブロックを生成
    local geoip_access_control=""
    local geoip_error_page=""
    if [[ "$geoip_enabled" == "true" ]]; then
        geoip_error_page="
    # GeoIP拒否時のカスタムレスポンス
    error_page 403 @geoip_denied;
    location @geoip_denied {
        internal;
        default_type application/json;
        return 403 '{\"error\": \"Access denied\", \"reason\": \"GeoIP policy violation\"}';
    }"
        
        geoip_access_control="
    # GeoIPアクセス制御
    if (\$${sanitized_fqdn}_access_denied = 1) {
        return 403;
    }"
    fi
    
    # FQDN設定ファイルを生成
    cat > "$config_file" << EOF
# FQDN設定: ${fqdn}
# 自動生成: $(date '+%Y-%m-%d %H:%M:%S')

server {
    listen 80;
    server_name ${fqdn};

    # 顧客名を変数に設定（ログフォーマットで使用）
    set \$customer_name "${customer_name}";
${geoip_error_page}
${geoip_access_control}

    # アクセスログ（FQDN別ディレクトリ、JSON形式）
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
    
    echo "✅ FQDN設定ファイルを生成しました: $config_file"
}

# ========================================
# メイン設定生成関数
# ========================================

generate_nginx_configs() {
    local config_data="$1"
    local output_dir="$2"
    
    if [ -z "$config_data" ] || [ -z "$output_dir" ]; then
        echo "❌ エラー: 引数が不足しています" >&2
        return 1
    fi
    
    # 出力ディレクトリを作成
    mkdir -p "${output_dir}/conf.d"
    mkdir -p "${output_dir}/geoip"
    
    # JSON形式の検証
    if ! echo "$config_data" | jq empty 2>/dev/null; then
        local json_error
        json_error=$(echo "$config_data" | jq . 2>&1 | head -5 || echo "JSONパースエラー")
        echo "❌ エラー: 設定データが有効なJSON形式ではありません" >&2
        echo "❌ JSONエラー詳細: $json_error" >&2
        return 1
    fi
    
    # 顧客名を取得
    local customer_name
    if ! customer_name=$(echo "$config_data" | jq -r '.customer_name // "default"'); then
        echo "⚠️  警告: customer_nameの取得中にjqエラーが発生しました。デフォルト値を使用します" >&2
        customer_name="default"
    elif [ -z "$customer_name" ] || [ "$customer_name" = "null" ]; then
        echo "⚠️  警告: customer_nameが設定されていません。デフォルト値を使用します" >&2
        customer_name="default"
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
        
        # GeoIP設定ファイルを生成（httpコンテキスト用）
        generate_geoip_config_file "$fqdn" "$fqdn_config" "$output_dir"
        
        # FQDN設定ファイルを生成（serverコンテキスト用）
        generate_fqdn_config_file "$fqdn" "$fqdn_config" "$customer_name" "$output_dir"
    done
    
    # 無効化されたFQDNの設定ファイルを削除
    local all_config_files
    all_config_files=$(find "${output_dir}/conf.d" -name "*.conf" -type f 2>/dev/null || true)
    
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
    
    # 無効化されたFQDNのGeoIP設定ファイルを削除
    local all_geoip_files
    all_geoip_files=$(find "${output_dir}/geoip" -name "*-geoip.conf" -type f 2>/dev/null || true)
    
    if [ -n "$all_geoip_files" ]; then
        echo "$all_geoip_files" | while read -r geoip_file; do
            local fqdn_from_file
            fqdn_from_file=$(basename "$geoip_file" -geoip.conf)
            
            # アクティブなFQDNリストに含まれているか確認
            if ! echo "$active_fqdns" | grep -q "^${fqdn_from_file}$"; then
                echo "🗑️  無効化されたFQDNのGeoIP設定ファイルを削除: $geoip_file"
                rm -f "$geoip_file"
            fi
        done
    fi
    
    echo "✅ Nginx設定ファイルの生成が完了しました"
}

# ========================================
# SSL/TLS設定生成関数
# ========================================

# SSL設定ファイルを生成（HTTPS設定）
generate_ssl_config() {
    local fqdn="$1"
    local config_file="$2"
    local cert_path="/etc/letsencrypt/live/${fqdn}"
    
    cat > "$config_file" << EOF
# HTTPS設定: ${fqdn}
# 自動生成: $(date '+%Y-%m-%d %H:%M:%S')

server {
    listen 443 ssl http2;
    server_name ${fqdn};
    
    # SSL証明書
    ssl_certificate     ${cert_path}/fullchain.pem;
    ssl_certificate_key ${cert_path}/privkey.pem;
    
    # SSL設定
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    
    # セキュリティヘッダー
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # アクセスログ（FQDN別ディレクトリ、JSON形式）
    access_log /var/log/nginx/${fqdn}/access.log json_combined;
    error_log /var/log/nginx/${fqdn}/error.log warn;
    
    location / {
        # バックエンドへのプロキシ
        proxy_pass http://httpbin.org:80;
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
}

# HTTP→HTTPSリダイレクト設定を生成
generate_http_redirect_config() {
    local fqdn="$1"
    local config_file="$2"
    
    cat > "$config_file" << EOF
# HTTP設定: ${fqdn}
# ACME Challenge + HTTPS リダイレクト
# 自動生成: $(date '+%Y-%m-%d %H:%M:%S')

server {
    listen 80;
    server_name ${fqdn};
    
    # ACME Challenge用ディレクトリ
    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
        allow all;
    }
    
    # HTTP→HTTPSリダイレクト
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
}

# SSL設定を含むFQDN設定ファイルを生成
generate_fqdn_ssl_config() {
    local fqdn="$1"
    local output_dir="$2"
    local cert_path="/etc/letsencrypt/live/${fqdn}"
    
    # 証明書の存在確認
    if [ ! -d "$cert_path" ] || [ ! -f "${cert_path}/fullchain.pem" ]; then
        echo "⚠️  警告: SSL証明書が見つかりません: $fqdn"
        echo "   証明書パス: $cert_path"
        echo "   HTTP設定のみを生成します"
        echo "   証明書取得後、ConfigAgentを再実行してください"
        return 0
    fi
    
    echo "🔐 SSL設定を生成中: $fqdn"
    
    # HTTPS設定ファイルを生成
    local ssl_config_file="${output_dir}/conf.d/${fqdn}-ssl.conf"
    generate_ssl_config "$fqdn" "$ssl_config_file"
    echo "  ✅ HTTPS設定: $ssl_config_file"
    
    # HTTP→HTTPSリダイレクト設定を生成
    local http_config_file="${output_dir}/conf.d/${fqdn}.conf"
    generate_http_redirect_config "$fqdn" "$http_config_file"
    echo "  ✅ HTTPリダイレクト設定: $http_config_file"
}
