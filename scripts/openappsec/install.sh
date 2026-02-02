#!/bin/bash

# OpenAppSecインストールスクリプト
# Task 5.7: インストール・セットアップスクリプト実装
# 開発者が簡単にOpenAppSec環境をセットアップできるようにする

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"
INSTALL_MODE=""

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# ヘルパー関数
# ============================================

# エラー時のクリーンアップ
cleanup_on_error() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  ❌ インストールに失敗しました (終了コード: $exit_code)${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "エラー発生時のクリーンアップオプション:"
        echo "1. コンテナを停止して削除（docker-compose down）"
        echo "2. ログを確認してから手動で対処"
        echo "3. 何もしない"
        echo ""
        read -p "選択してください (1/2/3) [デフォルト: 3]: " cleanup_option
        
        cd "$DOCKER_DIR"
        case ${cleanup_option:-3} in
            1)
                echo "🔄 コンテナを停止中..."
                docker-compose down 2>/dev/null || true
                echo -e "${GREEN}✅ クリーンアップ完了${NC}"
                ;;
            2)
                echo "📋 ログを表示します:"
                docker-compose logs --tail=50 2>/dev/null || echo "ログの取得に失敗しました"
                ;;
            3)
                echo "ℹ️  クリーンアップをスキップしました"
                ;;
            *)
                echo "ℹ️  無効な選択です。何もしません"
                ;;
        esac
        echo ""
        echo "トラブルシューティング:"
        echo "  - ログを確認: cd ${DOCKER_DIR} && docker-compose logs"
        echo "  - ステータス確認: cd ${DOCKER_DIR} && docker-compose ps"
        echo "  - 再起動: cd ${DOCKER_DIR} && docker-compose restart"
    fi
}

# エラートラップの設定
trap 'cleanup_on_error' EXIT

# ============================================
# 1. 依存関係の確認
# ============================================

check_dependencies() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 1. 依存関係の確認${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Dockerの確認
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ エラー: Dockerがインストールされていません${NC}"
        echo "   Dockerをインストールしてから再実行してください"
        echo "   https://docs.docker.com/get-docker/"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker: $(docker --version)${NC}"
    
    # docker-composeの確認
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        echo -e "${RED}❌ エラー: docker-composeがインストールされていません${NC}"
        echo "   docker-composeをインストールしてから再実行してください"
        exit 1
    fi
    if command -v docker-compose >/dev/null 2>&1; then
        echo -e "${GREEN}✅ docker-compose: $(docker-compose --version)${NC}"
    else
        echo -e "${GREEN}✅ docker compose: $(docker compose version)${NC}"
    fi
    
    # jqの確認（オプション）
    if command -v jq >/dev/null 2>&1; then
        echo -e "${GREEN}✅ jq: $(jq --version)${NC}"
    else
        echo -e "${YELLOW}⚠️  jqがインストールされていません（推奨）${NC}"
    fi
    
    # curlの確認
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}❌ エラー: curlがインストールされていません${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ curl: $(curl --version | head -1)${NC}"
    echo ""
}

# ============================================
# 2. ディレクトリ構造の確認
# ============================================

check_directory_structure() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 2. ディレクトリ構造の確認${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local required_dirs=(
        "${DOCKER_DIR}"
        "${DOCKER_DIR}/nginx"
        "${DOCKER_DIR}/nginx/conf.d"
        "${DOCKER_DIR}/openappsec"
        "${REPO_ROOT}/config-agent"
        "${REPO_ROOT}/config-agent/lib"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${RED}❌ エラー: ディレクトリが見つかりません: $dir${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}✅ 必要なディレクトリが存在します${NC}"
    echo ""
}

# ============================================
# 3. 既存コンテナの確認
# ============================================

check_existing_containers() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 3. 既存コンテナの確認${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cd "$DOCKER_DIR"
    local running_containers=$(docker-compose ps -q 2>/dev/null || true)
    
    if [ -n "$running_containers" ]; then
        echo -e "${YELLOW}⚠️  既存のコンテナが実行中です:${NC}"
        docker-compose ps
        echo ""
        read -p "既存のコンテナを停止して再インストールしますか？ (y/N): " answer
        
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            echo "🔄 既存のコンテナを停止中..."
            docker-compose down
            echo -e "${GREEN}✅ 既存のコンテナを停止しました${NC}"
        else
            echo "ℹ️  インストールを中断しました"
            exit 0
        fi
    else
        echo -e "${GREEN}✅ 既存のコンテナはありません${NC}"
    fi
    echo ""
}

# ============================================
# 4. インストールモードの選択
# ============================================

select_installation_mode() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 4. インストールモードの選択${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "1. クイックスタート（開発環境、デフォルト設定）"
    echo "2. カスタムインストール（環境変数を設定）"
    echo "3. SaaS管理UI連携（my.openappsec.io使用）"
    echo ""
    read -p "選択してください (1/2/3) [デフォルト: 1]: " mode
    
    case ${mode:-1} in
        1)
            echo -e "${GREEN}✅ クイックスタートモードを選択しました${NC}"
            INSTALL_MODE="quick"
            ;;
        2)
            echo -e "${GREEN}✅ カスタムインストールモードを選択しました${NC}"
            INSTALL_MODE="custom"
            ;;
        3)
            echo -e "${GREEN}✅ SaaS管理UI連携モードを選択しました${NC}"
            INSTALL_MODE="saas"
            ;;
        *)
            echo -e "${RED}❌ 無効な選択です${NC}"
            exit 1
            ;;
    esac
    echo ""
}

