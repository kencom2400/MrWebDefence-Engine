#!/bin/bash

# ログ転送機能動作確認スクリプト
# Fluentdによるログ転送機能が正常に動作しているか確認します
# CI環境でも実行可能で、成功/失敗を明確に判定できます

set -uo pipefail
# 注意: set -e は使用しない（エラーカウントを集計するため）
# 重要なエラーは明示的に exit 1 で終了する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

# docker-composeコマンドの互換性対応
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "❌ エラー: docker-compose または docker compose が見つかりません" >&2
    exit 1
fi

cd "$DOCKER_DIR"

# テスト結果のカウント
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0

# エラーカウント関数
increment_error() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

increment_warning() {
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

increment_success() {
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ログ転送機能 動作確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# テスト用FQDNリスト
FQDNS=("test.example.com" "example1.com" "example2.com" "example3.com")

# 必要なサービスリスト
REQUIRED_SERVICES=("nginx" "openappsec-agent" "fluentd")

# CI環境の検出（GitHub Actions 等で既にサービスが起動している場合は再起動をスキップ）
CI_MODE=false
if [ -n "${GITHUB_ACTIONS:-}" ] || [ "${CI:-}" = "true" ]; then
  CI_MODE=true
fi

# docker-compose ps の「起動中」判定（Up / running の両方に対応）
is_service_up() {
  $DOCKER_COMPOSE_CMD ps "$1" 2>/dev/null | grep -qE "Up|running"
}

# 0. 既存コンテナの停止（CI時はスキップ）
if [ "$CI_MODE" = "true" ]; then
  echo "📋 0. 既存コンテナの停止（スキップ: CI環境のため起動済みとして続行）"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔄 ログ安定化のため2秒待機..."
  sleep 2
  echo ""
else
  echo "📋 0. 既存コンテナの停止"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  RUNNING_SERVICES=()

  for service in "${REQUIRED_SERVICES[@]}"; do
    if is_service_up "$service"; then
      echo "⚠️  ${service}コンテナが起動中です（停止します）"
      RUNNING_SERVICES+=("$service")
    else
      echo "✅ ${service}コンテナは停止しています"
    fi
  done

  if [ ${#RUNNING_SERVICES[@]} -gt 0 ]; then
    echo ""
    echo "🔄 起動中のサービスを停止中: ${RUNNING_SERVICES[*]}"
    if $DOCKER_COMPOSE_CMD stop "${RUNNING_SERVICES[@]}" 2>&1; then
      echo "✅ サービスの停止を開始しました"
      echo "🔄 サービスが停止するまで待機中（3秒）..."
      sleep 3
      for service in "${RUNNING_SERVICES[@]}"; do
        if is_service_up "$service"; then
          echo "  ⚠️  ${service}がまだ起動中です（強制停止します）"
          $DOCKER_COMPOSE_CMD kill "$service" 2>/dev/null || true
        else
          echo "  ✅ ${service}が停止しました"
        fi
      done
    else
      echo "⚠️  サービスの停止に失敗しました（続行します）"
    fi
  fi
  echo ""

  # 1. 必要なサービスの起動
  echo "📋 1. 必要なサービスの起動"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔄 必要なサービスを起動中: ${REQUIRED_SERVICES[*]}"
  if $DOCKER_COMPOSE_CMD up -d "${REQUIRED_SERVICES[@]}" 2>&1; then
    echo "✅ サービスの起動を開始しました"
    echo "🔄 サービスが起動するまで待機中（10秒）..."
    sleep 10
    for service in "${REQUIRED_SERVICES[@]}"; do
      if is_service_up "$service"; then
        echo "  ✅ ${service}が起動しました"
      else
        echo "  ⚠️  ${service}の起動を確認中..."
      fi
    done
  else
    echo "❌ サービスの起動に失敗しました"
    increment_error
    exit 1
  fi
  echo ""
fi

# 2. Fluentdコンテナの状態確認
echo "📋 2. Fluentdコンテナの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if is_service_up fluentd; then
    echo "✅ Fluentdコンテナが起動しています"
    increment_success
    
    # Fluentdのヘルスチェック
    echo "🔄 Fluentdのヘルスチェック中..."
    if $DOCKER_COMPOSE_CMD exec -T fluentd fluentd --version > /dev/null 2>&1; then
        echo "✅ Fluentdが正常に動作しています"
        increment_success
    else
        echo "⚠️  Fluentdのバージョン確認に失敗しました（コンテナ内で確認）"
        increment_warning
    fi
else
    echo "❌ Fluentdコンテナが起動していません"
    echo "   コンテナの状態を確認してください: $DOCKER_COMPOSE_CMD ps fluentd"
    echo "   ログを確認してください: $DOCKER_COMPOSE_CMD logs fluentd"
    increment_error
    exit 1
fi
echo ""

# 3. Fluentd設定ファイルの確認
echo "📋 3. Fluentd設定ファイルの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "./fluentd/fluent.conf" ]; then
    echo "✅ Fluentd設定ファイルが存在します"
    increment_success
    
    # 設定ファイルの構文チェック（可能な場合）
    echo "🔄 設定ファイルの構文チェック中..."
    if $DOCKER_COMPOSE_CMD exec -T fluentd fluentd --dry-run -c /fluentd/etc/fluent.conf > /dev/null 2>&1; then
        echo "✅ Fluentd設定ファイルの構文は正常です"
        increment_success
    else
        echo "⚠️  設定ファイルの構文チェックに失敗しました（コンテナ内で確認）"
        increment_warning
    fi
else
    echo "❌ Fluentd設定ファイルが見つかりません: ./fluentd/fluent.conf"
    increment_error
    exit 1
fi
echo ""

# 4. ログディレクトリの確認
echo "📋 4. ログディレクトリの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Nginxログディレクトリ
if [ -d "./nginx/logs" ]; then
    echo "✅ Nginxログディレクトリが存在します: ./nginx/logs"
    
    # FQDN別ログディレクトリの確認
    for fqdn in "${FQDNS[@]}"; do
        fqdn_log_dir="./nginx/logs/${fqdn}"
        if [ -d "$fqdn_log_dir" ]; then
            echo "  ✅ ${fqdn} のログディレクトリが存在します"
            
            # ログファイルの確認
            if [ -f "${fqdn_log_dir}/access.log" ]; then
                access_log_size=$(stat -f "%z" "${fqdn_log_dir}/access.log" 2>/dev/null || stat -c "%s" "${fqdn_log_dir}/access.log" 2>/dev/null || echo "0")
                echo "    ✅ access.log が存在します (サイズ: ${access_log_size} bytes)"
            else
                echo "    ⚠️  access.log が見つかりません（まだログが出力されていない可能性があります）"
            fi
            
            if [ -f "${fqdn_log_dir}/error.log" ]; then
                error_log_size=$(stat -f "%z" "${fqdn_log_dir}/error.log" 2>/dev/null || stat -c "%s" "${fqdn_log_dir}/error.log" 2>/dev/null || echo "0")
                echo "    ✅ error.log が存在します (サイズ: ${error_log_size} bytes)"
            else
                echo "    ⚠️  error.log が見つかりません（まだエラーログが出力されていない可能性があります）"
            fi
        else
            echo "  ⚠️  ${fqdn} のログディレクトリが見つかりません（まだ作成されていない可能性があります）"
        fi
    done
else
    echo "⚠️  Nginxログディレクトリが見つかりません: ./nginx/logs"
    echo "   初回起動時は自動的に作成されます"
fi

# OpenAppSecログディレクトリ
if [ -d "./openappsec/logs" ]; then
    echo "✅ OpenAppSecログディレクトリが存在します: ./openappsec/logs"
    
    # ログファイルの確認
    log_file_count=$(find ./openappsec/logs -name "*.log" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$log_file_count" -gt 0 ]; then
        echo "  ✅ ログファイル: ${log_file_count}個"
    else
        echo "  ⚠️  ログファイルが見つかりません（まだログが出力されていない可能性があります）"
    fi
else
    echo "⚠️  OpenAppSecログディレクトリが見つかりません: ./openappsec/logs"
    echo "   初回起動時は自動的に作成されます"
fi

# Fluentdログディレクトリ
if [ -d "./fluentd/log" ]; then
    echo "✅ Fluentdログディレクトリが存在します: ./fluentd/log"
else
    echo "⚠️  Fluentdログディレクトリが見つかりません: ./fluentd/log"
    echo "   初回起動時は自動的に作成されます"
fi
echo ""

# 5. ログ生成テスト（HTTPリクエストを送信）
echo "📋 5. ログ生成テスト（HTTPリクエストを送信）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HTTP_TEST_FAILED=0
for fqdn in "${FQDNS[@]}"; do
    echo "テスト: ${fqdn}"
    
    # ヘルスチェックエンドポイント
    if curl -s -m 5 -H "Host: ${fqdn}" http://localhost/health > /dev/null 2>&1; then
        echo "  ✅ ヘルスチェック: OK"
        increment_success
    else
        echo "  ❌ ヘルスチェック: 失敗"
        increment_error
        HTTP_TEST_FAILED=1
    fi
    
    # 通常のリクエスト
    response=$(curl -s -m 5 -w "\n%{http_code}" -H "Host: ${fqdn}" http://localhost/ 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        echo "  ✅ HTTPリクエスト: OK (HTTP $http_code)"
        increment_success
    else
        echo "  ⚠️  HTTPリクエスト: HTTP $http_code"
        increment_warning
    fi
done

# 少し待機してログが書き込まれるのを待つ
echo "🔄 ログの書き込みを待機中（3秒）..."
sleep 3
echo ""

# 6. NginxログのJSON形式確認
echo "📋 6. NginxログのJSON形式確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
JSON_LOG_CHECK_FAILED=0
for fqdn in "${FQDNS[@]}"; do
    access_log="./nginx/logs/${fqdn}/access.log"
    if [ -f "$access_log" ] && [ -s "$access_log" ]; then
        echo "確認: ${fqdn}"
        
        # 最新のログエントリを取得
        latest_log=$(tail -n 1 "$access_log" 2>/dev/null || echo "")
        
        if [ -n "$latest_log" ]; then
            # JSON形式かどうかを確認
            if echo "$latest_log" | jq empty > /dev/null 2>&1; then
                echo "  ✅ JSON形式のログが正しく出力されています"
                increment_success
                
                # 必須フィールドの確認
                if echo "$latest_log" | jq -e '.time, .host, .status' > /dev/null 2>&1; then
                    echo "  ✅ 必須フィールド（time, host, status）が含まれています"
                    increment_success
                else
                    echo "  ⚠️  必須フィールドが不足している可能性があります"
                    increment_warning
                fi
                
                # customer_nameフィールドの確認
                if echo "$latest_log" | jq -e '.customer_name' > /dev/null 2>&1; then
                    customer_name=$(echo "$latest_log" | jq -r '.customer_name')
                    echo "  ✅ customer_nameフィールドが含まれています: ${customer_name}"
                    increment_success
                else
                    echo "  ⚠️  customer_nameフィールドが見つかりません"
                    increment_warning
                fi
            else
                echo "  ❌ JSON形式のログではありません"
                echo "     最新のログエントリ: ${latest_log:0:100}..."
                increment_error
                JSON_LOG_CHECK_FAILED=1
            fi
        else
            echo "  ⚠️  ログエントリが見つかりません"
            increment_warning
        fi
    else
        echo "確認: ${fqdn} - ログファイルが見つかりません"
        increment_warning
    fi
done
echo ""

# 7. Fluentdのログ収集確認
echo "📋 7. Fluentdのログ収集確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Fluentdのログを確認
echo "Fluentdコンテナのログ（最新20行）:"
$DOCKER_COMPOSE_CMD logs --tail=20 fluentd 2>/dev/null | grep -E "(nginx|openappsec|error|warn)" || echo "  関連ログが見つかりません"
echo ""

# pos_fileの確認
if [ -d "./fluentd/log" ]; then
    pos_file_count=$(find ./fluentd/log -name "*.pos" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pos_file_count" -gt 0 ]; then
        echo "✅ pos_file: ${pos_file_count}個（ログ収集が進行中です）"
        increment_success
    else
        echo "⚠️  pos_fileが見つかりません（まだログが収集されていない可能性があります）"
        increment_warning
    fi
fi
echo ""

# 8. Fluentdの出力確認（stdout）
echo "📋 8. Fluentdの出力確認（stdout）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Fluentdのstdout出力を確認
echo "Fluentdのstdout出力（最新10行）:"
$DOCKER_COMPOSE_CMD logs --tail=10 fluentd 2>/dev/null | grep -E "json|nginx|openappsec" || echo "  関連ログが見つかりません"
echo ""

# 9. OpenAppSecログの確認
echo "📋 9. OpenAppSecログの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "./openappsec/logs" ]; then
    log_files=$(find ./openappsec/logs -name "*.log" -type f 2>/dev/null | head -1)
    if [ -n "$log_files" ]; then
        echo "OpenAppSecログファイル（最新5行）:"
        tail -n 5 "$log_files" 2>/dev/null || echo "  ログを読み取れませんでした"
        
        # JSON形式かどうかを確認
        latest_log=$(tail -n 1 "$log_files" 2>/dev/null || echo "")
        if [ -n "$latest_log" ]; then
            if echo "$latest_log" | jq empty > /dev/null 2>&1; then
                echo "✅ JSON形式のログが正しく出力されています"
            else
                echo "⚠️  JSON形式のログではありません"
            fi
        fi
    else
        echo "⚠️  OpenAppSecログファイルが見つかりません"
    fi
else
    echo "⚠️  OpenAppSecログディレクトリが見つかりません"
fi
echo ""

# 10. ログローテーション設定の確認
echo "📋 10. ログローテーション設定の確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "./nginx/logrotate.d/nginx" ]; then
    echo "✅ logrotate設定ファイルが存在します: ./nginx/logrotate.d/nginx"
    
    # 設定内容の確認
    if grep -q "daily" ./nginx/logrotate.d/nginx; then
        echo "  ✅ 毎日ローテート設定が有効です"
    else
        echo "  ⚠️  毎日ローテート設定が見つかりません"
    fi
    
    if grep -q "rotate 30" ./nginx/logrotate.d/nginx; then
        echo "  ✅ 30日保持設定が有効です"
    else
        echo "  ⚠️  30日保持設定が見つかりません"
    fi
else
    echo "⚠️  logrotate設定ファイルが見つかりません: ./nginx/logrotate.d/nginx"
fi
echo ""

# 11. 環境変数の確認
echo "📋 11. 環境変数の確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Fluentdコンテナの環境変数:"
$DOCKER_COMPOSE_CMD exec -T fluentd env 2>/dev/null | grep -E "FLUENTD_|LOG_COLLECTION|HOSTNAME|CUSTOMER_NAME" || echo "  環境変数が見つかりません"
echo ""

# テスト結果サマリー
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  テスト結果サマリー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 成功: ${SUCCESS_COUNT}"
echo "⚠️  警告: ${WARNING_COUNT}"
echo "❌ エラー: ${ERROR_COUNT}"
echo ""

# 終了コードの決定
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ❌ ログ転送機能動作確認: 失敗（エラーが ${ERROR_COUNT} 件発生）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
elif [ "$WARNING_COUNT" -gt 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚠️  ログ転送機能動作確認: 警告あり（警告が ${WARNING_COUNT} 件発生）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ ログ転送機能動作確認: 成功"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi
