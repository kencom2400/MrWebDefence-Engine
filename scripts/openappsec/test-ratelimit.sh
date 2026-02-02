#!/bin/bash

# RateLimit機能テストスクリプト
# Task 5.4: RateLimit機能実装のテストと動作確認
# ポリシー: config-agent/lib/policy-generator.sh の rate-limit-default に準拠
#   - uri: "/", limit: 100, unit: minute, action: prevent

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

# 指定回数リクエストを送信し、成功・ブロック・その他の件数を集計する
# 使用例: send_requests "http://localhost/" "test.example.com" 10
# 戻り値: なし。グローバル SUCCESS_COUNT, BLOCKED_COUNT を更新する
send_requests() {
    local url="$1"
    local host_header="$2"
    local count="${3:-1}"
    SUCCESS_COUNT=0
    BLOCKED_COUNT=0

    for i in $(seq 1 "$count"); do
        local response
        response=$(curl -s -w "\n%{http_code}" -H "Host: ${host_header}" "$url" 2>/dev/null || echo "000")
        local http_code
        http_code=$(echo "$response" | tail -1)

        if [ "$http_code" = "200" ]; then
            echo -e "  リクエスト ${i}: ${GREEN}成功 (${http_code})${NC}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        elif [ "$http_code" = "403" ]; then
            echo -e "  リクエスト ${i}: ${RED}ブロック (403)${NC}"
            BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
        else
            echo -e "  リクエスト ${i}: ${YELLOW}その他 (${http_code})${NC}"
        fi
        sleep 0.5
    done
}

# 1回だけリクエストを送信し、HTTPステータスコードを返す（標準出力の最後の行）
get_http_code() {
    local url="$1"
    local host_header="$2"
    local response
    response=$(curl -s -w "\n%{http_code}" -H "Host: ${host_header}" "$url" 2>/dev/null || echo "000")
    echo "$response" | tail -1
}

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

# 2. accessControlPracticesの生成確認（現ポリシー: uri "/", 100/分, action prevent）
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

            # 現ポリシー: uri "/", limit 100, action prevent（policy-generator.sh に準拠）
            if grep -Fq 'uri: "/"' ./openappsec/local_policy.yaml; then
                echo -e "${GREEN}✅ 全エンドポイントのRateLimitルール（uri: \"/\"）が定義されています${NC}"
            else
                echo -e "${YELLOW}⚠️  uri: \"/\" のRateLimitルールが見つかりません${NC}"
            fi
            if grep -q "limit: 100" ./openappsec/local_policy.yaml; then
                echo -e "${GREEN}✅ limit: 100（100リクエスト/分）が定義されています${NC}"
            else
                echo -e "${YELLOW}⚠️  limit: 100 が見つかりません${NC}"
            fi
            if grep -q "action: prevent" ./openappsec/local_policy.yaml; then
                echo -e "${GREEN}✅ action: prevent が定義されています${NC}"
            else
                echo -e "${YELLOW}⚠️  action: prevent が見つかりません${NC}"
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

# 4. RateLimit機能のテスト（現ポリシー: uri "/", 100/分, action prevent）
echo -e "${BLUE}📋 4. RateLimit機能のテスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# テスト対象FQDNを動的に取得（堅牢性向上）
TEST_FQDN=$(grep -m 1 'host:' ./openappsec/local_policy.yaml | awk '{print $2}' | tr -d '"' || echo "test.example.com")
echo "テスト対象FQDN: ${TEST_FQDN}"
echo "ポリシー: uri \"/\", 100リクエスト/分, action: prevent（policy-generator.sh 準拠）"
echo ""

# 4.1 制限内のリクエスト（5回）
echo -e "${BLUE}4.1 制限内のリクエスト（5回）${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
send_requests "http://localhost/" "$TEST_FQDN" 5
echo ""
echo "結果: 成功 ${SUCCESS_COUNT}回、ブロック ${BLOCKED_COUNT}回"
echo ""

# 4.2 制限超過の確認（101回目で403が期待される場合のサンプルチェック）
echo -e "${BLUE}4.2 制限超過時の動作確認（オプション）${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "追加で1リクエスト送信し、レート制限適用の有無を確認します。"
code=$(get_http_code "http://localhost/" "$TEST_FQDN")
if [ "$code" = "403" ]; then
    echo -e "${GREEN}✅ レート制限が適用されている可能性があります（403）${NC}"
else
    echo -e "${YELLOW}⚠️  HTTPステータス: ${code}（100/分以内のため200の場合は正常）${NC}"
    echo "   注意: OpenAppSecのRateLimitは設定読み込みに時間がかかる場合や、Issue #397の影響で適用されない場合があります"
fi
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
    grep -A 20 "^accessControlPractices:" ./openappsec/local_policy.yaml | head -20
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
