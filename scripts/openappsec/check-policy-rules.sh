#!/bin/bash
# OpenAppSec ポリシールール確認スクリプト
# open-appsec-ctl ツールを使用してルール設定を確認します

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

echo -e "${BLUE}=== OpenAppSec ポリシールール確認 ===${NC}"
echo ""

# Docker Composeが実行中か確認
if ! docker-compose -f "$DOCKER_DIR/docker-compose.yml" ps | grep -q "openappsec-agent.*Up"; then
    echo -e "${RED}❌ OpenAppSec Agentコンテナが起動していません${NC}"
    exit 1
fi

echo -e "${GREEN}1. エージェントステータス確認${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --status --extended
echo ""

echo -e "${GREEN}2. ポリシーファイル一覧${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --list-policies
echo ""

echo -e "${GREEN}3. 現在のポリシー設定（/ext/appsec/local_policy.yaml）${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml
echo ""

echo -e "${GREEN}4. SQL Injection / XSS 関連設定の抽出${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【webAttacks設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 20 "webAttacks:" || echo "webAttacks設定が見つかりません"

echo ""
echo -e "${YELLOW}【protections設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 10 "protections:" || echo "protections設定が見つかりません"

echo ""
echo -e "${YELLOW}【minimumConfidence設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep "minimumConfidence" || echo "minimumConfidence設定が見つかりません"

echo ""
echo -e "${YELLOW}【mode設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -E "^\s+mode:" | head -5 || echo "mode設定が見つかりません"

echo ""
echo -e "${GREEN}5. RateLimit設定の確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【YAMLファイルのaccessControlPractices定義】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 20 "^accessControlPractices:" | head -25 || echo "accessControlPractices定義が見つかりません"

echo ""
echo -e "${YELLOW}【実際に読み込まれているRateLimit設定（policy.json）】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.accessControlV2.rulebase.rateLimit[]? | "uri: \(.uri // "N/A")\nlimit: \(.limit // "N/A")\nunit: \(.unit // "N/A")\naction: \(.action // "N/A")\n---"' 2>/dev/null || \
    echo "RateLimit設定が見つかりません（空の配列の可能性）"

echo ""
echo -e "${YELLOW}【accessControlV2.policyファイル】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/accessControlV2/accessControlV2.policy 2>/dev/null | \
    jq '.' 2>/dev/null || echo "accessControlV2.policyファイルを読み込めませんでした"

echo ""
echo -e "${GREEN}6. 実際に読み込まれている設定（policy.json）の確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【WAAP設定（WebApplicationSecurity）】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.waap.WAAP.WebApplicationSecurity[]? | "host: \(.assetName // "N/A")\nmode: \(.webAttackMitigationMode // "N/A")\npracticeName: \(.practiceName // "N/A")\n---"' 2>/dev/null | head -20 || \
    echo "WAAP設定が見つかりません"

echo ""
echo -e "${YELLOW}【Triggers設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.triggers[]? | "name: \(.name // "N/A")\ntype: \(.triggerType // "N/A")\n---"' 2>/dev/null | head -20 || \
    echo "Triggers設定が見つかりません"

echo ""
echo -e "${YELLOW}【Exceptions設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.exceptions | length' 2>/dev/null | \
    xargs -I {} echo "例外ルール数: {}" || \
    echo "Exceptions設定が見つかりません"

echo ""
echo -e "${GREEN}5. ポリシーファイルの生の内容（YAML）${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /ext/appsec/local_policy.yaml 2>/dev/null | head -100 || echo "ポリシーファイルを読み込めませんでした"

echo ""
echo -e "${BLUE}=== 確認完了 ===${NC}"
