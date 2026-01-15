#!/bin/bash

# 設定取得エージェント起動スクリプト
# ConfigAgentを起動・停止する

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

ACTION="${1:-start}"

case "$ACTION" in
    start)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  設定取得エージェントを起動中..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # 環境変数の確認
        if [ -z "${CONFIG_API_TOKEN:-}" ]; then
            echo "⚠️  警告: CONFIG_API_TOKENが設定されていません"
            echo "   環境変数を設定してから起動してください:"
            echo "   export CONFIG_API_TOKEN='your-api-token'"
            echo ""
            read -p "続行しますか？ (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "❌ キャンセルされました"
                exit 1
            fi
        fi
        
        if [ -z "${CONFIG_API_URL:-}" ]; then
            echo "ℹ️  CONFIG_API_URLが設定されていません（デフォルト: http://config-api:8080）"
        fi
        
        # ConfigAgentコンテナを起動
        echo "🔄 ConfigAgentコンテナを起動中..."
        if docker-compose up -d config-agent; then
            echo "✅ ConfigAgentが起動しました"
            echo ""
            echo "ログを確認:"
            echo "  docker-compose logs -f config-agent"
        else
            echo "❌ ConfigAgentの起動に失敗しました"
            exit 1
        fi
        ;;
    
    stop)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  設定取得エージェントを停止中..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if docker-compose stop config-agent; then
            echo "✅ ConfigAgentが停止しました"
        else
            echo "❌ ConfigAgentの停止に失敗しました"
            exit 1
        fi
        ;;
    
    restart)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  設定取得エージェントを再起動中..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if docker-compose restart config-agent; then
            echo "✅ ConfigAgentが再起動しました"
        else
            echo "❌ ConfigAgentの再起動に失敗しました"
            exit 1
        fi
        ;;
    
    status)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  設定取得エージェントの状態"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        docker-compose ps config-agent
        echo ""
        
        if docker-compose ps config-agent | grep -q "Up"; then
            echo "📋 最新のログ（10行）:"
            docker-compose logs --tail=10 config-agent
        fi
        ;;
    
    logs)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  設定取得エージェントのログ"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        docker-compose logs -f config-agent
        ;;
    
    *)
        echo "使用方法: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "コマンド:"
        echo "  start    - ConfigAgentを起動"
        echo "  stop     - ConfigAgentを停止"
        echo "  restart  - ConfigAgentを再起動"
        echo "  status   - ConfigAgentの状態を表示"
        echo "  logs     - ConfigAgentのログを表示（-fオプション付き）"
        exit 1
        ;;
esac
