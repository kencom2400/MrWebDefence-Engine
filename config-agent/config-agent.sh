#!/bin/bash

# 設定取得エージェント（メインスクリプト）
# 管理APIから設定を取得し、OpenAppSecとNginxの設定ファイルを生成・更新

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ライブラリの読み込み
source "${SCRIPT_DIR}/lib/api-client.sh"
source "${SCRIPT_DIR}/lib/config-generator.sh"

# 設定の読み込み
CONFIG_API_URL="${CONFIG_API_URL:-http://config-api:8080}"
CONFIG_API_TOKEN="${CONFIG_API_TOKEN}"
POLLING_INTERVAL="${POLLING_INTERVAL:-300}"  # デフォルト5分
CACHE_TTL="${CACHE_TTL:-300}"  # デフォルト5分

# 出力ディレクトリ
OUTPUT_DIR="${OUTPUT_DIR:-/app/output}"
OPENAPPSEC_CONFIG="${OUTPUT_DIR}/openappsec/local_policy.yaml"
NGINX_CONF_DIR="${OUTPUT_DIR}/nginx/conf.d"

# ログ出力関数
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $*"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $*"
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $*" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $*" >&2
}

# OpenAppSec Agentの設定リロード
reload_openappsec_config() {
    # OpenAppSec Agentはファイル変更を自動検知してリロードするため、
    # 特別な操作は不要（ファイルを更新するだけでOK）
    log_info "OpenAppSec Agentの設定リロード（ファイル更新により自動検知）"
    
    # 念のため、ファイルの更新時刻を確認
    if [ -f "$OPENAPPSEC_CONFIG" ]; then
        log_success "OpenAppSec設定ファイルが更新されました: $OPENAPPSEC_CONFIG"
    else
        log_warning "OpenAppSec設定ファイルが見つかりません: $OPENAPPSEC_CONFIG"
    fi
}

# Nginxの設定リロード
reload_nginx_config() {
    log_info "Nginxの設定リロードを実行中..."
    
    # Nginxコンテナにシグナルを送信
    local nginx_container="${NGINX_CONTAINER_NAME:-mwd-nginx}"
    
    # docker execを使用してリロード（同一Dockerネットワーク内から実行）
    if docker exec "$nginx_container" nginx -s reload 2>/dev/null; then
        log_success "Nginxの設定リロードが完了しました"
        return 0
    else
        log_warning "Nginxの設定リロードに失敗しました（コンテナが起動していない可能性があります）"
        # エラーでも続行（設定ファイルは更新されているため）
        return 0
    fi
}

# メインループ
main_loop() {
    local last_version=""
    local cache_file="/tmp/config_cache.json"
    local cache_timestamp_file="/tmp/config_cache_timestamp"
    
    log_info "設定取得エージェントを起動しました"
    log_info "管理API URL: ${CONFIG_API_URL}"
    log_info "ポーリング間隔: ${POLLING_INTERVAL}秒"
    log_info "キャッシュTTL: ${CACHE_TTL}秒"
    
    # 環境変数の確認
    if [ -z "$CONFIG_API_TOKEN" ]; then
        log_error "CONFIG_API_TOKENが設定されていません"
        log_error "環境変数を設定してから再起動してください"
        exit 1
    fi
    
    while true; do
        log_info "設定取得を開始..."
        
        # キャッシュの確認
        if [ -f "$cache_file" ] && [ -f "$cache_timestamp_file" ]; then
            local cache_age=$(($(date +%s) - $(cat "$cache_timestamp_file")))
            if [ $cache_age -lt $CACHE_TTL ]; then
                log_info "キャッシュが有効（残り時間: $((CACHE_TTL - cache_age))秒）"
                sleep $POLLING_INTERVAL
                continue
            fi
        fi
        
        # 設定取得
        local config_data
        config_data=$(fetch_config_from_api)
        
        if [ $? -ne 0 ] || [ -z "$config_data" ]; then
            log_error "設定取得に失敗しました。リトライします..."
            sleep 60
            continue
        fi
        
        # バージョン確認
        local current_version
        current_version=$(echo "$config_data" | jq -r '.version // empty')
        
        if [ -z "$current_version" ]; then
            log_warning "バージョン番号が取得できませんでした。設定を更新します..."
        elif [ "$current_version" = "$last_version" ]; then
            log_info "設定に変更がありません（バージョン: $current_version）"
            # キャッシュを更新
            echo "$config_data" > "$cache_file"
            echo "$(date +%s)" > "$cache_timestamp_file"
            sleep $POLLING_INTERVAL
            continue
        fi
        
        log_info "設定を更新中（バージョン: ${last_version:-"なし"} → $current_version）..."
        
        # 設定ファイル生成
        if generate_configs "$config_data" "$OPENAPPSEC_CONFIG" "$NGINX_CONF_DIR"; then
            # OpenAppSec Agentの設定リロード
            reload_openappsec_config
            
            # Nginxの設定リロード
            reload_nginx_config
            
            # バージョンを更新
            last_version="$current_version"
            
            # キャッシュを更新
            echo "$config_data" > "$cache_file"
            echo "$(date +%s)" > "$cache_timestamp_file"
            
            log_success "設定更新完了（バージョン: $current_version）"
        else
            log_error "設定ファイルの生成に失敗しました"
            sleep 60
            continue
        fi
        
        sleep $POLLING_INTERVAL
    done
}

# エージェント起動
if [ "${1:-}" = "test" ]; then
    # テストモード: API接続テスト
    test_api_connection
else
    # 通常モード: メインループを起動
    main_loop
fi
