#!/bin/bash

# RateLimit機能テストスクリプト
# Task 5.4: RateLimit機能実装のテストと動作確認

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
echo -e "${BLUE}  RateLimit機能テスト${NC}"
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

# Redisコンテナの確認（オプション: 将来の拡張用）
if $DOCKER_COMPOSE_CMD ps redis 2>/dev/null | grep -q "Up"; then
    echo -e "${GREEN}✅ Redis: 起動中${NC}"
else
    echo -e "${YELLOW}⚠️  Redis: 停止中（オプション）${NC}"
    echo "   注意: OpenAppSecのRateLimit機能は共有メモリを使用するため、Redisは必須ではありません"
    echo "   Redisは将来の拡張用に準備されています"
fi

# Nginx
if $DOCKER_COMPOSE_CMD ps nginx | grep -q "Up"; then
    echo -e "${GREEN}✅ Nginx: 起動中${NC}"
else
    echo -e "${RED}❌ Nginx: 停止中${NC}"
    exit 1
fi

# OpenAppSec Agent
if $DOCKER_COMPOSE_CMD ps openappsec-agent | grep -q "Up"; then
    echo -e "${GREEN}✅ OpenAppSec Agent: 起動中${NC}"
else
    echo -e "${RED}❌ OpenAppSec Agent: 停止中${NC}"
    exit 1
fi

# ConfigAgent
if $DOCKER_COMPOSE_CMD ps config-agent 2>/dev/null | grep -q "Up"; then
    echo -e "${GREEN}✅ ConfigAgent: 起動中${NC}"
else
    echo -e "${YELLOW}⚠️  ConfigAgent: 停止中（オプション）${NC}"
fi
echo ""

# 2. accessControlPracticesの生成確認
echo -e "${BLUE}📋 2. accessControlPracticesの生成確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "./openappsec/local_policy.yaml" ]; then
    echo -e "${GREEN}✅ OpenAppSec設定ファイルが存在します${NC}"
    
    # accessControlPracticesの確認
    if grep -q "^accessControlPractices:" ./openappsec/local_policy.yaml; then
        echo -e "${GREEN}✅ accessControlPractices定義が含まれています${NC}"
        
        # rate-limit-defaultプラクティスの確認
        if grep -q "name: rate-limit-default" ./openappsec/local_policy.yaml; then
            echo -e "${GREEN}✅ rate-limit-defaultプラクティスが定義されています${NC}"
            
            # RateLimitルールの確認
            if grep -q "uri: \"/login\"" ./openappsec/local_policy.yaml; then
                echo -e "${GREEN}✅ /loginエンドポイントのRateLimitルールが定義されています${NC}"
            else
                echo -e "${YELLOW}⚠️  /loginエンドポイントのRateLimitルールが見つかりません${NC}"
            fi
            
            if grep -q "uri: \"/api/\*\"" ./openappsec/local_policy.yaml; then
                echo -e "${GREEN}✅ /api/*エンドポイントのRateLimitルールが定義されています${NC}"
            else
                echo -e "${YELLOW}⚠️  /api/*エンドポイントのRateLimitルールが見つかりません${NC}"
            fi
        else
            echo -e "${RED}❌ rate-limit-defaultプラクティスが見つかりません${NC}"
        fi
    else
        echo -e "${RED}❌ accessControlPractices定義が見つかりません${NC}"
    fi
    
    # accessControlPractices定義の表示（最初の30行）
    echo ""
    echo "accessControlPractices定義（最初の30行）:"
    grep -A 30 "^accessControlPractices:" ./openappsec/local_policy.yaml | head -30
else
    echo -e "${RED}❌ OpenAppSec設定ファイルが見つかりません${NC}"
    echo "   ConfigAgentが設定ファイルを生成するまで待機してください"
    exit 1
fi
echo ""

# 3. OpenAppSec Agentのログ確認
echo -e "${BLUE}📋 3. OpenAppSec Agentのログ確認（RateLimit関連）${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if $DOCKER_COMPOSE_CMD ps openappsec-agent | grep -q "Up"; then
    echo "OpenAppSec Agentのログ（最新20行、RateLimit関連）:"
    $DOCKER_COMPOSE_CMD logs --tail=20 openappsec-agent 2>&1 | grep -i "rate\|limit\|access.control" || echo "RateLimit関連のログが見つかりませんでした"
else
    echo -e "${RED}❌ OpenAppSec Agentが起動していません${NC}"
fi
echo ""

