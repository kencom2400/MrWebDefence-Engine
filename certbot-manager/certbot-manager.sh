#!/bin/bash
#
# certbot-manager.sh - SSL/TLS証明書管理スクリプト
#
# 機能:
# - 初回証明書取得
# - 証明書自動更新
# - Nginx設定リロード
#
# 環境変数:
# - EMAIL: Let's Encrypt登録用メールアドレス（必須）
# - DOMAINS: 証明書取得対象ドメイン（カンマ区切り、必須）
# - STAGING: ステージング環境フラグ（true/false、デフォルト: false）
# - NGINX_CONTAINER_NAME: Nginxコンテナ名（デフォルト: mwd-nginx）
#

set -euo pipefail

# ============================================================================
# 定数定義
# ============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly CERTBOT_DIR="/etc/letsencrypt"
readonly WEBROOT_DIR="/var/www/certbot"
readonly LOG_PREFIX="[certbot-manager]"

# ============================================================================
# ログ関数
# ============================================================================

log_info() {
    echo "${LOG_PREFIX} [INFO] $*"
}

log_warn() {
    echo "${LOG_PREFIX} [WARN] $*" >&2
}

log_error() {
    echo "${LOG_PREFIX} [ERROR] $*" >&2
}

# ============================================================================
# 検証関数
# ============================================================================

validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "無効なメールアドレス形式: $email"
        return 1
    fi
}

validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "無効なドメイン形式: $domain"
        return 1
    fi
}

validate_env() {
    log_info "環境変数を検証中..."
    
    if [ -z "${EMAIL:-}" ]; then
        log_error "EMAIL環境変数が設定されていません"
        return 1
    fi
    
    if [ -z "${DOMAINS:-}" ]; then
        log_error "DOMAINS環境変数が設定されていません"
        return 1
    fi
    
    validate_email "$EMAIL" || return 1
    
    # ドメインリストを検証
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        domain=$(echo "$domain" | xargs)  # トリム
        validate_domain "$domain" || return 1
    done
    
    log_info "環境変数の検証が完了しました"
    log_info "  EMAIL: $EMAIL"
    log_info "  DOMAINS: $DOMAINS"
    log_info "  STAGING: ${STAGING:-false}"
    log_info "  NGINX_CONTAINER_NAME: ${NGINX_CONTAINER_NAME:-mwd-nginx}"
}

# ============================================================================
# Certbot実行関数
# ============================================================================

build_certbot_command() {
    local action="$1"
    local cmd="certbot $action --webroot --webroot-path=$WEBROOT_DIR"
    
    # ステージング環境フラグ
    if [ "${STAGING:-false}" = "true" ]; then
        cmd="$cmd --staging"
        log_info "ステージング環境モードで実行します"
    fi
    
    # アクションに応じた引数
    if [ "$action" = "certonly" ]; then
        # ドメインリストを追加
        IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
        for domain in "${DOMAIN_ARRAY[@]}"; do
            domain=$(echo "$domain" | xargs)
            cmd="$cmd -d $domain"
        done
        
        cmd="$cmd --email $EMAIL --agree-tos --non-interactive"
    elif [ "$action" = "renew" ]; then
        cmd="$cmd --quiet --deploy-hook 'docker exec ${NGINX_CONTAINER_NAME:-mwd-nginx} nginx -s reload'"
    fi
    
    echo "$cmd"
}

# ============================================================================
# 初回証明書取得
# ============================================================================

cmd_init() {
    log_info "=== 初回証明書取得を開始します ==="
    
    validate_env || return 1
    
    # 既存の証明書を確認
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    first_domain=$(echo "${DOMAIN_ARRAY[0]}" | xargs)
    
    if [ -d "$CERTBOT_DIR/live/$first_domain" ]; then
        log_warn "証明書は既に存在します: $first_domain"
        log_info "更新が必要な場合は 'renew' コマンドを使用してください"
        return 0
    fi
    
    # Certbotコマンドを構築して実行
    local cmd=$(build_certbot_command "certonly")
    log_info "実行コマンド: $cmd"
    
    if eval "$cmd"; then
        log_info "✅ 証明書の取得に成功しました"
        log_info "証明書ディレクトリ: $CERTBOT_DIR/live/$first_domain"
        
        # Nginx設定をリロード
        log_info "Nginx設定をリロードしています..."
        if docker exec "${NGINX_CONTAINER_NAME:-mwd-nginx}" nginx -s reload 2>/dev/null; then
            log_info "✅ Nginxのリロードに成功しました"
        else
            log_warn "Nginxのリロードに失敗しました（コンテナが起動していない可能性があります）"
        fi
        
        return 0
    else
        log_error "❌ 証明書の取得に失敗しました"
        return 1
    fi
}

# ============================================================================
# 証明書更新
# ============================================================================

cmd_renew() {
    log_info "=== 証明書更新を開始します ==="
    
    validate_env || return 1
    
    # Certbotコマンドを構築して実行
    local cmd=$(build_certbot_command "renew")
    log_info "実行コマンド: $cmd"
    
    if eval "$cmd"; then
        log_info "✅ 証明書の更新チェックが完了しました"
        return 0
    else
        log_error "❌ 証明書の更新に失敗しました"
        return 1
    fi
}

# ============================================================================
# テストモード
# ============================================================================

cmd_test() {
    log_info "=== テストモードで証明書取得を試行します ==="
    
    validate_env || return 1
    
    # 強制的にステージング環境を使用
    export STAGING=true
    
    cmd_init
}

# ============================================================================
# バージョン確認
# ============================================================================

cmd_version() {
    log_info "=== バージョン情報 ==="
    certbot --version
    docker --version
}

# ============================================================================
# ヘルプ
# ============================================================================

cmd_help() {
    cat <<EOF
使用方法: $SCRIPT_NAME <command>

コマンド:
  init      初回証明書取得
  renew     証明書更新（cron実行用）
  test      テストモード（ステージング環境で証明書取得）
  version   バージョン情報表示
  help      このヘルプを表示

環境変数:
  EMAIL                  Let's Encrypt登録用メールアドレス（必須）
  DOMAINS                証明書取得対象ドメイン（カンマ区切り、必須）
  STAGING                ステージング環境フラグ（true/false、デフォルト: false）
  NGINX_CONTAINER_NAME   Nginxコンテナ名（デフォルト: mwd-nginx）

例:
  # 初回証明書取得
  docker-compose exec certbot-manager /app/certbot-manager.sh init

  # 証明書更新
  docker-compose exec certbot-manager /app/certbot-manager.sh renew

  # テストモード
  docker-compose exec certbot-manager /app/certbot-manager.sh test

EOF
}

# ============================================================================
# メイン処理
# ============================================================================

main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            cmd_init
            ;;
        renew)
            cmd_renew
            ;;
        test)
            cmd_test
            ;;
        version)
            cmd_version
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            log_error "不明なコマンド: $command"
            cmd_help
            return 1
            ;;
    esac
}

main "$@"
