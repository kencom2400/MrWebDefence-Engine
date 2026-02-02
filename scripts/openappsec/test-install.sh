#!/bin/bash

# インストールスクリプトのテスト
# Task 5.7: インストール・セットアップスクリプト実装

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/install.sh"
DOCKER_DIR="${SCRIPT_DIR}/../../docker"

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  インストールスクリプトのテスト${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. インストールスクリプトの存在確認
echo -e "${BLUE}📋 1. インストールスクリプトの存在確認${NC}"
if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo -e "${RED}❌ エラー: インストールスクリプトが見つかりません: $INSTALL_SCRIPT${NC}"
    exit 1
fi
echo -e "${GREEN}✅ インストールスクリプトが存在します${NC}"
echo ""

# 2. 実行権限の確認
echo -e "${BLUE}📋 2. 実行権限の確認${NC}"
if [ ! -x "$INSTALL_SCRIPT" ]; then
    echo -e "${RED}❌ エラー: インストールスクリプトに実行権限がありません${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 実行権限があります${NC}"
echo ""

# 3. 依存関係の確認
echo -e "${BLUE}📋 3. 依存関係の確認${NC}"

# Docker
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ エラー: Dockerがインストールされていません${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker: $(docker --version)${NC}"

# docker-compose
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}❌ エラー: docker-composeがインストールされていません${NC}"
    exit 1
fi
echo -e "${GREEN}✅ docker-compose: $(docker-compose --version 2>/dev/null || docker compose version)${NC}"

# curl
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}❌ エラー: curlがインストールされていません${NC}"
    exit 1
fi
echo -e "${GREEN}✅ curl: $(curl --version | head -1)${NC}"
echo ""

# 4. 必要なファイルの確認
echo -e "${BLUE}📋 4. 必要なファイルの確認${NC}"

required_files=(
    "${DOCKER_DIR}/docker-compose.yml"
    "${DOCKER_DIR}/.env.template"
    "${DOCKER_DIR}/nginx/nginx.conf"
    "${DOCKER_DIR}/openappsec/local_policy.yaml"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ エラー: ファイルが見つかりません: $file${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ 必要なファイルが存在します${NC}"
echo ""

# 5. 構文チェック
echo -e "${BLUE}📋 5. スクリプトの構文チェック${NC}"
if bash -n "$INSTALL_SCRIPT"; then
    echo -e "${GREEN}✅ 構文エラーはありません${NC}"
else
    echo -e "${RED}❌ 構文エラーがあります${NC}"
    exit 1
fi
echo ""

# 6. 実際のインストールテスト（オプション）
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  実際のインストールテスト（オプション）${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "⚠️  実際にインストールスクリプトを実行しますか？"
echo "   既存のコンテナが停止される可能性があります"
echo ""
read -p "実行しますか？ (y/N): " run_install

if [ "$run_install" = "y" ] || [ "$run_install" = "Y" ]; then
    echo ""
    echo -e "${YELLOW}🔄 インストールスクリプトを実行中...${NC}"
    echo ""
    
    # インストールスクリプトを実行（入力を自動化）
    echo "1" | "$INSTALL_SCRIPT"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ インストールスクリプトが正常に完了しました${NC}"
        
        # サービスの状態確認
        echo ""
        echo -e "${BLUE}📋 サービスの状態確認${NC}"
        cd "$DOCKER_DIR"
        docker-compose ps
        
        # ヘルスチェック
        echo ""
        echo -e "${BLUE}📋 ヘルスチェック${NC}"
        if [ -f "${DOCKER_DIR}/docker-compose.override.yml" ]; then
            sleep 5
            if curl -sf http://localhost:8888/health >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Health APIが応答しました${NC}"
            else
                echo -e "${YELLOW}⚠️  Health APIの確認に失敗しました${NC}"
            fi
        fi
    else
        echo ""
        echo -e "${RED}❌ インストールスクリプトが失敗しました${NC}"
        exit 1
    fi
else
    echo "ℹ️  実際のインストールテストをスキップしました"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ すべてのテストが完了しました${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# テスト結果のサマリー
echo "テスト結果:"
echo "  ✅ インストールスクリプトの存在確認"
echo "  ✅ 実行権限の確認"
echo "  ✅ 依存関係の確認"
echo "  ✅ 必要なファイルの確認"
echo "  ✅ 構文チェック"

if [ "$run_install" = "y" ] || [ "$run_install" = "Y" ]; then
    echo "  ✅ 実際のインストールテスト"
fi

echo ""
echo "使用方法:"
echo "  基本テスト: ./scripts/openappsec/test-install.sh"
echo "  インストール実行: ./scripts/openappsec/install.sh"
echo ""
