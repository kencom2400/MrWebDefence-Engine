#!/bin/bash
# RateLimit設定のデバッグスクリプト
# OpenAppSecのRateLimit設定が読み込まれない原因を調査します

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

echo -e "${BLUE}=== RateLimit設定デバッグ調査 ===${NC}"
echo ""

# Docker Composeが実行中か確認
if ! docker-compose -f "$DOCKER_DIR/docker-compose.yml" ps | grep -q "openappsec-agent.*Up"; then
    echo -e "${RED}❌ OpenAppSec Agentコンテナが起動していません${NC}"
    exit 1
fi

echo -e "${GREEN}1. YAMLファイルの内容確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【accessControlPracticesの設定】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    sh -c 'cd /ext/appsec && yq eval -o json local_policy.yaml 2>&1' | \
    jq -r '{
        default_access_control: .policies.default.accessControlPractices[0],
        specific_rule_access_control: .policies.specificRules[0].accessControlPractices[0],
        access_control_practice_name: .accessControlPractices[0].name,
        expected_annotation: "local_policy/" + .accessControlPractices[0].name,
        rateLimit_overrideMode: .accessControlPractices[0].rateLimit.overrideMode,
        rateLimit_rules_count: (.accessControlPractices[0].rateLimit.rules | length),
        rateLimit_rules: .accessControlPractices[0].rateLimit.rules
    }' 2>/dev/null || echo "YAMLファイルの読み込みに失敗しました"
echo ""

echo -e "${GREEN}2. JSON変換結果の確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【YAML → JSON変換結果】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    sh -c 'cd /ext/appsec && yq eval -o json local_policy.yaml 2>&1' | \
    jq '.accessControlPractices[0]' 2>/dev/null || echo "JSON変換に失敗しました"
echo ""

echo -e "${GREEN}3. policy.jsonの確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【accessControlV2.rulebase.rateLimit】${NC}"
rate_limit_count=$(docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    cat /etc/cp/conf/policy.json 2>/dev/null | \
    jq -r '.accessControlV2.rulebase.rateLimit | length' 2>/dev/null || echo "0")

if [ "$rate_limit_count" = "0" ]; then
    echo -e "${RED}❌ RateLimit設定が読み込まれていません（空の配列）${NC}"
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        cat /etc/cp/conf/policy.json 2>/dev/null | \
        jq '.accessControlV2' 2>/dev/null || echo "accessControlV2の読み込みに失敗しました"
else
    echo -e "${GREEN}✅ RateLimit設定が読み込まれています（${rate_limit_count}個のルール）${NC}"
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        cat /etc/cp/conf/policy.json 2>/dev/null | \
        jq '.accessControlV2.rulebase.rateLimit' 2>/dev/null
fi
echo ""

echo -e "${GREEN}4. ポリシーの再読み込みとログ確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【ポリシーを再読み込みします】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    open-appsec-ctl -lc http-transaction-handler 2>&1
echo ""

echo -e "${YELLOW}【最新のログを確認します（10秒待機後）】${NC}"
sleep 10
docker-compose -f "$DOCKER_DIR/docker-compose.yml" logs openappsec-agent 2>&1 | \
    tail -100 | \
    grep -i -E "(access.control|rate.limit|policy|local|Failed to retrieve|Element with name|Creating policy|Proccesing policy)" | \
    head -50 || \
    echo "関連するログが見つかりませんでした"
echo ""

echo -e "${GREEN}5. 期待されるアノテーション名の確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【期待されるアノテーション名】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    sh -c 'cd /ext/appsec && yq eval -o json local_policy.yaml 2>&1' | \
    jq -r '
        "policy_name: local_policy
default_access_control_practice: " + (.policies.default.accessControlPractices[0] // "N/A") + "
specific_rule_access_control_practice: " + (.policies.specificRules[0].accessControlPractices[0] // "N/A") + "
access_control_practice_name: " + (.accessControlPractices[0].name // "N/A") + "
expected_annotation_name: local_policy/" + (.accessControlPractices[0].name // "N/A") + "
expected_search_name: " + (.accessControlPractices[0].name // "N/A")
    ' 2>/dev/null || echo "アノテーション名の確認に失敗しました"
echo ""

echo -e "${GREEN}6. 設定ファイルのパス確認${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【設定ファイルのパス】${NC}"
docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    sh -c 'ls -la /ext/appsec/local_policy.yaml /etc/cp/conf/local_policy.yaml 2>&1' || \
    echo "設定ファイルのパス確認に失敗しました"
echo ""

echo -e "${GREEN}7. ポリシーファイルの比較${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}【/ext/appsec/local_policy.yaml と /etc/cp/conf/local_policy.yaml の比較】${NC}"
if docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
    test -f /etc/cp/conf/local_policy.yaml 2>/dev/null; then
    echo "両方のファイルが存在します"
    docker-compose -f "$DOCKER_DIR/docker-compose.yml" exec -T openappsec-agent \
        diff /ext/appsec/local_policy.yaml /etc/cp/conf/local_policy.yaml 2>&1 || \
        echo "ファイルの内容が異なります（または比較に失敗しました）"
else
    echo "/etc/cp/conf/local_policy.yaml が存在しません（正常）"
fi
echo ""

echo -e "${BLUE}=== デバッグ調査完了 ===${NC}"
echo ""
echo -e "${YELLOW}次のステップ:${NC}"
echo "  1. 上記のログを確認して、'Failed to retrieve Access control practice'や"
echo "     'Element with name ... was not found'のメッセージを探してください"
echo "  2. 期待されるアノテーション名と実際のアノテーション名を比較してください"
echo "  3. policy_nameが'local_policy'になっているか確認してください"
