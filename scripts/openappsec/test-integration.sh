#!/bin/bash

# 統合テストスクリプト
# Phase 1-3の統合動作確認

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  統合テスト: OpenAppSec統合の動作確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# テスト用FQDNリスト
FQDNS=("test.example.com" "example1.com" "example2.com" "example3.com")

# 1. 全コンテナの状態確認
echo "📋 1. 全コンテナの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose ps
echo ""

# 2. ヘルスチェック
echo "📋 2. ヘルスチェック"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"${SCRIPT_DIR}/health-check.sh"
echo ""

# 3. 各FQDNでのHTTPリクエストテスト
echo "📋 3. 各FQDNでのHTTPリクエストテスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for fqdn in "${FQDNS[@]}"; do
    echo "テスト: ${fqdn}"
    
    # ヘルスチェックエンドポイント
    if curl -s -H "Host: ${fqdn}" http://localhost/health > /dev/null; then
        echo "  ✅ ヘルスチェック: OK"
    else
        echo "  ❌ ヘルスチェック: 失敗"
    fi
    
    # 通常のリクエスト
    response=$(curl -s -w "\n%{http_code}" -H "Host: ${fqdn}" http://localhost/ 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        echo "  ✅ HTTPリクエスト: OK (HTTP $http_code)"
    else
        echo "  ⚠️  HTTPリクエスト: HTTP $http_code"
    fi
done
echo ""

# 4. OpenAppSec Agentのログ確認
echo "📋 4. OpenAppSec Agentのログ確認（最新10行）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose logs --tail=10 openappsec-agent | grep -i "transaction\|request\|host" || echo "  関連ログが見つかりません"
echo ""

# 5. Nginxログの確認
echo "📋 5. Nginxログの確認（最新10行）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose logs --tail=10 nginx
echo ""

# 6. ConfigAgentの状態確認（オプション）
echo "📋 6. ConfigAgentの状態確認（オプション）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose ps config-agent 2>/dev/null | grep -q "Up"; then
    echo "✅ ConfigAgentが起動しています"
    echo "   最新のログ（5行）:"
    docker-compose logs --tail=5 config-agent
else
    echo "ℹ️  ConfigAgentは起動していません（オプション）"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 統合テスト完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "詳細な確認:"
echo "  - Phase 1: ${SCRIPT_DIR}/test-phase1.sh"
echo "  - Phase 2: ${SCRIPT_DIR}/test-phase2.sh"
echo "  - Phase 3: ${SCRIPT_DIR}/test-phase3.sh"
echo "  - ヘルスチェック: ${SCRIPT_DIR}/health-check.sh"
