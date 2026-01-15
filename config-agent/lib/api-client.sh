#!/bin/bash

# 管理APIクライアント
# 管理APIから設定を取得する機能を提供

set -e

# 管理APIから設定を取得
fetch_config_from_api() {
    local api_url="${CONFIG_API_URL}/engine/v1/config"
    local token="${CONFIG_API_TOKEN}"
    
    if [ -z "$token" ]; then
        echo "❌ エラー: CONFIG_API_TOKENが設定されていません" >&2
        return 1
    fi
    
    if [ -z "$CONFIG_API_URL" ]; then
        echo "❌ エラー: CONFIG_API_URLが設定されていません" >&2
        return 1
    fi
    
    local response
    local http_code
    
    # リトライロジック（指数バックオフ）
    local max_retries=5
    local retry_count=0
    local retry_delay=5
    
    while [ $retry_count -lt $max_retries ]; do
        response=$(curl -s -w "\n%{http_code}" \
            -X GET \
            -H "Authorization: Bearer ${token}" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            --max-time 30 \
            "$api_url" 2>&1)
        
        http_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | sed '$d')
        
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            echo "$response_body"
            return 0
        elif [ "$http_code" -eq 401 ]; then
            echo "❌ 認証エラー: APIトークンが無効です" >&2
            return 1
        elif [ "$http_code" -eq 404 ]; then
            echo "❌ エラー: エンドポイントが見つかりません: $api_url" >&2
            return 1
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "⚠️  HTTPエラー: $http_code (リトライ ${retry_count}/${max_retries}、${retry_delay}秒後に再試行...)" >&2
                sleep $retry_delay
                retry_delay=$((retry_delay * 2))  # 指数バックオフ
            else
                echo "❌ HTTPエラー: $http_code (最大リトライ回数に達しました)" >&2
                echo "$response_body" >&2
                return 1
            fi
        fi
    done
    
    return 1
}

# API接続テスト
test_api_connection() {
    local api_url="${CONFIG_API_URL}/engine/v1/config"
    local token="${CONFIG_API_TOKEN}"
    
    if [ -z "$token" ] || [ -z "$CONFIG_API_URL" ]; then
        echo "❌ エラー: CONFIG_API_URL または CONFIG_API_TOKEN が設定されていません" >&2
        return 1
    fi
    
    echo "🔄 API接続をテスト中: $api_url"
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" \
        -X GET \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/json" \
        --max-time 10 \
        "$api_url" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "✅ API接続成功"
        return 0
    else
        echo "❌ API接続失敗: HTTP $http_code" >&2
        return 1
    fi
}
