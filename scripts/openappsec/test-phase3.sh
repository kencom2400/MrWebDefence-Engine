#!/bin/bash

# Phase 3動作確認スクリプト
# 設定取得エージェントが正常に動作しているか確認します

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 3: 設定取得エージェント 動作確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. モックAPIサーバーの確認
echo "📋 1. モックAPIサーバーの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose ps mock-api | grep -q "Up"; then
    echo "✅ モックAPIサーバーが起動しています"
    
    # API接続テスト
    echo "🔄 API接続をテスト中..."
    if curl -s -H "Authorization: Bearer test-token" http://localhost:8080/health > /dev/null; then
        echo "✅ API接続成功"
    else
        echo "❌ API接続失敗"
    fi
else
    echo "❌ モックAPIサーバーが起動していません"
    echo "   起動してください: docker-compose up -d mock-api"
    exit 1
fi
echo ""

# 2. ConfigAgentの状態確認
echo "📋 2. ConfigAgentの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose ps config-agent | grep -q "Up"; then
    echo "✅ ConfigAgentが起動しています"
else
    echo "❌ ConfigAgentが起動していません"
    echo "   起動してください: docker-compose up -d config-agent"
    exit 1
fi
echo ""

# 3. ConfigAgentのログ確認
echo "📋 3. ConfigAgentのログ確認（最新20行）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose logs --tail=20 config-agent
echo ""

# 4. 設定ファイルの生成確認
echo "📋 4. 設定ファイルの生成確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# OpenAppSec設定ファイル
if [ -f "./openappsec/local_policy.yaml" ]; then
    echo "✅ OpenAppSec設定ファイルが存在します"
    echo "   最終更新: $(stat -f "%Sm" ./openappsec/local_policy.yaml 2>/dev/null || stat -c "%y" ./openappsec/local_policy.yaml 2>/dev/null || echo "不明")"
else
    echo "⚠️  OpenAppSec設定ファイルが見つかりません（まだ生成されていない可能性があります）"
fi

# Nginx設定ファイル
nginx_config_count=$(find ./nginx/conf.d -name "*.conf" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "✅ Nginx設定ファイル: ${nginx_config_count}個"

if [ "$nginx_config_count" -gt 0 ]; then
    echo "   設定ファイル一覧:"
    find ./nginx/conf.d -name "*.conf" -type f | while read -r file; do
        echo "     - $(basename "$file")"
    done
fi
echo ""

# 5. 設定ファイルの内容確認
echo "📋 5. 設定ファイルの内容確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "./openappsec/local_policy.yaml" ]; then
    echo "OpenAppSec設定ファイル（最初の20行）:"
    head -n 20 ./openappsec/local_policy.yaml
    echo ""
fi

if [ "$nginx_config_count" -gt 0 ]; then
    echo "Nginx設定ファイル（最初の1ファイル、最初の15行）:"
    first_config=$(find ./nginx/conf.d -name "*.conf" -type f | head -1)
    if [ -n "$first_config" ]; then
        head -n 15 "$first_config"
    fi
fi
echo ""

# 6. 設定変更のテスト
echo "📋 6. 設定変更のテスト（オプション）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "設定を変更して、ConfigAgentが自動的に更新するか確認できます"
echo "モックAPIの設定ファイルを編集してください:"
echo "  docker-compose exec mock-api cat /tmp/mock-api-config.json"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Phase 3動作確認完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "次のステップ:"
echo "  1. 設定ファイルが正しく生成されているか確認"
echo "  2. 設定変更時に自動更新されるか確認"
echo "  3. NginxとOpenAppSec Agentが設定を読み込んでいるか確認"
