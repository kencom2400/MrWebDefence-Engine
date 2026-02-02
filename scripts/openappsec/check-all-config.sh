#!/bin/bash
# OpenAppSec 全設定確認スクリプト
# 実際に読み込まれているすべての設定値を確認します

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

echo -e "${BLUE}=== OpenAppSec 全設定確認 ===${NC}"
echo ""

# Docker Composeが実行中か確認
if ! docker-compose -f "$DOCKER_DIR/docker-compose.yml" ps | grep -q "openappsec-agent.*Up"; then
    echo -e "${RED}❌ OpenAppSec Agentコンテナが起動していません${NC}"
    exit 1
fi

echo -e "${GREEN}1. エージェント基本情報${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --status 2>&1 | grep -E "(Version|Agent ID|Management mode|Policy load status)" | head -10
echo ""

echo -e "${GREEN}2. 設定ファイル（YAML）の概要${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>&1 | head -50
echo ""

echo -e "${GREEN}3. 実際に読み込まれている設定（policy.json）の概要${NC}"
echo "----------------------------------------"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '{
        version: .version,
        waap_count: (.waap.WAAP.WebApplicationSecurity | length),
        triggers_count: (.triggers | length),
        exceptions_count: (.exceptions | length),
        accessControlV2_rateLimit_count: (.accessControlV2.rulebase.rateLimit | length),
        accessControlV2_accessControl_count: (.accessControlV2.rulebase.accessControl | length)
    }' 2>/dev/null || echo "policy.jsonを読み込めませんでした"
echo ""

echo -e "${GREEN}4. WAAP設定（WebApplicationSecurity）${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【設定数】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.waap.WAAP.WebApplicationSecurity | length' 2>/dev/null || echo "0"

echo ""
echo -e "${YELLOW}【各ホストの設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.waap.WAAP.WebApplicationSecurity[]? | 
        "host: \(.assetName // "N/A")
mode: \(.webAttackMitigationMode // "N/A")
practiceName: \(.practiceName // "N/A")
csrfProtection: \(.csrfProtection // "N/A")
openRedirect: \(.openRedirect // "N/A")
errorDisclosure: \(.errorDisclosure // "N/A")
triggers: \(.triggers | length)個
---"' 2>/dev/null | head -40 || \
    echo "WAAP設定が見つかりません"
echo ""

echo -e "${GREEN}5. ThreatPrevention設定${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【YAMLファイルの定義】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 30 "^threatPreventionPractices:" | head -35 || \
    echo "threatPreventionPractices定義が見つかりません"

echo ""
echo -e "${YELLOW}【実際に読み込まれている設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.waap.WAAP.WebApplicationSecurity[0]? | 
        "practiceName: \(.practiceName // "N/A")
webAttackMitigationMode: \(.webAttackMitigationMode // "N/A")
minimumConfidence: \(.practiceAdvancedConfig.minimumConfidence // "N/A")
maxUrlSizeBytes: \(.practiceAdvancedConfig.urlMaxSize // "N/A")
maxBodySizeKb: \(.practiceAdvancedConfig.httpRequestBodyMaxSize // "N/A")"' 2>/dev/null || \
    echo "ThreatPrevention設定が見つかりません"
echo ""

echo -e "${GREEN}6. RateLimit設定${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【YAMLファイルのaccessControlPractices定義】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 20 "^accessControlPractices:" | head -25 || \
    echo "accessControlPractices定義が見つかりません"

echo ""
echo -e "${YELLOW}【実際に読み込まれているRateLimit設定（policy.json）】${NC}"
rate_limit_count=$(docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.accessControlV2.rulebase.rateLimit | length' 2>/dev/null || echo "0")

if [ "$rate_limit_count" = "0" ]; then
    echo -e "${RED}❌ RateLimit設定が読み込まれていません（空の配列）${NC}"
    echo ""
    echo -e "${YELLOW}【accessControlV2.policyファイル】${NC}"
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        cat /etc/cp/conf/accessControlV2/accessControlV2.policy 2>/dev/null | \
        jq '.' 2>/dev/null || echo "accessControlV2.policyファイルを読み込めませんでした"
else
    echo -e "${GREEN}✅ RateLimit設定が読み込まれています（${rate_limit_count}個のルール）${NC}"
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        cat /etc/cp/conf/policy.json 2>/dev/null | \
        jq -r '.accessControlV2.rulebase.rateLimit[]? | 
            "uri: \(.uri // "N/A")
limit: \(.limit // "N/A")
unit: \(.unit // "N/A")
action: \(.action // "N/A")
---"' 2>/dev/null
fi
echo ""

echo -e "${GREEN}7. Triggers設定${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【YAMLファイルの定義】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 25 "^logTriggers:" | head -30 || \
    echo "logTriggers定義が見つかりません"

echo ""
echo -e "${YELLOW}【実際に読み込まれている設定】${NC}"
trigger_count=$(docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.triggers | length' 2>/dev/null || echo "0")
echo "Triggers数: ${trigger_count}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.triggers[]? | "name: \(.name // "N/A")\ntype: \(.triggerType // "N/A")\n---"' 2>/dev/null | head -20 || \
    echo "Triggers設定が見つかりません"
echo ""

echo -e "${GREEN}8. Exceptions設定${NC}"
echo "----------------------------------------"
exception_count=$(docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.exceptions | length' 2>/dev/null || echo "0")
echo "例外ルール数: ${exception_count}"
if [ "$exception_count" -gt 0 ]; then
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        cat /etc/cp/conf/policy.json 2>/dev/null | \
        jq -r '.exceptions[]? | "name: \(.name // "N/A")\naction: \(.action // "N/A")\n---"' 2>/dev/null | head -20
fi
echo ""

echo -e "${GREEN}9. CustomResponse設定${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【YAMLファイルの定義】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 10 "^customResponses:" | head -15 || \
    echo "customResponses定義が見つかりません（または使用されていません）"
echo ""

echo -e "${GREEN}10. SourceIdentifiers設定${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【YAMLファイルの定義】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl --view-policy /ext/appsec/local_policy.yaml 2>/dev/null | \
    grep -A 10 "^sourcesIdentifiers:" | head -15 || \
    echo "sourcesIdentifiers定義が見つかりません（または使用されていません）"
echo ""

echo -e "${BLUE}=== 確認完了 ===${NC}"
echo ""
echo -e "${YELLOW}補足情報:${NC}"
echo "  - policy.jsonのパス: /etc/cp/conf/policy.json"
echo "  - accessControlV2.policyのパス: /etc/cp/conf/accessControlV2/accessControlV2.policy"
echo "  - YAMLファイルのパス: /ext/appsec/local_policy.yaml"
echo ""
echo -e "${YELLOW}ポリシーを再読み込みする場合:${NC}"
echo "  docker-compose exec openappsec-agent open-appsec-ctl -lc http-transaction-handler"
