#!/bin/bash

# 設定取得エージェント（メインスクリプト）
# 管理APIから設定を取得し、OpenAppSecとNginxの設定ファイルを生成・更新

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_AGENT_ROOT="${SCRIPT_DIR}"

# ライブラリの読み込み
source "${CONFIG_AGENT_ROOT}/lib/api-client.sh"
source "${CONFIG_AGENT_ROOT}/lib/config-generator.sh"
source "${CONFIG_AGENT_ROOT}/lib/config-validator.sh"

# 設定の読み込み
CONFIG_API_URL="${CONFIG_API_URL:-http://config-api:8080}"
CONFIG_API_TOKEN="${CONFIG_API_TOKEN}"
POLLING_INTERVAL="${POLLING_INTERVAL:-300}"  # デフォルト5分
CACHE_TTL="${CACHE_TTL:-300}"  # デフォルト5分

# 出力ディレクトリ
OUTPUT_DIR="${OUTPUT_DIR:-/app/output}"
OPENAPPSEC_CONFIG="${OUTPUT_DIR}/openappsec/local_policy.yaml"
NGINX_CONF_DIR="${OUTPUT_DIR}/nginx/conf.d"

# ログレベル設定
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# ログレベルの数値化
get_log_level_value() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        *)     echo 1 ;;  # デフォルトはINFO
    esac
}

# ログレベル判定
should_log() {
    local message_level="$1"
    local current_level_value
    local message_level_value
    
    current_level_value=$(get_log_level_value "$LOG_LEVEL")
    message_level_value=$(get_log_level_value "$message_level")
    
    [ $message_level_value -ge $current_level_value ]
}

# ログ出力関数
log_debug() {
    if should_log "DEBUG"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $*"
    fi
}

log_info() {
    if should_log "INFO"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] ℹ️  $*"
    fi
}

log_success() {
    if should_log "INFO"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] ✅ $*"
    fi
}

log_warning() {
    if should_log "WARN"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] ⚠️  $*" >&2
    fi
}

