#!/bin/bash

# Phase 5.3動作確認スクリプト
# ログ転送機能が正常に動作しているか確認します

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

cd "$DOCKER_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 5.3: ログ転送機能 動作確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# テスト用FQDNリスト
FQDNS=("test.example.com" "example1.com" "example2.com" "example3.com")

# 1. Fluentdコンテナの状態確認
echo "📋 1. Fluentdコンテナの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker-compose ps fluentd | grep -q "Up"; then
    echo "✅ Fluentdコンテナが起動しています"
    
    # Fluentdのヘルスチェック
    echo "🔄 Fluentdのヘルスチェック中..."
    if docker-compose exec -T fluentd fluentd --version > /dev/null 2>&1; then
        echo "✅ Fluentdが正常に動作しています"
    else
        echo "⚠️  Fluentdのバージョン確認に失敗しました（コンテナ内で確認）"
    fi
else
    echo "❌ Fluentdコンテナが起動していません"
    echo "   起動してください: docker-compose up -d fluentd"
    exit 1
fi
echo ""

# 2. Fluentd設定ファイルの確認
echo "📋 2. Fluentd設定ファイルの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "./fluentd/fluent.conf" ]; then
    echo "✅ Fluentd設定ファイルが存在します"
    
    # 設定ファイルの構文チェック（可能な場合）
    echo "🔄 設定ファイルの構文チェック中..."
    if docker-compose exec -T fluentd fluentd --dry-run -c /fluentd/etc/fluent.conf > /dev/null 2>&1; then
        echo "✅ Fluentd設定ファイルの構文は正常です"
    else
        echo "⚠️  設定ファイルの構文チェックに失敗しました（コンテナ内で確認）"
    fi
else
    echo "❌ Fluentd設定ファイルが見つかりません: ./fluentd/fluent.conf"
    exit 1
fi
echo ""

# 3. ログディレクトリの確認
echo "📋 3. ログディレクトリの確認"
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

# 4. ログ生成テスト（HTTPリクエストを送信）
echo "📋 4. ログ生成テスト（HTTPリクエストを送信）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for fqdn in "${FQDNS[@]}"; do
    echo "テスト: ${fqdn}"
    
    # ヘルスチェックエンドポイント
    if curl -s -H "Host: ${fqdn}" http://localhost/health > /dev/null; then
        echo "  ✅ ヘルスチェック: OK"
    else
        echo "  ❌ ヘルスチェック: 失敗"
    fi
    
    # 通常のリクエスト
    response=$(curl -s -w "\n%{http_code}" -H "Host: ${fqdn}" http://localhost/ 2>/dev/null || echo -e "\n000")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        echo "  ✅ HTTPリクエスト: OK (HTTP $http_code)"
    else
        echo "  ⚠️  HTTPリクエスト: HTTP $http_code"
    fi
done

# 少し待機してログが書き込まれるのを待つ
echo "🔄 ログの書き込みを待機中（3秒）..."
sleep 3
echo ""

# 5. NginxログのJSON形式確認
echo "📋 5. NginxログのJSON形式確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
                
                # 必須フィールドの確認
                if echo "$latest_log" | jq -e '.time, .host, .status' > /dev/null 2>&1; then
                    echo "  ✅ 必須フィールド（time, host, status）が含まれています"
                else
                    echo "  ⚠️  必須フィールドが不足している可能性があります"
                fi
                
                # customer_nameフィールドの確認
                if echo "$latest_log" | jq -e '.customer_name' > /dev/null 2>&1; then
                    customer_name=$(echo "$latest_log" | jq -r '.customer_name')
                    echo "  ✅ customer_nameフィールドが含まれています: ${customer_name}"
                else
                    echo "  ⚠️  customer_nameフィールドが見つかりません"
                fi
            else
                echo "  ❌ JSON形式のログではありません"
                echo "     最新のログエントリ: ${latest_log:0:100}..."
            fi
        else
            echo "  ⚠️  ログエントリが見つかりません"
        fi
    else
        echo "確認: ${fqdn} - ログファイルが見つかりません"
    fi
done
echo ""

# 6. Fluentdのログ収集確認
echo "📋 6. Fluentdのログ収集確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Fluentdのログを確認
echo "Fluentdコンテナのログ（最新20行）:"
docker-compose logs --tail=20 fluentd | grep -E "(nginx|openappsec|error|warn)" || echo "  関連ログが見つかりません"
echo ""

# pos_fileの確認
if [ -d "./fluentd/log" ]; then
    pos_file_count=$(find ./fluentd/log -name "*.pos" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pos_file_count" -gt 0 ]; then
        echo "✅ pos_file: ${pos_file_count}個（ログ収集が進行中です）"
    else
        echo "⚠️  pos_fileが見つかりません（まだログが収集されていない可能性があります）"
    fi
fi
echo ""

# 7. Fluentdの出力確認（stdout）
echo "📋 7. Fluentdの出力確認（stdout）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Fluentdのstdout出力を確認
echo "Fluentdのstdout出力（最新10行）:"
docker-compose logs --tail=10 fluentd | grep -E "json|nginx|openappsec" || echo "  関連ログが見つかりません"
echo ""

# 8. OpenAppSecログの確認
echo "📋 8. OpenAppSecログの確認"
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

# 9. ログローテーション設定の確認
echo "📋 9. ログローテーション設定の確認"
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

# 10. 環境変数の確認
echo "📋 10. 環境変数の確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Fluentdコンテナの環境変数:"
docker-compose exec -T fluentd env | grep -E "FLUENTD_|LOG_COLLECTION|HOSTNAME|CUSTOMER_NAME" || echo "  環境変数が見つかりません"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Phase 5.3動作確認完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "次のステップ:"
echo "  1. Fluentdのログを確認して、ログが正しく収集されているか確認"
echo "  2. ログ転送先（HTTP/HTTPS）が設定されている場合、転送が正常に動作しているか確認"
echo "  3. ログローテーションが正常に動作するか確認（時間経過後）"
echo "  4. 大量のログが発生した場合のパフォーマンスを確認"
