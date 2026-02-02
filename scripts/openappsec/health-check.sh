#!/bin/bash

# ヘルスチェックスクリプト
# OpenAppSec、Nginx、ConfigAgentの状態を確認

set -e

# 作業ディレクトリの設定
# 環境変数で指定されている場合はそれを使用、なければ相対パスから計算
if [ -n "$HEALTH_CHECK_CWD" ]; then
    DOCKER_DIR="$HEALTH_CHECK_CWD"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    DOCKER_DIR="${REPO_ROOT}/docker"
fi

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
health_status["redis"]="unknown"
health_status["fluentd"]="unknown"
health_status["nginx_config"]="unknown"
health_status["openappsec_config"]="unknown"
health_status["redis_connection"]="unknown"

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

# Redisヘルスチェック
check_redis() {
    if docker-compose ps redis 2>/dev/null | grep -q "Up"; then
        health_status["redis"]="healthy"
        
        # Redis接続確認（PING）
        # パスワード認証に対応
        local redis_auth_arg=""
        if [ -n "$REDIS_PASSWORD" ]; then
            redis_auth_arg="-a $REDIS_PASSWORD"
        fi

        if docker-compose exec -T redis redis-cli ${redis_auth_arg} ping >/dev/null 2>&1; then
            health_status["redis_connection"]="ok"
        else
            health_status["redis_connection"]="failed"
            error_messages["redis_connection"]="Redisへの接続に失敗しました"
        fi
    else
        health_status["redis"]="unhealthy"
        error_messages["redis"]="Redisコンテナが起動していません"
    fi
}

# Fluentdヘルスチェック
check_fluentd() {
    if docker-compose ps fluentd 2>/dev/null | grep -q "Up"; then
        health_status["fluentd"]="healthy"
    else
        health_status["fluentd"]="unhealthy"
        error_messages["fluentd"]="Fluentdコンテナが起動していません（オプション）"
    fi
}

# システム情報の取得
get_system_info() {
    local nginx_version
    
    nginx_version=$(docker-compose exec -T nginx nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+' || echo "unknown")
    
    # jqを使って安全にJSONを生成（特殊文字のエスケープに対応）
    jq -n \
      --arg nginx_version "$nginx_version" \
      --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg hostname "$(hostname)" \
      '{nginx_version: $nginx_version, timestamp: $timestamp, hostname: $hostname}'
}

# すべてのチェックを実行
check_nginx
check_openappsec_agent
check_config_agent
check_redis
check_fluentd

# 結果の出力
if [ "$output_json" = true ]; then
    # JSON形式で出力（jqを使用して安全に生成）
    # システム情報を取得
    system_info=$(get_system_info)
    
    # 全体ステータスの判定
    overall_status="healthy"
    if [ "${health_status[nginx]}" != "healthy" ] || \
       [ "${health_status[openappsec-agent]}" != "healthy" ]; then
        overall_status="unhealthy"
    fi
    
    # エラーメッセージの配列を作成
    errors_json="[]"
    if [ ${#error_messages[@]} -gt 0 ]; then
        errors_json=$(
            for key in "${!error_messages[@]}"; do
                jq -n \
                  --arg component "$key" \
                  --arg message "${error_messages[$key]}" \
                  '{component: $component, message: $message}'
            done | jq -s '.'
        )
    fi
    
    # 最終的なJSONを出力
    jq -n \
      --arg status "$overall_status" \
      --arg nginx "${health_status[nginx]}" \
      --arg nginx_config "${health_status[nginx_config]}" \
      --arg openappsec_agent "${health_status[openappsec-agent]}" \
      --arg openappsec_config "${health_status[openappsec_config]}" \
      --arg config_agent "${health_status[config-agent]}" \
      --arg redis "${health_status[redis]}" \
      --arg redis_connection "${health_status[redis_connection]}" \
      --arg fluentd "${health_status[fluentd]}" \
      --argjson system_info "$system_info" \
      --argjson errors "$errors_json" \
      '{
        status: $status,
        components: {
          nginx: $nginx,
          nginx_config: $nginx_config,
          openappsec_agent: $openappsec_agent,
          openappsec_config: $openappsec_config,
          config_agent: $config_agent,
          redis: $redis,
          redis_connection: $redis_connection,
          fluentd: $fluentd
        },
        system_info: $system_info,
        errors: $errors
      }'
    
    # JSON出力モードでもexit codeを適切に設定
    if [ "$overall_status" = "healthy" ]; then
        exit 0
    else
        exit 1
    fi
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
    echo "Redis: ${health_status[redis]}"
    if [ "${health_status[redis_connection]}" != "unknown" ]; then
        echo "  - 接続: ${health_status[redis_connection]}"
    fi
    echo ""
    echo "Fluentd: ${health_status[fluentd]}"
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
