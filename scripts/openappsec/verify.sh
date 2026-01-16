#!/bin/bash

# 動作確認スクリプト（簡易版）
# 基本的な動作確認を簡単に実行

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  動作確認スクリプト${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. サービス状態確認
echo -e "${BLUE}📋 1. サービス状態確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

$DOCKER_COMPOSE_CMD ps
echo ""

# 2. ヘルスチェック
echo -e "${BLUE}📋 2. ヘルスチェック${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Nginx
if $DOCKER_COMPOSE_CMD ps nginx | grep -q "Up"; then
    echo -e "${GREEN}✅ Nginx: 起動中${NC}"
else
    echo -e "${RED}❌ Nginx: 停止中${NC}"
fi

# OpenAppSec Agent
if $DOCKER_COMPOSE_CMD ps openappsec-agent | grep -q "Up"; then
    echo -e "${GREEN}✅ OpenAppSec Agent: 起動中${NC}"
else
    echo -e "${RED}❌ OpenAppSec Agent: 停止中${NC}"
fi

# ConfigAgent（オプション）
if $DOCKER_COMPOSE_CMD ps config-agent 2>/dev/null | grep -q "Up"; then
    echo -e "${GREEN}✅ ConfigAgent: 起動中${NC}"
else
    echo -e "${YELLOW}⚠️  ConfigAgent: 停止中（オプション）${NC}"
fi

# Mock API（オプション）
if $DOCKER_COMPOSE_CMD ps mock-api 2>/dev/null | grep -q "Up"; then
    echo -e "${GREEN}✅ Mock API: 起動中${NC}"
else
    echo -e "${YELLOW}⚠️  Mock API: 停止中（オプション）${NC}"
fi
echo ""

# 3. HTTPリクエストテスト
echo -e "${BLUE}📋 3. HTTPリクエストテスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FQDNS=("test.example.com" "example1.com" "example2.com" "example3.com")
SUCCESS_COUNT=0
FAIL_COUNT=0

for fqdn in "${FQDNS[@]}"; do
    echo -n "  ${fqdn}: "
    if curl -s -m 5 -H "Host: ${fqdn}" http://localhost/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}❌ 失敗${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ すべてのFQDNでHTTPリクエストが成功しました${NC}"
else
    echo -e "${YELLOW}⚠️  ${FAIL_COUNT}個のFQDNでHTTPリクエストが失敗しました${NC}"
fi
echo ""

# 4. 設定ファイルの確認
echo -e "${BLUE}📋 4. 設定ファイルの確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# OpenAppSec設定ファイル
if [ -f "./openappsec/local_policy.yaml" ]; then
    echo -e "${GREEN}✅ OpenAppSec設定ファイル: 存在${NC}"
    FQDN_COUNT=$(grep -c "host:" ./openappsec/local_policy.yaml 2>/dev/null || echo "0")
    echo "   FQDN設定数: ${FQDN_COUNT}"
else
    echo -e "${RED}❌ OpenAppSec設定ファイル: 見つかりません${NC}"
fi

# Nginx設定ファイル
NGINX_CONFIG_COUNT=$(find ./nginx/conf.d -name "*.conf" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$NGINX_CONFIG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Nginx設定ファイル: ${NGINX_CONFIG_COUNT}個${NC}"
else
    echo -e "${YELLOW}⚠️  Nginx設定ファイル: 見つかりません${NC}"
fi
echo ""

# 5. ログの確認（最新5行）
echo -e "${BLUE}📋 5. ログの確認（最新5行）${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Nginx:"
$DOCKER_COMPOSE_CMD logs --tail=5 nginx 2>/dev/null | tail -3 || echo "  ログを取得できませんでした"
echo ""

echo "OpenAppSec Agent:"
$DOCKER_COMPOSE_CMD logs --tail=5 openappsec-agent 2>/dev/null | tail -3 || echo "  ログを取得できませんでした"
echo ""

# 結果サマリー
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}  ✅ 動作確認完了: すべて正常${NC}"
    exit 0
else
    echo -e "${YELLOW}  ⚠️  動作確認完了: 一部に問題があります${NC}"
    echo ""
    echo "詳細な確認:"
    echo "  ./scripts/openappsec/test-integration.sh"
    echo "  ./scripts/openappsec/health-check.sh"
    exit 1
fi
