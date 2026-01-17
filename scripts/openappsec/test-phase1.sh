#!/bin/bash

# Phase 1動作確認スクリプト
# OpenAppSecとNginxの統合が正常に動作しているか確認します

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 1: 基盤構築 動作確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. コンテナの状態確認
echo "📋 1. コンテナの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose ps
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

# 3. Attachment Moduleの読み込み確認
echo "📋 3. Attachment Moduleの読み込み確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose exec -T nginx nginx -V 2>&1 | grep -qi "attachment\|cp"; then
    echo "✅ Attachment Moduleが読み込まれています"
else
    echo "⚠️  Attachment Moduleの読み込みを確認できませんでした"
    echo "   ログを確認してください: docker-compose logs nginx"
fi
echo ""

# 4. OpenAppSec Agentの状態確認
echo "📋 4. OpenAppSec Agentの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose ps | grep -q "openappsec-agent.*Up"; then
    echo "✅ OpenAppSec Agentが起動しています"
else
    echo "❌ OpenAppSec Agentが起動していません"
    echo "   ログを確認してください: docker-compose logs openappsec-agent"
    exit 1
fi
echo ""

# 5. 設定ファイルの存在確認
echo "📋 5. 設定ファイルの存在確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose exec -T openappsec-agent test -f /ext/appsec/local_policy.yaml; then
    echo "✅ local_policy.yamlが存在します"
else
    echo "⚠️  local_policy.yamlが見つかりません"
    echo "   パスを確認してください: /ext/appsec/local_policy.yaml"
fi
echo ""

# 6. HTTPリクエストのテスト
echo "📋 6. HTTPリクエストのテスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "テスト用FQDNにHTTPリクエストを送信します..."
if curl -s -H "Host: test.example.com" http://localhost/health > /dev/null; then
    echo "✅ HTTPリクエストが正常に処理されました"
else
    echo "❌ HTTPリクエストの処理に失敗しました"
    echo "   ログを確認してください: docker-compose logs nginx"
fi
echo ""

# 7. ログの確認
echo "📋 7. ログの確認（最新10行）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Nginxログ:"
docker-compose logs --tail=10 nginx
echo ""
echo "OpenAppSec Agentログ:"
docker-compose logs --tail=10 openappsec-agent
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Phase 1動作確認完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "次のステップ:"
echo "  1. ログを詳細に確認して、OpenAppSec Agentがリクエストを検知しているか確認"
echo "  2. Phase 2: 複数FQDN対応の実装に進む"