# ============================================
# 5. 環境変数の設定
# ============================================

setup_environment() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 5. 環境変数の設定${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local env_file="${DOCKER_DIR}/.env"
    local env_template="${DOCKER_DIR}/.env.template"
    
    if [ ! -f "$env_file" ]; then
        echo -e "${YELLOW}⚠️  .envファイルが見つかりません${NC}"
        
        if [ -f "$env_template" ]; then
            echo "📝 .env.templateから.envファイルを作成します"
            cp "$env_template" "$env_file"
            echo -e "${GREEN}✅ .envファイルを作成しました: $env_file${NC}"
            echo ""
            
            if [ "$INSTALL_MODE" = "saas" ]; then
                echo -e "${YELLOW}⚠️  重要: SaaS管理UIを使用するには以下の環境変数を設定してください:${NC}"
                echo "   1. https://my.openappsec.io にログイン"
                echo "   2. Deployment Profile を作成または選択"
                echo "   3. Token をコピー"
                echo ""
                echo "エディタで編集してください:"
                echo "   vim $env_file"
                echo ""
                echo "必須の設定:"
                echo "   - APPSEC_AGENT_TOKEN=<your-token>"
                echo "   - APPSEC_AUTO_POLICY_LOAD=false"
                echo ""
                read -p "Enterキーを押して続行（またはCtrl+Cで中断）..." dummy
            elif [ "$INSTALL_MODE" = "custom" ]; then
                echo -e "${YELLOW}⚠️  環境変数をカスタマイズする場合は、.envファイルを編集してください${NC}"
                echo "   vim $env_file"
                echo ""
                read -p "編集しますか？ (y/N): " edit_answer
                if [ "$edit_answer" = "y" ] || [ "$edit_answer" = "Y" ]; then
                    ${EDITOR:-vim} "$env_file"
                fi
            else
                echo "ℹ️  クイックスタートモード: デフォルト設定を使用します"
            fi
        else
            echo -e "${RED}❌ エラー: .env.templateが見つかりません${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ .envファイルが存在します${NC}"
        
        if [ "$INSTALL_MODE" = "saas" ]; then
            echo ""
            echo -e "${YELLOW}⚠️  SaaS管理UIモードが選択されていますが、.envファイルが既に存在します${NC}"
            echo "   APPSEC_AGENT_TOKENとAPPSEC_AUTO_POLICY_LOADが正しく設定されているか確認してください"
            echo ""
            read -p ".envファイルを確認しますか？ (y/N): " check_answer
            if [ "$check_answer" = "y" ] || [ "$check_answer" = "Y" ]; then
                cat "$env_file"
                echo ""
                read -p "Enterキーを押して続行..." dummy
            fi
        fi
    fi
    echo ""
}

# ============================================
# 6. 必要なディレクトリの作成
# ============================================

create_required_directories() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 6. 必要なディレクトリの作成${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local log_dirs=(
        "${DOCKER_DIR}/nginx/logs"
        "${DOCKER_DIR}/openappsec/logs"
        "${DOCKER_DIR}/fluentd/log"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "📁 ディレクトリを作成: $dir"
            mkdir -p "$dir"
        fi
    done
    
    echo -e "${GREEN}✅ 必要なディレクトリを作成しました${NC}"
    echo ""
}

# ============================================
# 7. Docker Composeでのサービス起動
# ============================================

start_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 7. Docker Composeでのサービス起動${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cd "$DOCKER_DIR"
    
    echo "🔄 Docker Composeでサービスを起動中..."
    
    if [ "$INSTALL_MODE" = "saas" ]; then
        echo "ℹ️  SaaS管理UIモードで起動します"
        if docker-compose -f docker-compose.yml -f docker-compose.saas.yml up -d; then
            echo -e "${GREEN}✅ サービスが起動しました（SaaS連携モード）${NC}"
        else
            echo -e "${RED}❌ サービスの起動に失敗しました${NC}"
            exit 1
        fi
    else
        if docker-compose up -d; then
            echo -e "${GREEN}✅ サービスが起動しました${NC}"
        else
            echo -e "${RED}❌ サービスの起動に失敗しました${NC}"
            exit 1
        fi
    fi
    echo ""
}

# ============================================
# 8. サービスの起動確認
# ============================================

wait_for_service_ready() {
    local service_name=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    echo -n "🔄 ${service_name}の起動を待機中"
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose ps "$service_name" 2>/dev/null | grep -q "Up"; then
            echo ""
            echo -e "${GREEN}✅ ${service_name}が起動しました${NC}"
            return 0
        fi
        
        echo -n "."
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo ""
    echo -e "${YELLOW}⚠️  ${service_name}の起動確認がタイムアウトしました${NC}"
    echo "   ログを確認してください:"
    echo "   docker-compose logs $service_name"
    return 1
}

verify_all_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 8. サービスの起動確認${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cd "$DOCKER_DIR"
    
    local services=("nginx" "openappsec-agent" "mock-api" "config-agent" "redis" "fluentd" "health-api")
    local failed=false
    
    for service in "${services[@]}"; do
        if ! wait_for_service_ready "$service" 30; then
            failed=true
        fi
    done
    
    if [ "$failed" = true ]; then
        echo ""
        echo -e "${YELLOW}⚠️  一部のサービスの起動確認に失敗しました${NC}"
        echo "   全サービスの状態:"
        docker-compose ps
        echo ""
        echo "   ログを確認してください:"
        echo "   docker-compose logs"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}✅ 全サービスが正常に起動しました${NC}"
    
    echo ""
    echo "📋 サービスの状態:"
    docker-compose ps
    echo ""
}

