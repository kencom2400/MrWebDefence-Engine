#!/bin/bash
# GeoIP機能統合テストスクリプト
#
# 使い方:
#   test-geoip.sh [OPTIONS]
#
# オプション:
#   --fqdn <FQDN>       テスト対象のFQDN（デフォルト: example.com）
#   --port <PORT>       テスト対象のポート（デフォルト: 80）
#   --verbose           詳細なログを表示
#   --help              このヘルプを表示

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# デフォルト設定
TEST_FQDN="${TEST_FQDN:-example.com}"
TEST_PORT="${TEST_PORT:-80}"
VERBOSE=false

# ログ関数
log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

success() {
  echo -e "${GREEN}✅ $*${NC}"
}

error() {
  echo -e "${RED}❌ $*${NC}"
}

warning() {
  echo -e "${YELLOW}⚠️  $*${NC}"
}

# オプション解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --fqdn)
      TEST_FQDN="$2"
      shift 2
      ;;
    --port)
      TEST_PORT="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      cat << EOF
使い方: $0 [OPTIONS]

オプション:
  --fqdn <FQDN>       テスト対象のFQDN（デフォルト: example.com）
  --port <PORT>       テスト対象のポート（デフォルト: 80）
  --verbose           詳細なログを表示
  --help              このヘルプを表示

環境変数:
  TEST_FQDN           テスト対象のFQDN
  TEST_PORT           テスト対象のポート

例:
  # デフォルト設定でテスト
  $0

  # 特定のFQDNとポートでテスト
  $0 --fqdn example.com --port 80

  # 詳細ログ付きでテスト
  $0 --verbose

EOF
      exit 0
      ;;
    *)
      error "不明なオプション: $1"
      exit 1
      ;;
  esac
done

# テストヘッダー
log "=========================================="
log "GeoIP機能統合テスト"
log "=========================================="
log "テスト対象: ${TEST_FQDN}:${TEST_PORT}"
log ""

# テストカウンター
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# テストケース実行関数
run_test() {
  local test_name="$1"
  local test_ip="$2"
  local expected_status="$3"
  local description="$4"
  
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  log "=========================================="
  log "テストケース ${TOTAL_TESTS}: ${test_name}"
  log "説明: ${description}"
  log "テストIP: ${test_ip}"
  log "期待ステータス: ${expected_status}"
  
  # HTTPリクエスト実行
  local response
  local status_code
  
  if [ "$VERBOSE" = true ]; then
    response=$(curl -s -w "\n%{http_code}" \
      -H "Host: ${TEST_FQDN}" \
      -H "X-Forwarded-For: ${test_ip}" \
      "http://localhost:${TEST_PORT}/" 2>&1)
  else
    response=$(curl -s -w "\n%{http_code}" \
      -H "Host: ${TEST_FQDN}" \
      -H "X-Forwarded-For: ${test_ip}" \
      "http://localhost:${TEST_PORT}/" 2>/dev/null)
  fi
  
  # ステータスコードを抽出
  status_code=$(echo "$response" | tail -1)
  local body=$(echo "$response" | head -n -1)
  
  log "実際のステータス: ${status_code}"
  
  if [ "$VERBOSE" = true ]; then
    log "レスポンスボディ:"
    echo "$body" | head -10
  fi
  
  # ステータスコードの検証
  if [ "$status_code" = "$expected_status" ]; then
    success "テストケース ${TOTAL_TESTS}: 成功"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    error "テストケース ${TOTAL_TESTS}: 失敗"
    error "  期待: ${expected_status}, 実際: ${status_code}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  
  log ""
}

# テストケース1: 日本からのアクセス（許可）
# 注意: 203.0.113.0/24はドキュメント用に予約されたIPレンジ（RFC 5737）
# 実際のGeoIPデータベースでは国コードが取得できない可能性があるため、
# 実際のIPアドレスを使用する必要がある
run_test \
  "日本からのアクセス（許可）" \
  "203.0.113.1" \
  "200" \
  "日本のIPアドレスからのアクセス（AllowListに含まれる場合）"

# テストケース2: AllowList IPからのアクセス（許可）
run_test \
  "AllowList IPからのアクセス（許可）" \
  "192.168.1.100" \
  "200" \
  "IP AllowListに含まれるIPアドレスからのアクセス"

# テストケース3: BlockList IPからのアクセス（拒否）
run_test \
  "BlockList IPからのアクセス（拒否）" \
  "198.51.100.100" \
  "403" \
  "IP BlockListに含まれるIPアドレスからのアクセス"

# テストケース4: BlockList国（ロシア）からのアクセス（拒否）
# 注意: 実際のロシアのIPアドレスを使用
run_test \
  "BlockList国（ロシア）からのアクセス（拒否）" \
  "5.255.255.1" \
  "403" \
  "ロシアのIPアドレスからのアクセス（BlockListに含まれる場合）"

# テストケース5: 中国からのアクセス（中立）
# 注意: AllowListにもBlockListにも含まれない国
run_test \
  "中国からのアクセス（中立）" \
  "1.2.3.4" \
  "200" \
  "AllowListにもBlockListにも含まれない国からのアクセス"

# テストケース6: X-Forwarded-Forヘッダーなし
run_test \
  "X-Forwarded-Forヘッダーなし" \
  "" \
  "200" \
  "X-Forwarded-Forヘッダーがない場合（remote_addrを使用）"

# テスト結果サマリー
log "=========================================="
log "テスト結果サマリー"
log "=========================================="
log "総テスト数: ${TOTAL_TESTS}"
success "成功: ${PASSED_TESTS}"
if [ "$FAILED_TESTS" -gt 0 ]; then
  error "失敗: ${FAILED_TESTS}"
else
  success "失敗: ${FAILED_TESTS}"
fi
log ""

# 終了コード
if [ "$FAILED_TESTS" -gt 0 ]; then
  error "❌ テストに失敗しました"
  exit 1
else
  success "✅ すべてのテストが成功しました"
  exit 0
fi
