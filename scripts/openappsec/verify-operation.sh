#!/bin/bash

# 動作確認スクリプト（簡易版）
# OpenAppSec統合の基本的な動作確認を簡単に実行

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

# 6. WAFシグニチャテスト（SQL Injection、XSSなど）
echo -e "${BLUE}📋 6. WAFシグニチャテスト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WAF_TEST_COUNT=0
WAF_BLOCK_COUNT=0
WAF_DETECT_COUNT=0

# SQL Injection攻撃パターン
sql_injection_patterns=(
    "' OR '1'='1"
    "UNION SELECT * FROM users"
    "'; DROP TABLE users--"
    "1' OR '1'='1'--"
    "admin'--"
    "1' UNION SELECT NULL--"
)

# XSS攻撃パターン
xss_patterns=(
    "<script>alert('XSS')</script>"
    "<img src=x onerror=alert(1)>"
    "<svg onload=alert(1)>"
    "javascript:alert('XSS')"
    "<iframe src=javascript:alert(1)>"
    "<body onload=alert('XSS')>"
)

# パストラバーサル攻撃パターン
path_traversal_patterns=(
    "../../../etc/passwd"
    "..\\..\\..\\windows\\system32"
    "....//....//etc/passwd"
)

# コマンドインジェクション攻撃パターン
command_injection_patterns=(
    "; ls -la"
    "| cat /etc/passwd"
    "&& id"
    "; rm -rf /"
)

echo "WAFシグニチャテストを実行中..."
echo ""

# テスト用FQDN（最初の1つを使用）
TEST_FQDN="${FQDNS[0]}"

# SQL Injectionテスト
echo "  SQL Injectionテスト:"
for pattern in "${sql_injection_patterns[@]}"; do
    WAF_TEST_COUNT=$((WAF_TEST_COUNT + 1))
    # URLエンコード
    encoded_pattern=$(printf '%s' "$pattern" | jq -sRr @uri 2>/dev/null || echo "$pattern")
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Host: ${TEST_FQDN}" \
        "http://localhost/?id=${encoded_pattern}" 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 403 ] || [ "$http_code" -eq 406 ] || [ "$http_code" -ge 400 ]; then
        echo -e "    ${GREEN}✅ ブロック: ${pattern}${NC} (HTTP $http_code)"
        WAF_BLOCK_COUNT=$((WAF_BLOCK_COUNT + 1))
    elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "    ${YELLOW}⚠️  検知されず: ${pattern}${NC} (HTTP $http_code)"
        WAF_DETECT_COUNT=$((WAF_DETECT_COUNT + 1))
    else
        echo -e "    ${YELLOW}⚠️  不明: ${pattern}${NC} (HTTP $http_code)"
    fi
done
echo ""

# XSSテスト
echo "  XSSテスト:"
for pattern in "${xss_patterns[@]}"; do
    WAF_TEST_COUNT=$((WAF_TEST_COUNT + 1))
    # URLエンコード
    encoded_pattern=$(printf '%s' "$pattern" | jq -sRr @uri 2>/dev/null || echo "$pattern")
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Host: ${TEST_FQDN}" \
        "http://localhost/?q=${encoded_pattern}" 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 403 ] || [ "$http_code" -eq 406 ] || [ "$http_code" -ge 400 ]; then
        echo -e "    ${GREEN}✅ ブロック: ${pattern}${NC} (HTTP $http_code)"
        WAF_BLOCK_COUNT=$((WAF_BLOCK_COUNT + 1))
    elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "    ${YELLOW}⚠️  検知されず: ${pattern}${NC} (HTTP $http_code)"
        WAF_DETECT_COUNT=$((WAF_DETECT_COUNT + 1))
    else
        echo -e "    ${YELLOW}⚠️  不明: ${pattern}${NC} (HTTP $http_code)"
    fi
done
echo ""