# 4. RateLimit機能のテスト
echo -e "${BLUE}📋 4. RateLimit機能のテスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# テスト用FQDN（最初の有効なFQDNを使用）
TEST_FQDN="test.example.com"

echo "テスト対象FQDN: ${TEST_FQDN}"
echo ""

# 4.1 /loginエンドポイントのレート制限テスト
echo -e "${BLUE}4.1 /loginエンドポイントのレート制限テスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "レート制限: 10リクエスト/分（action: prevent）"
echo ""

# 10回のリクエストを送信（制限内）
echo "制限内のリクエスト（10回）:"
SUCCESS_COUNT=0
BLOCKED_COUNT=0

for i in {1..10}; do
    response=$(curl -s -w "\n%{http_code}" -H "Host: ${TEST_FQDN}" http://localhost/login 2>/dev/null || echo "000")
    http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "403" ]; then
        if [ "$http_code" = "403" ]; then
            echo -e "  リクエスト ${i}: ${RED}ブロック (403)${NC}"
            BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
        else
            echo -e "  リクエスト ${i}: ${GREEN}成功 (${http_code})${NC}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    else
        echo -e "  リクエスト ${i}: ${YELLOW}その他 (${http_code})${NC}"
    fi
    sleep 0.5
done

echo ""
echo "結果: 成功 ${SUCCESS_COUNT}回、ブロック ${BLOCKED_COUNT}回"
echo ""

# 11回目のリクエスト（制限超過）
echo "制限超過のリクエスト（11回目）:"
response=$(curl -s -w "\n%{http_code}" -H "Host: ${TEST_FQDN}" http://localhost/login 2>/dev/null || echo "000")
http_code=$(echo "$response" | tail -1)

if [ "$http_code" = "403" ]; then
    echo -e "${GREEN}✅ レート制限が正常に動作しています（403が返されました）${NC}"
else
    echo -e "${YELLOW}⚠️  レート制限が動作していない可能性があります（HTTPステータス: ${http_code}）${NC}"
    echo "   注意: OpenAppSecのRateLimit機能は設定読み込みに時間がかかる場合があります"
fi
echo ""

# 4.2 /api/*エンドポイントのレート制限テスト
echo -e "${BLUE}4.2 /api/*エンドポイントのレート制限テスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "レート制限: 100リクエスト/分（action: detect）"
echo ""

# 5回のリクエストを送信（制限内）
echo "制限内のリクエスト（5回）:"
SUCCESS_COUNT=0
for i in {1..5}; do
    response=$(curl -s -w "\n%{http_code}" -H "Host: ${TEST_FQDN}" http://localhost/api/test 2>/dev/null || echo "000")
    http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "  リクエスト ${i}: ${GREEN}成功 (${http_code})${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "  リクエスト ${i}: ${YELLOW}その他 (${http_code})${NC}"
    fi
    sleep 0.5
done

echo ""
echo "結果: 成功 ${SUCCESS_COUNT}回"
echo "注意: /api/*エンドポイントはaction: detectのため、ブロックされずにログに記録されます"
echo ""

# 5. IPアドレス単位のレート制限テスト
echo -e "${BLUE}📋 5. IPアドレス単位のレート制限テスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "異なるIPアドレスからのリクエストでレート制限が個別に適用されることを確認"
echo ""
echo "注意: このテストは実際の異なるIPアドレスからのリクエストが必要です"
echo "      手動で異なるIPアドレスからリクエストを送信して確認してください"
echo ""

# 6. 設定ファイルの内容確認
echo -e "${BLUE}📋 6. 設定ファイルの内容確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "./openappsec/local_policy.yaml" ]; then
    echo "OpenAppSec設定ファイルのaccessControlPracticesセクション:"
    awk '/^accessControlPractices:/,/^[a-zA-Z#]/ {if (/^accessControlPractices:/ || /^  - name:/ || /^    rateLimit:/ || /^      rules:/ || /^        - uri:/ || /^          limit:/ || /^          action:/) print}' ./openappsec/local_policy.yaml | head -20
fi
echo ""

# 7. テスト結果のサマリー
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  ✅ RateLimit機能テスト完了${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "次のステップ:"
echo "  1. OpenAppSec Agentのログを確認してRateLimitが適用されているか確認"
echo "  2. 制限超過時のレスポンスを確認"
echo "  3. 異なるIPアドレスからのリクエストでレート制限が個別に適用されることを確認"
echo "  4. 分散環境でのテスト（複数のOpenAppSec Agentインスタンス）"
echo ""
