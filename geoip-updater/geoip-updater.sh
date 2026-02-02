#!/bin/bash
# GeoIPデータベース自動更新スクリプト
#
# 使い方:
#   geoip-updater.sh [update|test|version]
#
# 環境変数:
#   MAXMIND_LICENSE_KEY: MaxMind License Key（必須）
#   MAXMIND_ACCOUNT_ID: MaxMind Account ID（オプション）
#   GEOIP_DB_PATH: GeoIPデータベースのパス（デフォルト: /usr/share/GeoIP）
#   NGINX_CONTAINER_NAME: Nginxコンテナ名（デフォルト: mwd-nginx）
#   BACKUP_RETENTION_DAYS: バックアップ保持日数（デフォルト: 7）

set -e

# ログ関数
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ エラー: $*" >&2
}

# 設定
MAXMIND_LICENSE_KEY="${MAXMIND_LICENSE_KEY:-}"
MAXMIND_ACCOUNT_ID="${MAXMIND_ACCOUNT_ID:-}"
GEOIP_DB_PATH="${GEOIP_DB_PATH:-/usr/share/GeoIP}"
GEOIP_DB_FILE="GeoLite2-Country.mmdb"
NGINX_CONTAINER_NAME="${NGINX_CONTAINER_NAME:-mwd-nginx}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# コマンド
COMMAND="${1:-update}"

# バージョン表示
show_version() {
  if [ -f "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" ]; then
    log "📊 現在のGeoIPデータベース情報:"
    log "  ファイル: ${GEOIP_DB_PATH}/${GEOIP_DB_FILE}"
    log "  サイズ: $(du -h "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" | cut -f1)"
    log "  更新日時: $(stat -c '%y' "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" 2>/dev/null || stat -f '%Sm' "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}")"
  else
    error "GeoIPデータベースが見つかりません: ${GEOIP_DB_PATH}/${GEOIP_DB_FILE}"
    exit 1
  fi
}

# テストモード
test_mode() {
  log "🧪 テストモード"
  
  # MaxMind License Key確認
  if [ -z "$MAXMIND_LICENSE_KEY" ]; then
    error "MAXMIND_LICENSE_KEYが設定されていません"
    exit 1
  fi
  log "✅ MAXMIND_LICENSE_KEY: 設定済み（${#MAXMIND_LICENSE_KEY}文字）"
  
  # GeoIPデータベースパス確認
  if [ ! -d "$GEOIP_DB_PATH" ]; then
    error "GeoIPデータベースパスが存在しません: ${GEOIP_DB_PATH}"
    exit 1
  fi
  log "✅ GeoIPデータベースパス: ${GEOIP_DB_PATH}"
  
  # Nginxコンテナ確認
  if docker ps --format '{{.Names}}' | grep -q "^${NGINX_CONTAINER_NAME}$"; then
    log "✅ Nginxコンテナ: ${NGINX_CONTAINER_NAME} (起動中)"
  else
    error "Nginxコンテナが起動していません: ${NGINX_CONTAINER_NAME}"
    exit 1
  fi
  
  # 現在のGeoIPデータベース情報表示
  show_version
  
  log "✅ すべてのテストが成功しました"
}

# 更新モード
update_mode() {
  # MaxMind License Key確認
  if [ -z "$MAXMIND_LICENSE_KEY" ]; then
    error "MAXMIND_LICENSE_KEYが設定されていません"
    error "使い方:"
    error "  export MAXMIND_LICENSE_KEY='your-license-key'"
    error "  $0 update"
    exit 1
  fi
  
  log "🔄 GeoIPデータベースの更新を開始します"
  
  # ダウンロード
  log "📥 GeoLite2-Country.mmdbをダウンロード中..."
  if ! curl -L -f \
    "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" \
    -o /tmp/GeoLite2-Country.tar.gz; then
    error "ダウンロードに失敗しました"
    exit 1
  fi
  
  # 解凍
  log "📦 ファイルを解凍中..."
  tar -xzf /tmp/GeoLite2-Country.tar.gz -C /tmp
  
  # バックアップ
  if [ -f "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" ]; then
    BACKUP_FILE="${GEOIP_DB_PATH}/${GEOIP_DB_FILE}.$(date +'%Y%m%d_%H%M%S').bak"
    log "💾 既存ファイルをバックアップ: ${BACKUP_FILE}"
    cp "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" "${BACKUP_FILE}"
  fi
  
  # 新しいファイルを配置
  log "📝 新しいファイルを配置中..."
  find /tmp -name "${GEOIP_DB_FILE}" -exec mv {} "${GEOIP_DB_PATH}/" \;
  
  # 権限設定
  chmod 644 "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}"
  
  # 古いバックアップの削除
  log "🗑️  古いバックアップを削除中（${BACKUP_RETENTION_DAYS}日以上）..."
  find "${GEOIP_DB_PATH}" -name "${GEOIP_DB_FILE}.*.bak" -mtime +${BACKUP_RETENTION_DAYS} -delete 2>/dev/null || true
  
  # Nginxリロード
  log "🔄 Nginxをリロード中..."
  if docker exec "${NGINX_CONTAINER_NAME}" nginx -t 2>&1; then
    docker exec "${NGINX_CONTAINER_NAME}" nginx -s reload
    log "✅ Nginxリロードが成功しました"
  else
    error "Nginx設定テストに失敗しました"
    if [ -f "${BACKUP_FILE}" ]; then
      log "🔙 バックアップから復元中..."
      mv "${BACKUP_FILE}" "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}"
      log "✅ バックアップから復元しました"
    fi
    exit 1
  fi
  
  # クリーンアップ
  rm -rf /tmp/GeoLite2-Country*
  
  log "✅ GeoIPデータベースの更新が完了しました"
  
  # 更新後の情報表示
  show_version
}

# 使い方表示
show_usage() {
  cat << EOF
使い方: $0 [COMMAND]

コマンド:
  update      GeoIPデータベースを更新（デフォルト）
  test        設定と環境をテスト
  version     現在のGeoIPデータベース情報を表示
  help        このヘルプを表示

環境変数:
  MAXMIND_LICENSE_KEY       MaxMind License Key（必須）
  MAXMIND_ACCOUNT_ID        MaxMind Account ID（オプション）
  GEOIP_DB_PATH             GeoIPデータベースのパス（デフォルト: /usr/share/GeoIP）
  NGINX_CONTAINER_NAME      Nginxコンテナ名（デフォルト: mwd-nginx）
  BACKUP_RETENTION_DAYS     バックアップ保持日数（デフォルト: 7）

例:
  # テストモード
  export MAXMIND_LICENSE_KEY='your-license-key'
  $0 test

  # 更新モード
  export MAXMIND_LICENSE_KEY='your-license-key'
  $0 update

  # バージョン表示
  $0 version

EOF
}

# メイン処理
case "$COMMAND" in
  update)
    update_mode
    ;;
  test)
    test_mode
    ;;
  version)
    show_version
    ;;
  help|--help|-h)
    show_usage
    ;;
  *)
    error "不明なコマンド: $COMMAND"
    show_usage
    exit 1
    ;;
esac
