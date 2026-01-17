#!/bin/bash

# ヘルスチェックスクリプト
# OpenAppSec、Nginx、ConfigAgentの状態を確認

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

# JSON形式で結果を出力
output_json=false
if [ "${1:-}" = "--json" ]; then
    output_json=true
fi

# ヘルスチェック結果
declare -A health_status
health_status["nginx"]="unknown"
health_status["openappsec-agent"]="unknown"
health_status["config-agent"]="unknown"
health_status["nginx_config"]="unknown"
health_status["openappsec_config"]="unknown"

# エラーメッセージ
declare -A error_messages

# Nginx状態チェック
check_nginx() {
    if docker-compose ps nginx | grep -q "Up"; then
        health_status["nginx"]="healthy"
        
        # Nginx設定の構文チェック
        if docker-compose exec -T nginx nginx -t >/dev/null 2>&1; then
            health_status["nginx_config"]="valid"
        else
            health_status["nginx_config"]="invalid"
            error_messages["nginx_config"]="Nginx設定に構文エラーがあります"
        fi
    else
        health_status["nginx"]="unhealthy"
        error_messages["nginx"]="Nginxコンテナが起動していません"
    fi
}

# OpenAppSec Agent状態チェック
check_openappsec_agent() {
    if docker-compose ps openappsec-agent | grep -q "Up"; then
        health_status["openappsec-agent"]="healthy"
        
        # 設定ファイルの存在確認
        if docker-compose exec -T openappsec-agent test -f /ext/appsec/local_policy.yaml 2>/dev/null; then
            health_status["openappsec_config"]="exists"
        else
            health_status["openappsec_config"]="missing"
            error_messages["openappsec_config"]="local_policy.yamlが見つかりません"
        fi
    else
        health_status["openappsec-agent"]="unhealthy"
        error_messages["openappsec-agent"]="OpenAppSec Agentコンテナが起動していません"
    fi
}

# ConfigAgent状態チェック
check_config_agent() {
    if docker-compose ps config-agent 2>/dev/null | grep -q "Up"; then
        health_status["config-agent"]="healthy"
    else
        health_status["config-agent"]="unhealthy"
        error_messages["config-agent"]="ConfigAgentコンテナが起動していません（オプション）"
    fi
}

# すべてのチェックを実行
check_nginx
check_openappsec_agent
check_config_agent

# 結果の出力
if [ "$output_json" = true ]; then
    # JSON形式で出力
    echo "{"
    echo "  \"status\": \"$(
        if [ "${health_status[nginx]}" = "healthy" ] && \
           [ "${health_status[openappsec-agent]}" = "healthy" ]; then
            echo "healthy"
        else
            echo "unhealthy"
        fi
    )\","
    echo "  \"components\": {"
    echo "    \"nginx\": \"${health_status[nginx]}\","
    echo "    \"nginx_config\": \"${health_status[nginx_config]}\","
    echo "    \"openappsec_agent\": \"${health_status[openappsec-agent]}\","
    echo "    \"openappsec_config\": \"${health_status[openappsec_config]}\","
    echo "    \"config_agent\": \"${health_status[config-agent]}\""
    echo "  },"
    echo "  \"errors\": ["
    local first_error=true
    for key in "${!error_messages[@]}"; do
        if [ "$first_error" = true ]; then
            first_error=false
        else
            echo ","
        fi
        echo "    {\"component\": \"$key\", \"message\": \"${error_messages[$key]}\"}"
    done
    echo "  ]"
    echo "}"
else
    # 人間が読みやすい形式で出力
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ヘルスチェック結果"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Nginx: ${health_status[nginx]}"
    if [ "${health_status[nginx_config]}" != "unknown" ]; then
        echo "  - 設定: ${health_status[nginx_config]}"
    fi
    echo ""
    echo "OpenAppSec Agent: ${health_status[openappsec-agent]}"
    if [ "${health_status[openappsec_config]}" != "unknown" ]; then
        echo "  - 設定ファイル: ${health_status[openappsec_config]}"
    fi
    echo ""
    echo "ConfigAgent: ${health_status[config-agent]}"
    echo ""
    
    if [ ${#error_messages[@]} -gt 0 ]; then
        echo "エラー:"
        for key in "${!error_messages[@]}"; do
            echo "  - ${key}: ${error_messages[$key]}"
        done
        echo ""
    fi
    
    # 全体のステータス
    if [ "${health_status[nginx]}" = "healthy" ] && \
       [ "${health_status[openappsec-agent]}" = "healthy" ]; then
        echo "✅ 全体ステータス: 正常"
        exit 0
    else
        echo "❌ 全体ステータス: 異常"
        exit 1
    fi
fi