log_error() {
    if should_log "ERROR"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] ❌ $*" >&2
        # エラー発生時のスタックトレース（呼び出し元情報）
        if [ "${LOG_LEVEL}" = "DEBUG" ]; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] スタックトレース:" >&2
            local frame=0
            local call_info
            while call_info=$(caller $frame 2>/dev/null); do
                echo "$call_info" | sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG]   /" >&2
                frame=$((frame + 1))
            done
        fi
    fi
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
    
    local nginx_container="${NGINX_CONTAINER_NAME:-mwd-nginx}"
    
    # Dockerソケットがマウントされているか確認
    if [ -S /var/run/docker.sock ]; then
        # Dockerソケットがマウントされている場合: docker execを使用
        log_info "Dockerソケットが利用可能です。docker execを使用してリロードします"
        local reload_output
        reload_output=$(docker exec "$nginx_container" nginx -s reload 2>&1)
        local reload_status=$?
        
        if [ $reload_status -eq 0 ]; then
            log_success "Nginxの設定リロードが完了しました"
            return 0
        else
            log_warning "Nginxの設定リロードに失敗しました"
            log_error "Nginxからのエラー: ${reload_output}"
            return 1
        fi
    else
        # Dockerソケットがマウントされていない場合: シグナルファイル方式を使用
        # Nginxコンテナ内のwatch-config.shスクリプトがシグナルファイルを監視し、自動的にリロードします
        log_warning "Dockerソケットがマウントされていません"
        log_info "シグナルファイル方式を使用します（Nginxコンテナ内のwatch-config.shが監視します）"
        
        # シグナルファイルを作成（共有ボリューム上）
        local signal_file="${NGINX_CONF_DIR}/.reload_signal"
        touch "$signal_file"
        
        # シグナルファイルの存在を確認
        if [ -f "$signal_file" ]; then
            log_info "シグナルファイルを作成しました: $signal_file"
            log_info "Nginxコンテナ内のwatch-config.shがシグナルを検知してリロードします"
            # シグナルファイル方式では、Nginxコンテナ側のwatch-config.shがリロードを実行するため、
            # ここでは成功として扱う（実際のリロードはNginxコンテナ内で実行される）
            return 0
        else
            log_error "シグナルファイルの作成に失敗しました: $signal_file"
            return 1
        fi
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
    log_info "ログレベル: ${LOG_LEVEL}"
    log_debug "出力ディレクトリ: ${OUTPUT_DIR}"
    log_debug "OpenAppSec設定ファイル: ${OPENAPPSEC_CONFIG}"
    log_debug "Nginx設定ディレクトリ: ${NGINX_CONF_DIR}"
    
    # 環境変数の確認
    if [ -z "$CONFIG_API_TOKEN" ]; then
        log_error "CONFIG_API_TOKENが設定されていません"
        log_error "環境変数を設定してから再起動してください"
        exit 1
    fi
    
    # エラー統計
    local error_count=0
    local success_count=0
    local last_error_time=""
    
    # 一時ディレクトリを作成し、終了時に自動でクリーンアップする
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM
    
    while true; do
        local loop_start_time
        loop_start_time=$(date +%s)
        
        log_info "設定取得を開始..."
        log_debug "ループ開始時刻: $(date -d "@$loop_start_time" +'%Y-%m-%d %H:%M:%S' 2>/dev/null || date +'%Y-%m-%d %H:%M:%S')"
        
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
        local fetch_error_file="$tmp_dir/fetch_error"
        config_data=$(fetch_config_from_api 2>"$fetch_error_file")
        local fetch_status=$?
        local fetch_error_msg
        fetch_error_msg=$(cat "$fetch_error_file" 2>/dev/null || echo "")
        
        if [ $fetch_status -ne 0 ] || [ -z "$config_data" ]; then
            log_error "設定取得に失敗しました"
            if [ -n "$fetch_error_msg" ]; then
                log_error "エラー詳細: $fetch_error_msg"
            fi
            log_info "60秒後にリトライします..."
            sleep 60
            continue
        fi
        
        # JSON形式の検証
        if ! echo "$config_data" | jq empty 2>/dev/null; then
            local json_error
            json_error=$(echo "$config_data" | jq . 2>&1 | head -5 || echo "JSONパースエラー")
            log_error "取得したデータが有効なJSON形式ではありません"
            log_error "JSONエラー詳細: $json_error"
            log_info "60秒後にリトライします..."
            sleep 60
            continue
        fi
        
        # 設定データの検証
        if ! validate_config_data "$config_data"; then
            log_error "設定データの検証に失敗しました"
            log_info "60秒後にリトライします..."
            sleep 60
            continue
        fi
        
        # バージョン確認
        local current_version
        current_version=$(echo "$config_data" | jq -r '.version // empty' 2>/dev/null)
        local jq_version_status=$?
        
        if [ $jq_version_status -ne 0 ]; then
            log_error "バージョン番号の取得に失敗しました（jqエラー）"
            log_info "60秒後にリトライします..."
            sleep 60
            continue
        fi
        
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
        local generate_error_file="$tmp_dir/generate_error"
        if generate_configs "$config_data" "$OPENAPPSEC_CONFIG" "$NGINX_CONF_DIR" 2>"$generate_error_file"; then
            local generate_error_msg
            generate_error_msg=$(cat "$generate_error_file" 2>/dev/null || echo "")
            
            if [ -n "$generate_error_msg" ]; then
                log_warning "設定ファイル生成時の警告: $generate_error_msg"
            fi
            
            # OpenAppSec Agentの設定リロード
            if ! reload_openappsec_config; then
                log_error "OpenAppSec Agentの設定リロードに失敗しました"
                log_info "60秒後にリトライします..."
                sleep 60
                continue
            fi
            
            # Nginxの設定リロード
            local reload_error_file="$tmp_dir/reload_error"
            if ! reload_nginx_config 2>"$reload_error_file"; then
                local reload_error_msg
                reload_error_msg=$(cat "$reload_error_file" 2>/dev/null || echo "")
                log_error "Nginxの設定リロードに失敗しました"
                if [ -n "$reload_error_msg" ]; then
                    log_error "リロードエラー詳細: $reload_error_msg"
                fi
                log_info "60秒後にリトライします..."
                sleep 60
                continue
            fi
            
            # バージョンを更新
            last_version="$current_version"
            
            # キャッシュを更新
            echo "$config_data" > "$cache_file"
            echo "$(date +%s)" > "$cache_timestamp_file"
            
            success_count=$((success_count + 1))
            error_count=0  # 成功時はエラーカウントをリセット
            
            local loop_end_time
            loop_end_time=$(date +%s)
            local processing_time=$((loop_end_time - loop_start_time))
            
            log_success "設定更新完了（バージョン: $current_version、処理時間: ${processing_time}秒）"
            log_debug "累計成功回数: ${success_count}"
        else
            local generate_error_msg
            generate_error_msg=$(cat "$generate_error_file" 2>/dev/null || echo "")
            
            error_count=$((error_count + 1))
            last_error_time=$(date +'%Y-%m-%d %H:%M:%S')
            
            log_error "設定ファイルの生成に失敗しました（連続エラー: ${error_count}回）"
            if [ -n "$generate_error_msg" ]; then
                log_error "生成エラー詳細: $generate_error_msg"
            fi
            
            # 連続エラー時の警告
            if [ $error_count -ge 5 ]; then
                log_warning "連続エラーが ${error_count} 回発生しています。最後のエラー時刻: ${last_error_time}"
            fi
            
            log_info "60秒後にリトライします..."
            sleep 60
            continue
        fi
        
        log_debug "次のポーリングまで ${POLLING_INTERVAL} 秒待機します"
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
