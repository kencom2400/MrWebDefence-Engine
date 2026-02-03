#!/bin/bash

# SSL/TLS証明書管理機能テストスクリプト
# Task 5.8: SSL/TLS証明書管理機能実装のテストと動作確認

set -uo pipefail
# 注意: set -e は使用しない（エラーカウントを集計するため）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

# docker-composeコマンドの互換性対応
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "❌ エラー: docker-compose または docker compose が見つかりません" >&2
    exit 1
fi

cd "$DOCKER_DIR"

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# テスト結果のカウント
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0

# カウント関数
increment_error() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

increment_warning() {
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

increment_success() {
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

# ヘルプメッセージ
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

SSL/TLS証明書管理機能のテストスクリプト

OPTIONS:
    --fqdn FQDN         テスト対象のFQDN（デフォルト: test.example.com）
    --skip-cert-test    証明書取得テストをスキップ
    --no-restart        コンテナの停止・起動をスキップ（CI環境用）
    --help              このヘルプメッセージを表示

EXAMPLES:
    # デフォルトFQDNでテスト（コンテナ再起動あり）
    $0

    # 特定のFQDNでテスト
    $0 --fqdn example.com

    # 証明書取得テストをスキップ
    $0 --skip-cert-test

    # CI環境でテスト（コンテナ再起動なし）
    $0 --no-restart

EOF
}

# オプション解析
TEST_FQDN="test.example.com"
SKIP_CERT_TEST=false
NO_RESTART=false

# CI環境の検出
if [ -n "${GITHUB_ACTIONS:-}" ] || [ "${CI:-}" = "true" ]; then
    NO_RESTART=true
    echo "🔍 CI環境を検出しました。コンテナ再起動をスキップします。"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --fqdn)
            TEST_FQDN="$2"
            shift 2
            ;;
        --skip-cert-test)
            SKIP_CERT_TEST=true
            shift
            ;;
        --no-restart)
            NO_RESTART=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# 必要なサービスリスト
REQUIRED_SERVICES=("nginx" "openappsec-agent" "config-agent")