# ============================================
# 9. エンドポイントの確認
# ============================================

check_http_endpoint() {
    local url=$1
    local description=$2
    local expected_code=${3:-200}
    local max_attempts=${4:-30}
    local attempt=0
    
    echo -n "🔄 ${description}を確認中"
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -q "$expected_code"; then
            echo ""
            echo -e "${GREEN}✅ ${description}が応答しました${NC}"
            return 0
        fi
        
        echo -n "."
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo ""
    echo -e "${YELLOW}⚠️  ${description}の確認がタイムアウトしました${NC}"
    return 1
}

verify_endpoints() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📋 9. エンドポイントの確認${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Health API（開発環境ではdocker-compose.override.ymlでポート公開されている）
    if [ -f "${DOCKER_DIR}/docker-compose.override.yml" ]; then
        check_http_endpoint "http://localhost:8888/health" "Health API" 200 30
    else
        echo "ℹ️  Health API: 本番環境モード（ポート公開なし）"
    fi
    
    # Nginx
    echo -n "🔄 Nginxエンドポイントを確認中"
    if curl -sf -H "Host: test.example.com" http://localhost/ >/dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}✅ Nginxが応答しました${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  Nginxの確認に失敗しました（設定によっては正常）${NC}"
    fi
    
    echo ""
}

# ============================================
# 10. インストール完了メッセージ
# ============================================

show_completion_message() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ インストール完了${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "次のステップ:"
    echo ""
    echo "1. ログの確認:"
    echo "   cd ${DOCKER_DIR}"
    echo "   docker-compose logs -f"
    echo ""
    echo "2. 動作確認:"
    echo "   curl -H \"Host: test.example.com\" http://localhost/"
    echo ""
    
    if [ "$INSTALL_MODE" = "saas" ]; then
        echo "3. SaaS管理UIでの確認:"
        echo "   https://my.openappsec.io にアクセスして、Agentが接続されているか確認してください"
        echo ""
    fi
    
    echo "3. ヘルスチェック:"
    if [ -f "${DOCKER_DIR}/docker-compose.override.yml" ]; then
        echo "   curl http://localhost:8888/health"
    else
        echo "   docker-compose exec nginx curl http://health-api:8888/health"
    fi
    echo ""
    echo "4. サービスの管理:"
    echo "   cd ${DOCKER_DIR}"
    echo "   docker-compose ps      # 状態確認"
    echo "   docker-compose restart # 再起動"
    echo "   docker-compose stop    # 停止"
    echo "   docker-compose down    # 停止と削除"
    echo ""
    echo "詳細は以下を参照してください:"
    echo "  - ${DOCKER_DIR}/README.md"
    echo "  - ${REPO_ROOT}/docs/design/MWD-103-implementation-plan.md"
    echo ""
}

# ============================================
# メイン処理
# ============================================

main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  OpenAppSec インストールスクリプト${NC}"
    echo -e "${BLUE}  Task 5.7: インストール・セットアップスクリプト実装${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 1. 依存関係の確認
    check_dependencies
    
    # 2. ディレクトリ構造の確認
    check_directory_structure
    
    # 3. 既存コンテナの確認
    check_existing_containers
    
    # 4. インストールモードの選択
    select_installation_mode
    
    # 5. 環境変数の設定
    setup_environment
    
    # 6. 必要なディレクトリの作成
    create_required_directories
    
    # 7. Docker Composeでのサービス起動
    start_services
    
    # 8. サービスの起動確認
    verify_all_services
    
    # 9. エンドポイントの確認
    verify_endpoints
    
    # 10. インストール完了メッセージ
    show_completion_message
}

# スクリプトの実行
main
