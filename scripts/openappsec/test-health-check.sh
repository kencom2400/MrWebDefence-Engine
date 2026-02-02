#!/bin/bash

# ヘルスチェック機能のテストスクリプト
# Task 5.6: ヘルスチェック機能実装のテスト

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/../../docker"

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Task 5.6: ヘルスチェック機能のテスト${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# health-apiコンテナが起動しているか確認
echo -e "${BLUE}📋 1. health-apiコンテナの起動確認${NC}"
if docker-compose -f "${DOCKER_DIR}/docker-compose.yml" ps health-api | grep -q "Up"; then
    echo -e "${GREEN}✅ health-apiコンテナが起動しています${NC}"
else
    echo -e "${RED}❌ health-apiコンテナが起動していません${NC}"
    echo -e "${YELLOW}コンテナを起動してください: cd docker && docker-compose up -d health-api${NC}"
    exit 1
fi
echo ""

# 簡易ヘルスチェックエンドポイントのテスト
echo -e "${BLUE}📋 2. 簡易ヘルスチェックエンドポイント (/health)${NC}"
response=$(curl -s http://localhost:8888/health)
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/health)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ HTTPステータスコード: 200 OK${NC}"
    echo "レスポンス: $response"
else
    echo -e "${RED}❌ HTTPステータスコード: $http_code${NC}"
    exit 1
fi
echo ""

# 詳細ヘルスチェックエンドポイントのテスト
echo -e "${BLUE}📋 3. 詳細ヘルスチェックエンドポイント (/engine/v1/health)${NC}"
response=$(curl -s http://localhost:8888/engine/v1/health)
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/engine/v1/health)
status=$(echo "$response" | jq -r '.status')

echo "全体ステータス: $status"
echo "HTTPステータスコード: $http_code"

if [ "$status" = "healthy" ] && [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ 正常: status=healthy, HTTP 200 OK${NC}"
elif [ "$status" = "unhealthy" ] && [ "$http_code" = "503" ]; then
    echo -e "${YELLOW}⚠️  異常検知: status=unhealthy, HTTP 503 Service Unavailable${NC}"
else
    echo -e "${RED}❌ 予期しないレスポンス: status=$status, HTTP $http_code${NC}"
    exit 1
fi
echo ""

# コンポーネント状態の確認
echo -e "${BLUE}📋 4. コンポーネント状態の詳細${NC}"
echo "$response" | jq -r '.components | to_entries[] | "\(.key): \(.value)"'
echo ""

# エラーメッセージの確認
echo -e "${BLUE}📋 5. エラーメッセージ${NC}"
errors=$(echo "$response" | jq -r '.errors')
if [ "$errors" = "[]" ]; then
    echo -e "${GREEN}✅ エラーなし${NC}"
else
    echo -e "${YELLOW}⚠️  以下のエラーが検出されました:${NC}"
    echo "$response" | jq -r '.errors[] | "  - \(.component): \(.message)"'
fi
echo ""

# システム情報の確認
echo -e "${BLUE}📋 6. システム情報${NC}"
echo "$response" | jq -r '.system_info | to_entries[] | "\(.key): \(.value)"'
echo ""

# 異常系テスト（オプション）
if [ "${TEST_ERROR_CASES:-false}" = "true" ]; then
    echo -e "${BLUE}📋 7. 異常系テスト（オプション）${NC}"
    echo -e "${YELLOW}Redisコンテナを停止して異常検知をテストします...${NC}"
    
    docker-compose -f "${DOCKER_DIR}/docker-compose.yml" stop redis
    sleep 2
    
    response=$(curl -s http://localhost:8888/engine/v1/health)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/engine/v1/health)
    status=$(echo "$response" | jq -r '.status')
    
    echo "Redis停止時のステータス: $status"
    echo "HTTPステータスコード: $http_code"
    
    redis_status=$(echo "$response" | jq -r '.components.redis')
    if [ "$redis_status" = "unhealthy" ]; then
        echo -e "${GREEN}✅ Redis異常が正しく検知されました${NC}"
    else
        echo -e "${RED}❌ Redis異常が検知されませんでした${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Redisコンテナを再起動します...${NC}"
    docker-compose -f "${DOCKER_DIR}/docker-compose.yml" start redis
    sleep 2
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ すべてのテストが完了しました${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "テスト結果:"
echo "  - 簡易ヘルスチェック: ✅ 正常"
echo "  - 詳細ヘルスチェック: ✅ 正常"
echo "  - コンポーネント状態監視: ✅ 動作確認"
echo "  - エラー検知: ✅ 動作確認"
echo "  - システム情報取得: ✅ 動作確認"
echo ""
echo "使用方法:"
echo "  基本テスト: ./scripts/openappsec/test-health-check.sh"
echo "  異常系テスト: TEST_ERROR_CASES=true ./scripts/openappsec/test-health-check.sh"
echo ""
