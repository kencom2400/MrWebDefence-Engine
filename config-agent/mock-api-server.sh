#!/bin/bash

# モックAPIサーバー
# ConfigAgentの動作確認用の簡単なHTTPサーバー

set -e

PORT="${MOCK_API_PORT:-8080}"
CONFIG_FILE="${MOCK_API_CONFIG_FILE:-/tmp/mock-api-config.json}"

# デフォルト設定データ
DEFAULT_CONFIG='{
  "version": "1.0.0",
  "default_mode": "detect-learn",
  "default_custom_response": 403,
  "fqdns": [
    {
      "fqdn": "test.example.com",
      "is_active": true,
      "waf_mode": "detect-learn",
      "custom_response": 403,
      "backend_host": "httpbin.org",
      "backend_port": 80,
      "backend_path": "/get"
    },
    {
      "fqdn": "example1.com",
      "is_active": true,
      "waf_mode": "detect-learn",
      "custom_response": 403,
      "backend_host": "httpbin.org",
      "backend_port": 80,
      "backend_path": "/json"
    },
    {
      "fqdn": "example2.com",
      "is_active": true,
      "waf_mode": "detect-learn",
      "custom_response": 403,
      "backend_host": "httpbin.org",
      "backend_port": 80,
      "backend_path": "/xml"
    },
    {
      "fqdn": "example3.com",
      "is_active": true,
      "waf_mode": "detect-learn",
      "custom_response": 403,
      "backend_host": "httpbin.org",
      "backend_port": 80,
      "backend_path": "/get"
    }
  ]
}'

# 設定ファイルが存在しない場合は作成
if [ ! -f "$CONFIG_FILE" ]; then
    echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    echo "✅ デフォルト設定ファイルを作成しました: $CONFIG_FILE"
fi

# HTTPレスポンスを生成
generate_response() {
    local method="$1"
    local path="$2"
    local headers="$3"
    
    # Authorizationヘッダーの確認
    if ! echo "$headers" | grep -qi "Authorization: Bearer"; then
        echo "HTTP/1.1 401 Unauthorized"
        echo "Content-Type: application/json"
        echo ""
        echo '{"error": "Unauthorized: API token required"}'
        return
    fi
    
    case "$path" in
        /engine/v1/config)
            if [ "$method" = "GET" ]; then
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo ""
                cat "$CONFIG_FILE"
            else
                echo "HTTP/1.1 405 Method Not Allowed"
                echo "Content-Type: application/json"
                echo ""
                echo '{"error": "Method not allowed"}'
            fi
            ;;
        /health)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo ""
            echo '{"status": "healthy"}'
            ;;
        *)
            echo "HTTP/1.1 404 Not Found"
            echo "Content-Type: application/json"
            echo ""
            echo '{"error": "Not found"}'
            ;;
    esac
}

# HTTPリクエストを処理
handle_request() {
    local request_line
    read -r request_line
    
    if [ -z "$request_line" ]; then
        return
    fi
    
    local method
    local path
    read -r method path rest <<< "$request_line"
    
    # ヘッダーを読み込む
    local headers=""
    local line
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            break
        fi
        headers="${headers}${line}\n"
    done
    
    # レスポンスを生成
    generate_response "$method" "$path" "$headers"
}

# サーバーを起動
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  モックAPIサーバーを起動中..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ポート: $PORT"
echo "設定ファイル: $CONFIG_FILE"
echo ""
echo "エンドポイント:"
echo "  GET /engine/v1/config - 設定データを取得"
echo "  GET /health - ヘルスチェック"
echo ""
echo "停止するには Ctrl+C を押してください"
echo ""

# netcatを使用してHTTPサーバーを起動
while true; do
    if command -v nc >/dev/null 2>&1; then
        # netcatを使用
        echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n" | nc -l -p "$PORT" | handle_request
    elif command -v socat >/dev/null 2>&1; then
        # socatを使用
        socat TCP-LISTEN:"$PORT",reuseaddr,fork EXEC:"$0 handle_request"
    else
        echo "❌ エラー: netcatまたはsocatが必要です"
        exit 1
    fi
done
