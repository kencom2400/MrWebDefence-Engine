#!/bin/bash

# OpenAppSecサービス管理スクリプト
# Docker Composeで管理されているサービスを起動・停止・再起動する

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力関数
log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

# Docker Composeコマンドの確認
check_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        log_error "docker-composeがインストールされていません"
        exit 1
    fi
}

# サービス起動
start_services() {
    local services="${1:-}"
    
    cd "$DOCKER_DIR"
    
    log_info "サービスを起動中..."
    
    if [ -z "$services" ]; then
        # 全サービスを起動
        if $DOCKER_COMPOSE_CMD up -d 2>&1 | tee /tmp/docker-compose-output.log; then
            # エラーメッセージをチェック
            if grep -q "Error\|error\|failed\|Failed" /tmp/docker-compose-output.log; then
                log_error "サービスの起動中にエラーが発生しました"
                log_info "詳細なログを確認してください:"
                $DOCKER_COMPOSE_CMD logs --tail=20
                return 1
            fi
            log_success "全サービスが起動しました"
        else
            log_error "サービスの起動に失敗しました"
            log_info "詳細なログを確認してください:"
            $DOCKER_COMPOSE_CMD logs --tail=20
            return 1
        fi
    else
        # 指定されたサービスを起動
        if $DOCKER_COMPOSE_CMD up -d $services 2>&1 | tee /tmp/docker-compose-output.log; then
            # エラーメッセージをチェック
            if grep -q "Error\|error\|failed\|Failed" /tmp/docker-compose-output.log; then
                log_error "サービスの起動中にエラーが発生しました: $services"
                log_info "詳細なログを確認してください:"
                $DOCKER_COMPOSE_CMD logs --tail=20 $services
                return 1
            fi
            log_success "サービスが起動しました: $services"
        else
            log_error "サービスの起動に失敗しました: $services"
            log_info "詳細なログを確認してください:"
            $DOCKER_COMPOSE_CMD logs --tail=20 $services
            return 1
        fi
    fi
    
    # 起動確認
    sleep 2
    show_status
}

# サービス停止
stop_services() {
    local services="${1:-}"
    
    cd "$DOCKER_DIR"
    
    log_info "サービスを停止中..."
    
    if [ -z "$services" ]; then
        # 全サービスを停止
        if $DOCKER_COMPOSE_CMD stop; then
            log_success "全サービスが停止しました"
        else
            log_error "サービスの停止に失敗しました"
            return 1
        fi
    else
        # 指定されたサービスを停止
        if $DOCKER_COMPOSE_CMD stop $services; then
            log_success "サービスが停止しました: $services"
        else
            log_error "サービスの停止に失敗しました: $services"
            return 1
        fi
    fi
}

# サービス再起動
restart_services() {
    local services="${1:-}"
    
    cd "$DOCKER_DIR"
    
    log_info "サービスを再起動中..."
    
    if [ -z "$services" ]; then
        # 全サービスを再起動
        if $DOCKER_COMPOSE_CMD restart; then
            log_success "全サービスが再起動しました"
        else
            log_error "サービスの再起動に失敗しました"
            return 1
        fi
    else
        # 指定されたサービスを再起動
        if $DOCKER_COMPOSE_CMD restart $services; then
            log_success "サービスが再起動しました: $services"
        else
            log_error "サービスの再起動に失敗しました: $services"
            return 1
        fi
    fi
    
    # 起動確認
    sleep 2
    show_status
}

# サービス削除（停止＋コンテナ削除）
down_services() {
    cd "$DOCKER_DIR"
    
    log_warning "サービスを停止してコンテナを削除しますか？ (y/N)"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "キャンセルされました"
        return 0
    fi
    
    log_info "サービスを停止してコンテナを削除中..."
    
    if $DOCKER_COMPOSE_CMD down; then
        log_success "サービスが停止し、コンテナが削除されました"
    else
        log_error "サービスの停止・削除に失敗しました"
        return 1
    fi
}

# サービス状態表示
show_status() {
    cd "$DOCKER_DIR"
    
    echo ""
    log_info "サービス状態:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $DOCKER_COMPOSE_CMD ps
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ログ表示
show_logs() {
    local services="${1:-}"
    local follow="${2:-false}"
    
    cd "$DOCKER_DIR"
    
    if [ "$follow" = "true" ]; then
        log_info "ログを表示中（Ctrl+Cで終了）..."
        $DOCKER_COMPOSE_CMD logs -f $services
    else
        log_info "最新のログを表示中..."
        $DOCKER_COMPOSE_CMD logs --tail=50 $services
    fi
}

# サービス一覧表示
list_services() {
    echo ""
    log_info "利用可能なサービス:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  nginx              - Nginx（OpenAppSec Attachment Module組み込み）"
    echo "  openappsec-agent   - OpenAppSec Agent"
    echo "  config-agent       - 設定取得エージェント（オプション）"
    echo "  mock-api           - モックAPIサーバー（動作確認用）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 使用方法表示
show_usage() {
    cat << EOF
使用方法: $0 {command} [service...]

コマンド:
  start [service...]     - サービスを起動（サービス名を指定しない場合は全サービス）
  stop [service...]       - サービスを停止（サービス名を指定しない場合は全サービス）
  restart [service...]    - サービスを再起動（サービス名を指定しない場合は全サービス）
  down                   - サービスを停止してコンテナを削除
  status                 - サービス状態を表示
  logs [service...]      - ログを表示（最新50行）
  logs-follow [service...] - ログをリアルタイム表示（Ctrl+Cで終了）
  list                   - 利用可能なサービス一覧を表示

例:
  $0 start                    # 全サービスを起動
  $0 start nginx              # nginxのみ起動
  $0 stop                     # 全サービスを停止
  $0 restart nginx openappsec-agent  # 指定したサービスを再起動
  $0 logs                     # 全サービスのログを表示
  $0 logs-follow nginx        # nginxのログをリアルタイム表示
  $0 status                   # サービス状態を表示

EOF
}

# メイン処理
main() {
    local command="${1:-}"
    shift || true
    
    # Docker Composeコマンドの確認
    check_docker_compose
    
    case "$command" in
        start)
            start_services "$@"
            ;;
        stop)
            stop_services "$@"
            ;;
        restart)
            restart_services "$@"
            ;;
        down)
            down_services
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$@"
            ;;
        logs-follow)
            show_logs "$@" "true"
            ;;
        list)
            list_services
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            if [ -z "$command" ]; then
                log_error "コマンドが指定されていません"
            else
                log_error "不明なコマンド: $command"
            fi
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"
