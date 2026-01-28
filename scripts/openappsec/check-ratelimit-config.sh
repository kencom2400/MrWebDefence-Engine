#!/bin/bash
# OpenAppSec RateLimit設定確認スクリプト
# 実際に読み込まれているRateLimit設定を確認します

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OpenAppSec RateLimit設定確認 ===${NC}"
echo ""

# Docker Composeが実行中か確認
if ! docker-compose -f "$DOCKER_DIR/docker-compose.yml" ps | grep -q "openappsec-agent.*Up"; then
    echo -e "${RED}❌ OpenAppSec Agentコンテナが起動していません${NC}"
    exit 1
fi

echo -e "${GREEN}1. エージェントステータス確認${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --status --extended 2>&1 | grep -E "(Status|Policy|Version)" | head -10
echo ""

echo -e "${GREEN}2. 設定ファイル（YAML）のaccessControlPractices確認${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>&1 | \
    grep -A 20 "^accessControlPractices:" | head -25
echo ""

echo -e "${GREEN}3. 実際に読み込まれている設定（policy.json）の確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【accessControlPractices定義】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.accessControlPractices[]? | select(.name == "rate-limit-default") | "name: \(.name)\npracticeMode: \(.practiceMode // "N/A")\nrateLimit: \(.rateLimit // "N/A")"' 2>/dev/null || \
    echo "accessControlPractices定義が見つかりません"
echo ""

echo -e "${YELLOW}【RateLimitルール】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.accessControlPractices[]? | select(.name == "rate-limit-default") | .rateLimit.rules[]? | "uri: \(.uri // "N/A")\nlimit: \(.limit // "N/A")\nunit: \(.unit // "N/A")\naction: \(.action // "N/A")\n---"' 2>/dev/null || \
    echo "RateLimitルールが見つかりません"
echo ""

echo -e "${YELLOW}【policies.default.accessControlPractices】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.policies.default.accessControlPractices[]?' 2>/dev/null || \
    echo "default.accessControlPracticesが見つかりません"
echo ""

echo -e "${YELLOW}【policies.specificRules[].accessControlPractices】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.policies.specificRules[]? | "host: \(.host // "N/A")\naccessControlPractices: \(.accessControlPractices // [])\n---"' 2>/dev/null | head -20 || \
    echo "specificRules.accessControlPracticesが見つかりません"
echo ""

echo -e "${GREEN}4. accessControlV2ディレクトリの確認${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    ls -la /etc/cp/conf/accessControlV2/ 2>&1 | head -10 || \
    echo "accessControlV2ディレクトリが見つかりません"
echo ""

echo -e "${GREEN}5. ポリシーの再読み込み${NC}"
echo "----------------------------------------"
echo "ポリシーを再読み込みしますか？ (y/N)"
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        open-appsec-ctl -lc http-transaction-handler 2>&1
    echo ""
    echo "✅ ポリシーを再読み込みしました"
    echo "5秒待機してからステータスを確認します..."
    sleep 5
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        open-appsec-ctl --status 2>&1 | grep -A 5 "Policy" | head -10
else
    echo "スキップしました"
fi
echo ""

echo -e "${BLUE}=== 確認完了 ===${NC}"
