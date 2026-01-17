#!/bin/bash

# Phase 2動作確認スクリプト
# 複数FQDN対応が正常に動作しているか確認します

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 2: 複数FQDN対応 動作確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# テスト用FQDNリスト
FQDNS=("test.example.com" "example1.com" "example2.com" "example3.com")

# 1. Nginx設定ファイルの確認
echo "📋 1. Nginx設定ファイルの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for fqdn in "${FQDNS[@]}"; do
    conf_file="nginx/conf.d/${fqdn}.conf"
    if [ -f "$conf_file" ]; then
        echo "✅ ${fqdn}.conf が存在します"
    else
        echo "❌ ${fqdn}.conf が見つかりません"
    fi
done
echo ""

# 2. Nginx設定の構文チェック
echo "📋 2. Nginx設定の構文チェック"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose exec -T nginx nginx -t 2>&1; then
    echo "✅ Nginx設定は正常です"
else
    echo "❌ Nginx設定にエラーがあります"
    exit 1
fi
echo ""

# 3. OpenAppSec設定の確認
echo "📋 3. OpenAppSec設定の確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose exec -T openappsec-agent test -f /ext/appsec/local_policy.yaml; then
    echo "✅ local_policy.yamlが存在します"
    echo ""
    echo "specificRulesの確認:"
    docker-compose exec -T openappsec-agent cat /ext/appsec/local_policy.yaml | grep -A 5 "specificRules:" || echo "  specificRulesセクションを確認中..."
else
    echo "❌ local_policy.yamlが見つかりません"
    exit 1
fi
echo ""

# 4. 各FQDNでのHTTPリクエストテスト
echo "📋 4. 各FQDNでのHTTPリクエストテスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for fqdn in "${FQDNS[@]}"; do
    echo "テスト: ${fqdn}"
    if curl -s -H "Host: ${fqdn}" http://localhost/health > /dev/null; then
        echo "  ✅ HTTPリクエストが正常に処理されました"
    else
        echo "  ❌ HTTPリクエストの処理に失敗しました"
    fi
done
echo ""

# 5. ログの確認（FQDN別）
echo "📋 5. ログの確認（FQDN別）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Nginxアクセスログ（最新5行）:"
for fqdn in "${FQDNS[@]}"; do
    echo "  ${fqdn}:"
    docker-compose exec -T nginx tail -n 5 /var/log/nginx/${fqdn}.access.log 2>/dev/null || echo "    ログファイルが見つかりません"
done
echo ""

# 6. OpenAppSec Agentのログ確認
echo "📋 6. OpenAppSec Agentのログ確認（最新10行）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose logs --tail=10 openappsec-agent | grep -i "transaction\|request\|host" || echo "  関連ログが見つかりません"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Phase 2動作確認完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "次のステップ:"
echo "  1. 各FQDNで異なるWAF設定が適用されているか確認"
echo "  2. OpenAppSec Agentが各FQDNのリクエストを検知しているか確認"
echo "  3. Phase 3: 設定取得エージェントの実装に進む"
