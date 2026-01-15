#!/bin/bash

# OpenAppSecインストールスクリプト
# 開発者が簡単にOpenAppSec環境をセットアップできるようにする

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenAppSec インストールスクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. 依存関係の確認
echo "📋 1. 依存関係の確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Dockerの確認
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ エラー: Dockerがインストールされていません"
    echo "   Dockerをインストールしてから再実行してください"
    exit 1
fi
echo "✅ Docker: $(docker --version)"

# docker-composeの確認
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "❌ エラー: docker-composeがインストールされていません"
    echo "   docker-composeをインストールしてから再実行してください"
    exit 1
fi
if command -v docker-compose >/dev/null 2>&1; then
    echo "✅ docker-compose: $(docker-compose --version)"
else
    echo "✅ docker compose: $(docker compose version)"
fi

# jqの確認（オプション）
if command -v jq >/dev/null 2>&1; then
    echo "✅ jq: $(jq --version)"
else
    echo "⚠️  jqがインストールされていません（推奨）"
fi

# curlの確認
if ! command -v curl >/dev/null 2>&1; then
    echo "❌ エラー: curlがインストールされていません"
    exit 1
fi
echo "✅ curl: $(curl --version | head -1)"
echo ""

# 2. ディレクトリ構造の確認
echo "📋 2. ディレクトリ構造の確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

required_dirs=(
    "${DOCKER_DIR}"
    "${DOCKER_DIR}/nginx"
    "${DOCKER_DIR}/nginx/conf.d"
    "${DOCKER_DIR}/openappsec"
    "${REPO_ROOT}/config-agent"
    "${REPO_ROOT}/config-agent/lib"
)

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "❌ エラー: ディレクトリが見つかりません: $dir"
        exit 1
    fi
done
echo "✅ 必要なディレクトリが存在します"
echo ""

# 3. 設定ファイルの確認
echo "📋 3. 設定ファイルの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

required_files=(
    "${DOCKER_DIR}/docker-compose.yml"
    "${DOCKER_DIR}/nginx/nginx.conf"
    "${DOCKER_DIR}/openappsec/local_policy.yaml"
    "${REPO_ROOT}/config-agent/config-agent.sh"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ エラー: ファイルが見つかりません: $file"
        exit 1
    fi
done
echo "✅ 必要な設定ファイルが存在します"
echo ""

# 4. 環境変数の確認
echo "📋 4. 環境変数の確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -z "${CONFIG_API_URL:-}" ]; then
    echo "⚠️  CONFIG_API_URLが設定されていません（デフォルト: http://config-api:8080）"
else
    echo "✅ CONFIG_API_URL: ${CONFIG_API_URL}"
fi

if [ -z "${CONFIG_API_TOKEN:-}" ]; then
    echo "⚠️  CONFIG_API_TOKENが設定されていません"
    echo "   設定取得エージェントを使用する場合は、環境変数を設定してください"
    echo "   例: export CONFIG_API_TOKEN='your-api-token'"
else
    echo "✅ CONFIG_API_TOKEN: 設定済み"
fi
echo ""

# 5. Docker Composeでのサービス起動
echo "📋 5. Docker Composeでのサービス起動"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$DOCKER_DIR"

echo "🔄 Docker Composeでサービスを起動中..."
if docker-compose up -d 2>&1; then
    echo "✅ サービスが起動しました"
else
    echo "❌ サービスの起動に失敗しました"
    exit 1
fi
echo ""

# 6. 起動確認
echo "📋 6. 起動確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sleep 5  # コンテナの起動を待つ

echo "コンテナの状態:"
docker-compose ps
echo ""

# 7. 初期設定のガイダンス
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ インストール完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "次のステップ:"
echo ""
echo "1. ログの確認:"
echo "   cd ${DOCKER_DIR}"
echo "   docker-compose logs -f"
echo ""
echo "2. 動作確認:"
echo "   curl -H \"Host: test.example.com\" http://localhost/health"
echo ""
echo "3. 設定取得エージェントを使用する場合:"
echo "   export CONFIG_API_URL='http://config-api:8080'"
echo "   export CONFIG_API_TOKEN='your-api-token'"
echo "   docker-compose restart config-agent"
echo ""
echo "詳細は ${REPO_ROOT}/docker/README.md を参照してください"