# パストラバーサルテスト
echo "  パストラバーサルテスト:"
for pattern in "${path_traversal_patterns[@]}"; do
    WAF_TEST_COUNT=$((WAF_TEST_COUNT + 1))
    # URLエンコード
    encoded_pattern=$(printf '%s' "$pattern" | jq -sRr @uri 2>/dev/null || echo "$pattern")
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Host: ${TEST_FQDN}" \
        "http://localhost/${encoded_pattern}" 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 403 ] || [ "$http_code" -eq 406 ] || [ "$http_code" -ge 400 ]; then
        echo -e "    ${GREEN}✅ ブロック: ${pattern}${NC} (HTTP $http_code)"
        WAF_BLOCK_COUNT=$((WAF_BLOCK_COUNT + 1))
    elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "    ${YELLOW}⚠️  検知されず: ${pattern}${NC} (HTTP $http_code)"
        WAF_DETECT_COUNT=$((WAF_DETECT_COUNT + 1))
    else
        echo -e "    ${YELLOW}⚠️  不明: ${pattern}${NC} (HTTP $http_code)"
    fi
done
echo ""

# コマンドインジェクションテスト
echo "  コマンドインジェクションテスト:"
for pattern in "${command_injection_patterns[@]}"; do
    WAF_TEST_COUNT=$((WAF_TEST_COUNT + 1))
    # URLエンコード
    encoded_pattern=$(printf '%s' "$pattern" | jq -sRr @uri 2>/dev/null || echo "$pattern")
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Host: ${TEST_FQDN}" \
        "http://localhost/?cmd=${encoded_pattern}" 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 403 ] || [ "$http_code" -eq 406 ] || [ "$http_code" -ge 400 ]; then
        echo -e "    ${GREEN}✅ ブロック: ${pattern}${NC} (HTTP $http_code)"
        WAF_BLOCK_COUNT=$((WAF_BLOCK_COUNT + 1))
    elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "    ${YELLOW}⚠️  検知されず: ${pattern}${NC} (HTTP $http_code)"
        WAF_DETECT_COUNT=$((WAF_DETECT_COUNT + 1))
    else
        echo -e "    ${YELLOW}⚠️  不明: ${pattern}${NC} (HTTP $http_code)"
    fi
done
echo ""

# WAFテスト結果サマリー
echo "  WAFテスト結果:"
echo "    総テスト数: ${WAF_TEST_COUNT}"
echo "    ブロック数: ${WAF_BLOCK_COUNT}"
echo "    検知されず: ${WAF_DETECT_COUNT}"
echo ""

if [ $WAF_BLOCK_COUNT -gt 0 ]; then
    echo -e "  ${GREEN}✅ WAFが動作しています（${WAF_BLOCK_COUNT}個の攻撃パターンをブロック）${NC}"
else
    echo -e "  ${YELLOW}⚠️  WAFが攻撃パターンをブロックしていません${NC}"
    echo "    注意: detect-learnモードでは検知のみでブロックしない可能性があります"
    echo "    ログを確認してください: docker-compose logs openappsec-agent"
fi
echo ""

# 結果サマリー
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ $FAIL_COUNT -eq 0 ] && [ $WAF_BLOCK_COUNT -gt 0 ]; then
    echo -e "${GREEN}  ✅ 動作確認完了: すべて正常（WAF動作確認済み）${NC}"
    exit 0
elif [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${YELLOW}  ⚠️  動作確認完了: 基本動作は正常（WAF動作要確認）${NC}"
    echo ""
    echo "詳細な確認:"
    echo "  ./scripts/openappsec/test-integration.sh"
    echo "  ./scripts/openappsec/health-check.sh"
    echo "  OpenAppSec Agentログ: docker-compose logs openappsec-agent"
    exit 0
else
    echo -e "${YELLOW}  ⚠️  動作確認完了: 一部に問題があります${NC}"
    echo ""
    echo "詳細な確認:"
    echo "  ./scripts/openappsec/test-integration.sh"
    echo "  ./scripts/openappsec/health-check.sh"
    exit 1
fi
