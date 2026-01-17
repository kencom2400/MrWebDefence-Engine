#!/bin/sh
# Nginx設定ファイル変更監視スクリプト
# 設定ファイルの変更を検知して自動的にNginxをリロードします
# Dockerソケットがマウントされていない場合の代替手段として使用
#
# 使用方法:
#   1. このスクリプトをNginxコンテナ内でバックグラウンドで起動
#   2. config-agentが設定ファイルを更新すると、自動的にリロードされる
#
# 監視方法:
#   - シグナルファイル方式: .reload_signalファイルの作成を監視
#   - inotifywait方式（利用可能な場合）: 設定ファイルの変更を直接監視

set -e

CONF_DIR="/etc/nginx/conf.d"
RELOAD_SIGNAL_FILE="${CONF_DIR}/.reload_signal"
PID_FILE="/var/run/nginx.pid"

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [watch-config] ℹ️  $*"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [watch-config] ✅ $*"
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [watch-config] ⚠️  $*" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [watch-config] ❌ $*" >&2
}

# inotifywaitが利用可能か確認
if ! command -v inotifywait >/dev/null 2>&1; then
    log_warning "inotifywaitが利用できません。シグナルファイル方式を使用します"
    USE_SIGNAL_FILE=true
else
    USE_SIGNAL_FILE=false
fi

# シグナルファイル方式で監視
watch_signal_file() {
    log_info "シグナルファイル方式で監視を開始: $RELOAD_SIGNAL_FILE"
    
    while true; do
        if [ -f "$RELOAD_SIGNAL_FILE" ]; then
            log_info "シグナルファイルを検知しました。Nginxをリロードします"
            
            # Nginxプロセスが存在するか確認
            if [ ! -f "$PID_FILE" ]; then
                log_warning "Nginxプロセスが見つかりません。スキップします"
                rm -f "$RELOAD_SIGNAL_FILE"
                sleep 1
                continue
            fi
            
            # Nginx設定のテスト
            if nginx -t >/dev/null 2>&1; then
                # Nginxをリロード
                if nginx -s reload 2>/dev/null; then
                    log_success "Nginxの設定リロードが完了しました"
                else
                    log_error "Nginxの設定リロードに失敗しました"
                fi
            else
                log_error "Nginx設定ファイルにエラーがあります。リロードをスキップします"
                nginx -t
            fi
            
            # シグナルファイルを削除
            rm -f "$RELOAD_SIGNAL_FILE"
        fi
        sleep 1
    done
}

# inotifywait方式で監視
watch_with_inotify() {
    log_info "inotifywait方式で監視を開始: $CONF_DIR"
    
    inotifywait -m -r -e create,modify,delete,close_write \
        --format '%w%f %e' \
        "$CONF_DIR" 2>/dev/null | while read -r file event; do
        # .reload_signalファイルの変更は無視（シグナルファイル方式との重複を避ける）
        if echo "$file" | grep -q "\.reload_signal$"; then
            continue
        fi
        
        log_info "設定ファイルの変更を検知: $file ($event)"
        
        # 少し待ってからリロード（複数のファイルが同時に更新される可能性があるため）
        sleep 0.5
        
        # Nginxプロセスが存在するか確認
        if [ ! -f "$PID_FILE" ]; then
            log_warning "Nginxプロセスが見つかりません。スキップします"
            continue
        fi
        
        # Nginx設定のテスト
        if nginx -t >/dev/null 2>&1; then
            # Nginxをリロード
            if nginx -s reload 2>/dev/null; then
                log_success "Nginxの設定リロードが完了しました（ファイル: $file）"
            else
                log_error "Nginxの設定リロードに失敗しました"
            fi
        else
            log_error "Nginx設定ファイルにエラーがあります。リロードをスキップします"
            nginx -t
        fi
    done
}

# メイン処理
if [ "$USE_SIGNAL_FILE" = "true" ]; then
    watch_signal_file
else
    # inotifywaitとシグナルファイルの両方を監視（バックグラウンドでシグナルファイル監視）
    watch_signal_file &
    SIGNAL_PID=$!
    
    # inotifywaitで監視
    watch_with_inotify
    
    # シグナルファイル監視プロセスを終了
    kill $SIGNAL_PID 2>/dev/null || true
fi