# docker-compose ps の「起動中」判定（Up / running の両方に対応）
is_service_up() {
    $DOCKER_COMPOSE_CMD ps "$1" 2>/dev/null | grep -qE "Up|running"
}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  SSL/TLS証明書管理機能テスト${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "テスト対象FQDN: ${TEST_FQDN}"
if [ "$NO_RESTART" = "true" ]; then
    echo "モード: CI環境（コンテナ再起動なし）"
fi
echo ""

# ============================================================================
# 0. 既存コンテナの停止（CI時またはno-restart時はスキップ）
# ============================================================================
if [ "$NO_RESTART" = "true" ]; then
    echo -e "${BLUE}📋 0. 既存コンテナの停止（スキップ: --no-restartオプション指定）${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 サービス安定化のため2秒待機..."
    sleep 2
    echo ""
else
    echo -e "${BLUE}📋 0. 既存コンテナの停止${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    RUNNING_SERVICES=()

    for service in "${REQUIRED_SERVICES[@]}"; do
        if is_service_up "$service"; then
            echo -e "${YELLOW}⚠️  ${service}コンテナが起動中です（停止します）${NC}"
            RUNNING_SERVICES+=("$service")
        else
            echo -e "${GREEN}✅ ${service}コンテナは停止しています${NC}"
        fi
    done

    if [ ${#RUNNING_SERVICES[@]} -gt 0 ]; then
        echo ""
        echo "🔄 起動中のサービスを停止中: ${RUNNING_SERVICES[*]}"
        if $DOCKER_COMPOSE_CMD stop "${RUNNING_SERVICES[@]}" 2>&1; then
            echo -e "${GREEN}✅ サービスの停止を開始しました${NC}"
            echo "🔄 サービスが停止するまで待機中（3秒）..."
            sleep 3
            
            for service in "${RUNNING_SERVICES[@]}"; do
                if is_service_up "$service"; then
                    echo -e "${YELLOW}  ⚠️  ${service}がまだ起動中です（強制停止します）${NC}"
                    $DOCKER_COMPOSE_CMD kill "$service" 2>/dev/null || true
                else
                    echo -e "${GREEN}  ✅ ${service}が停止しました${NC}"
                fi
            done
        else
            echo -e "${RED}❌ サービスの停止に失敗しました${NC}"
            increment_error
        fi
    else
        echo -e "${GREEN}✅ すべての対象サービスは停止しています${NC}"
    fi
    echo ""
fi

# ============================================================================
# 1. 必要なサービスの起動
# ============================================================================
if [ "$NO_RESTART" = "true" ]; then
    echo -e "${BLUE}📋 1. サービスの起動（スキップ: --no-restartオプション指定）${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 既存のサービス状態を確認します..."
    
    for service in "${REQUIRED_SERVICES[@]}"; do
        if is_service_up "$service"; then
            echo -e "${GREEN}✅ ${service}: 起動中${NC}"
            increment_success
        else
            echo -e "${RED}❌ ${service}: 停止中${NC}"
            echo "   --no-restartオプション指定時は、サービスを起動できません"
            echo "   手動でサービスを起動してください: docker-compose up -d ${service}"
            increment_error
        fi
    done
    echo ""
else
    echo -e "${BLUE}📋 1. 必要なサービスの起動${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "🔄 サービスを起動中: ${REQUIRED_SERVICES[*]}"
    if $DOCKER_COMPOSE_CMD up -d "${REQUIRED_SERVICES[@]}" 2>&1; then
        echo -e "${GREEN}✅ サービスの起動を開始しました${NC}"
        echo "🔄 サービスが起動するまで待機中（5秒）..."
        sleep 5
        
        # 起動確認
        ALL_UP=true
        for service in "${REQUIRED_SERVICES[@]}"; do
            if is_service_up "$service"; then
                echo -e "${GREEN}  ✅ ${service}が起動しました${NC}"
                increment_success
            else
                echo -e "${RED}  ❌ ${service}の起動に失敗しました${NC}"
                $DOCKER_COMPOSE_CMD logs --tail=20 "$service" 2>&1 || true
                increment_error
                ALL_UP=false
            fi
        done
        
        if [ "$ALL_UP" = "false" ]; then
            echo ""
            echo -e "${RED}❌ 一部のサービスの起動に失敗しました${NC}"
            echo "   ログを確認してください: docker-compose logs"
            exit 1
        fi
    else
        echo -e "${RED}❌ サービスの起動に失敗しました${NC}"
        increment_error
        exit 1
    fi
    
    echo ""
    echo "🔄 サービスの安定化のため5秒待機..."
    sleep 5
    echo ""
fi

# ============================================================================
# 2. サービス状態確認
# ============================================================================
echo -e "${BLUE}📋 2. サービス状態確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Nginx
if is_service_up "nginx"; then
    echo -e "${GREEN}✅ Nginx: 起動中${NC}"
    increment_success
else
    echo -e "${RED}❌ Nginx: 停止中${NC}"
    echo "   Nginxを起動してください: docker-compose up -d nginx"
    increment_error
fi

# Certbot Manager（オプション）
if $DOCKER_COMPOSE_CMD ps certbot-manager 2>/dev/null | grep -qE "Up|running"; then
    echo -e "${GREEN}✅ Certbot Manager: 起動中${NC}"
    CERTBOT_MANAGER_EXISTS=true
    increment_success
else
    echo -e "${YELLOW}⚠️  Certbot Manager: 停止中またはサービス未定義${NC}"
    echo "   このテストではCertbot Managerが必要です"
    CERTBOT_MANAGER_EXISTS=false
    increment_warning
fi

echo ""

# ============================================================================
# 3. Docker Compose設定確認
# ============================================================================
echo -e "${BLUE}📋 3. Docker Compose設定確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# certbot-managerサービスの定義確認
if grep -q "certbot-manager:" docker-compose.yml; then
    echo -e "${GREEN}✅ certbot-managerサービスが定義されています${NC}"
    increment_success
else
    echo -e "${RED}❌ certbot-managerサービスが定義されていません${NC}"
    echo "   docker-compose.ymlにcertbot-managerサービスを追加してください"
    increment_error
fi

# certbot-dataボリュームの確認
if grep -q "certbot-data:" docker-compose.yml; then
    echo -e "${GREEN}✅ certbot-dataボリュームが定義されています${NC}"
    increment_success
else
    echo -e "${YELLOW}⚠️  certbot-dataボリュームが定義されていません${NC}"
    increment_warning
fi

# certbot-webrootボリュームの確認
if grep -q "certbot-webroot:" docker-compose.yml; then
    echo -e "${GREEN}✅ certbot-webrootボリュームが定義されています${NC}"
    increment_success
else
    echo -e "${YELLOW}⚠️  certbot-webrootボリュームが定義されていません${NC}"
    increment_warning
fi

# 443ポートのマッピング確認
if grep -q '"443:443"' docker-compose.yml; then
    echo -e "${GREEN}✅ 443ポートがマッピングされています${NC}"
    increment_success
else
    echo -e "${YELLOW}⚠️  443ポートがマッピングされていません${NC}"
    echo "   HTTPSアクセスには443ポートのマッピングが必要です"
    increment_warning
fi

echo ""

# ============================================================================
# ============================================================================
# 4. Nginx設定確認
# ============================================================================
echo -e "${BLUE}📋 4. Nginx設定確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Nginx設定の構文チェック
if $DOCKER_COMPOSE_CMD exec -T nginx nginx -t 2>&1 >/dev/null; then
    echo -e "${GREEN}✅ Nginx設定の構文チェック: 正常${NC}"
    increment_success
else
    echo -e "${RED}❌ Nginx設定の構文チェック: エラー${NC}"
    $DOCKER_COMPOSE_CMD exec -T nginx nginx -t 2>&1
    increment_error
fi

# SSL/TLSセッション設定の確認
if $DOCKER_COMPOSE_CMD exec -T nginx cat /etc/nginx/nginx.conf 2>/dev/null | grep -q "ssl_session_cache"; then
    echo -e "${GREEN}✅ SSLセッションキャッシュが設定されています${NC}"
    increment_success
else
    echo -e "${YELLOW}⚠️  SSLセッションキャッシュが設定されていません${NC}"
    echo "   パフォーマンス向上のため、ssl_session_cacheの設定を推奨します"
    increment_warning
fi

echo ""

# ============================================================================
# 5. Certbot Managerの動作確認
# ============================================================================
echo -e "${BLUE}📋 5. Certbot Managerの動作確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$CERTBOT_MANAGER_EXISTS" = true ]; then
    # certbot-manager.shの存在確認
    if $DOCKER_COMPOSE_CMD exec -T certbot-manager test -f /app/certbot-manager.sh 2>/dev/null; then
        echo -e "${GREEN}✅ certbot-manager.shが存在します${NC}"
        increment_success
        
        # 実行権限の確認
        if $DOCKER_COMPOSE_CMD exec -T certbot-manager test -x /app/certbot-manager.sh 2>/dev/null; then
            echo -e "${GREEN}✅ certbot-manager.shに実行権限があります${NC}"
            increment_success
        else
            echo -e "${RED}❌ certbot-manager.shに実行権限がありません${NC}"
            increment_error
        fi
        
        # バージョン確認
        echo ""
        echo "Certbotバージョン:"
        if $DOCKER_COMPOSE_CMD exec -T certbot-manager certbot --version 2>&1; then
            increment_success
        else
            echo "バージョン確認失敗"
            increment_error
        fi
    else
        echo -e "${RED}❌ certbot-manager.shが見つかりません${NC}"
        increment_error
    fi
    
    # crontabの確認
    if $DOCKER_COMPOSE_CMD exec -T certbot-manager crontab -l 2>/dev/null | grep -q "certbot-manager.sh"; then
        echo -e "${GREEN}✅ crontabが設定されています${NC}"
        increment_success
        echo ""
        echo "crontab設定:"
        $DOCKER_COMPOSE_CMD exec -T certbot-manager crontab -l 2>/dev/null | grep "certbot-manager.sh"
    else
        echo -e "${YELLOW}⚠️  crontabが設定されていません${NC}"
        increment_warning
    fi
else
    echo -e "${YELLOW}⚠️  Certbot Managerが起動していないため、スキップします${NC}"
    increment_warning
fi

echo ""

# ============================================================================
# 6. 証明書取得テスト（ステージング環境）
# ============================================================================
if [ "$SKIP_CERT_TEST" = false ] && [ "$CERTBOT_MANAGER_EXISTS" = true ]; then
    echo -e "${BLUE}📋 6. 証明書取得テスト（ステージング環境）${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "注意: このテストは実際のDNS設定が必要です"
    echo "      ステージング環境で証明書取得を試みます"
    echo ""
    
    # 環境変数の確認
    if [ -n "${CERTBOT_EMAIL:-}" ] && [ -n "${CERTBOT_DOMAINS:-}" ]; then
        echo "環境変数:"
        echo "  CERTBOT_EMAIL: ${CERTBOT_EMAIL}"
        echo "  CERTBOT_DOMAINS: ${CERTBOT_DOMAINS}"
        echo "  CERTBOT_STAGING: ${CERTBOT_STAGING:-false}"
        echo ""
        
        # ステージング環境であることを確認
        if [ "${CERTBOT_STAGING:-false}" = "true" ]; then
            echo -e "${GREEN}✅ ステージング環境が設定されています${NC}"
            echo ""
            echo "証明書取得を試みます（時間がかかる場合があります）..."
            
            if $DOCKER_COMPOSE_CMD exec -T certbot-manager /app/certbot-manager.sh init 2>&1; then
                echo -e "${GREEN}✅ 証明書取得成功${NC}"
            else
                echo -e "${RED}❌ 証明書取得失敗${NC}"
                echo "   DNS設定を確認してください"
            fi
        else
            echo -e "${YELLOW}⚠️  ステージング環境が設定されていません（CERTBOT_STAGING=false）${NC}"
            echo "   本番環境での証明書取得はレート制限があるため、テストではスキップします"
        fi
    else
        echo -e "${YELLOW}⚠️  環境変数が設定されていません${NC}"
        echo "   CERTBOT_EMAIL と CERTBOT_DOMAINS を設定してください"
    fi
else
    echo -e "${BLUE}📋 6. 証明書取得テスト: スキップ${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$SKIP_CERT_TEST" = true ]; then
        echo "   --skip-cert-testオプションが指定されました"
    else
        echo "   Certbot Managerが起動していません"
    fi
fi

echo ""

# ============================================================================
# 7. 証明書の存在確認
# ============================================================================
echo -e "${BLUE}📋 7. 証明書の存在確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 証明書ディレクトリの確認
CERT_PATH="/etc/letsencrypt/live/${TEST_FQDN}"

if $DOCKER_COMPOSE_CMD exec -T nginx test -d "$CERT_PATH" 2>/dev/null; then
    echo -e "${GREEN}✅ 証明書ディレクトリが存在します: ${CERT_PATH}${NC}"
    
    # 個別ファイルの確認
    for file in fullchain.pem privkey.pem chain.pem; do
        if $DOCKER_COMPOSE_CMD exec -T nginx test -f "${CERT_PATH}/${file}" 2>/dev/null; then
            echo -e "${GREEN}✅ ${file}が存在します${NC}"
        else
            echo -e "${RED}❌ ${file}が存在しません${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  証明書ディレクトリが存在しません: ${CERT_PATH}${NC}"
    echo "   証明書を取得してからHTTPSテストを実行してください"
    CERT_EXISTS=false
fi

echo ""

# ============================================================================
# 8. ACME Challenge設定の確認
# ============================================================================
echo -e "${BLUE}📋 8. ACME Challenge設定の確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# .well-known/acme-challenge/へのアクセステスト
echo "ACME Challengeエンドポイントテスト..."

response=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${TEST_FQDN}" "http://localhost/.well-known/acme-challenge/test" 2>&1 || echo "000")

if [ "$response" = "404" ] || [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ ACME Challengeエンドポイントにアクセス可能（${response}）${NC}"
    echo "   注意: 404はファイルが存在しないことを示します（設定は正常）"
else
    echo -e "${YELLOW}⚠️  ACME Challengeエンドポイントのレスポンス: ${response}${NC}"
fi

echo ""

# ============================================================================
# 9. HTTP→HTTPSリダイレクトテスト
# ============================================================================
echo -e "${BLUE}📋 9. HTTP→HTTPSリダイレクトテスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "HTTP→HTTPSリダイレクトテスト: http://localhost/ (Host: ${TEST_FQDN})"

response=$(curl -s -I -H "Host: ${TEST_FQDN}" "http://localhost/" 2>&1)
http_code=$(echo "$response" | grep -i "^HTTP" | awk '{print $2}')
location=$(echo "$response" | grep -i "^Location:" | awk '{print $2}' | tr -d '\r')

if [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
    echo -e "${GREEN}✅ リダイレクトが設定されています（${http_code}）${NC}"
    if echo "$location" | grep -q "^https://"; then
        echo -e "${GREEN}✅ HTTPSへリダイレクトされます: ${location}${NC}"
    else
        echo -e "${YELLOW}⚠️  リダイレクト先: ${location}${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  リダイレクトが設定されていません（HTTPステータス: ${http_code}）${NC}"
    echo "   注意: 証明書が存在しない場合、リダイレクトは設定されません"
fi

echo ""

# ============================================================================
# 10. HTTPS接続テスト
# ============================================================================
if [ "${CERT_EXISTS:-true}" != "false" ]; then
    echo -e "${BLUE}📋 10. HTTPS接続テスト${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "HTTPS接続テスト: https://localhost/health (Host: ${TEST_FQDN})"
    echo "注意: 自己署名証明書の場合、-kオプションを使用します"
    
    response=$(curl -s -k -I -H "Host: ${TEST_FQDN}" "https://localhost/health" 2>&1)
    http_code=$(echo "$response" | grep -i "^HTTP" | awk '{print $2}')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ HTTPS接続成功（${http_code}）${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTPS接続のHTTPステータス: ${http_code}${NC}"
        echo "   証明書またはNginx設定を確認してください"
    fi
else
    echo -e "${BLUE}📋 10. HTTPS接続テスト: スキップ${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   証明書が存在しないため、HTTPSテストをスキップします"
fi

echo ""

# ============================================================================
# 11. 証明書有効性テスト
# ============================================================================
if [ "${CERT_EXISTS:-true}" != "false" ]; then
    echo -e "${BLUE}📋 11. 証明書有効性テスト${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "証明書の有効期限を確認します..."
    
    if cert_info=$(echo | openssl s_client -connect localhost:443 -servername "${TEST_FQDN}" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null); then
        echo -e "${GREEN}✅ 証明書情報を取得しました${NC}"
        echo ""
        echo "${cert_info}"
        echo ""
        
        # 発行者情報
        if issuer=$(echo | openssl s_client -connect localhost:443 -servername "${TEST_FQDN}" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null); then
            echo "発行者: ${issuer}"
        fi
    else
        echo -e "${YELLOW}⚠️  証明書情報を取得できませんでした${NC}"
        echo "   HTTPSが有効になっていない可能性があります"
    fi
else
    echo -e "${BLUE}📋 11. 証明書有効性テスト: スキップ${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   証明書が存在しないため、証明書テストをスキップします"
fi

echo ""

# ============================================================================
# 12. セキュリティヘッダーテスト
# ============================================================================
if [ "${CERT_EXISTS:-true}" != "false" ]; then
    echo -e "${BLUE}📋 12. セキュリティヘッダーテスト${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "セキュリティヘッダーを確認します..."
    
    headers=$(curl -s -k -I -H "Host: ${TEST_FQDN}" "https://localhost/" 2>&1)
    
    # Strict-Transport-Security (HSTS)
    if echo "$headers" | grep -iq "Strict-Transport-Security"; then
        hsts_value=$(echo "$headers" | grep -i "Strict-Transport-Security:" | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
        echo -e "${GREEN}✅ HSTS: ${hsts_value}${NC}"
    else
        echo -e "${RED}❌ HSTS: 未設定${NC}"
    fi
    
    # X-Frame-Options
    if echo "$headers" | grep -iq "X-Frame-Options"; then
        xfo_value=$(echo "$headers" | grep -i "X-Frame-Options:" | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
        echo -e "${GREEN}✅ X-Frame-Options: ${xfo_value}${NC}"
    else
        echo -e "${RED}❌ X-Frame-Options: 未設定${NC}"
    fi
    
    # X-Content-Type-Options
    if echo "$headers" | grep -iq "X-Content-Type-Options"; then
        xcto_value=$(echo "$headers" | grep -i "X-Content-Type-Options:" | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
        echo -e "${GREEN}✅ X-Content-Type-Options: ${xcto_value}${NC}"
    else
        echo -e "${RED}❌ X-Content-Type-Options: 未設定${NC}"
    fi
    
    # Content-Security-Policy（オプション）
    if echo "$headers" | grep -iq "Content-Security-Policy"; then
        csp_value=$(echo "$headers" | grep -i "Content-Security-Policy:" | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
        echo -e "${GREEN}✅ CSP: ${csp_value}${NC}"
    else
        echo -e "${YELLOW}⚠️  CSP: 未設定（将来的に実装予定）${NC}"
    fi
else
    echo -e "${BLUE}📋 12. セキュリティヘッダーテスト: スキップ${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   証明書が存在しないため、セキュリティヘッダーテストをスキップします"
fi

echo ""

# ============================================================================
# 13. SSL/TLS設定の確認
# ============================================================================
if [ "${CERT_EXISTS:-true}" != "false" ]; then
    echo -e "${BLUE}📋 13. SSL/TLS設定の確認${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "SSL/TLS設定を確認します..."
    
    if ssl_info=$(echo | openssl s_client -connect localhost:443 -servername "${TEST_FQDN}" 2>/dev/null); then
        # プロトコルバージョン
        protocol=$(echo "$ssl_info" | grep "Protocol" | awk '{print $3}')
        if [ -n "$protocol" ]; then
            echo -e "${GREEN}✅ プロトコル: ${protocol}${NC}"
            
            # TLSv1.2またはTLSv1.3のみを許可しているか確認
            if [ "$protocol" = "TLSv1.2" ] || [ "$protocol" = "TLSv1.3" ]; then
                echo -e "${GREEN}   セキュアなプロトコルバージョンです${NC}"
            else
                echo -e "${YELLOW}   警告: TLSv1.2またはTLSv1.3の使用を推奨します${NC}"
            fi
        fi
        
        # 暗号スイート
        cipher=$(echo "$ssl_info" | grep "Cipher" | awk '{print $3}')
        if [ -n "$cipher" ]; then
            echo -e "${GREEN}✅ 暗号スイート: ${cipher}${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  SSL/TLS情報を取得できませんでした${NC}"
    fi
else
    echo -e "${BLUE}📋 13. SSL/TLS設定の確認: スキップ${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   証明書が存在しないため、SSL/TLS設定テストをスキップします"
fi

echo ""

# ============================================================================
# 14. ログの確認
# ============================================================================
echo -e "${BLUE}📋 14. ログの確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Nginxログ（最新10行）:"
$DOCKER_COMPOSE_CMD logs --tail=10 nginx 2>&1 | head -20

if [ "$CERTBOT_MANAGER_EXISTS" = true ]; then
    echo ""
    echo "Certbot Managerログ（最新10行）:"
    $DOCKER_COMPOSE_CMD logs --tail=10 certbot-manager 2>&1 | head -20
fi

echo ""

# ============================================================================
# テスト結果のサマリー
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  SSL/TLS証明書管理機能テスト完了${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "テスト結果サマリー:"
echo -e "  ${GREEN}✅ 成功: ${SUCCESS_COUNT}${NC}"
echo -e "  ${YELLOW}⚠️  警告: ${WARNING_COUNT}${NC}"
echo -e "  ${RED}❌ エラー: ${ERROR_COUNT}${NC}"
echo ""

if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${RED}❌ テストに失敗しました（エラー: ${ERROR_COUNT}件）${NC}"
    echo ""
    echo "エラーの解決方法:"
    echo "  1. エラーメッセージを確認してください"
    echo "  2. docker-compose logs でログを確認してください"
    echo "  3. 設定ファイルを確認してください"
    exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  テストは完了しましたが、警告があります（警告: ${WARNING_COUNT}件）${NC}"
    echo ""
else
    echo -e "${GREEN}✅ すべてのテストが成功しました${NC}"
    echo ""
fi

echo "次のステップ:"
echo "  1. 証明書が存在しない場合、Certbot Managerで証明書を取得してください"
echo "     例: docker-compose exec certbot-manager /app/certbot-manager.sh init"
echo ""
echo "  2. HTTPS接続を確認してください"
echo "     例: curl -k https://localhost/ -H \"Host: ${TEST_FQDN}\""
echo ""
echo "  3. 証明書の自動更新を確認してください"
echo "     例: docker-compose exec certbot-manager /app/certbot-manager.sh renew"
echo ""
echo "  4. セキュリティヘッダーがすべて設定されていることを確認してください"
echo ""
echo "  5. 本番環境デプロイ前にステージング環境で十分テストしてください"
echo "     CERTBOT_STAGING=true を設定してテストすることを推奨します"
echo ""

exit $ERROR_COUNT
