# Task 5.5: GeoIP機能実装計画

## 概要

IPアドレス/CIDRブロックと国単位のアクセス制御機能を実装します。

**Issue**: [MWD-42](https://kencom2400.atlassian.net/browse/MWD-42)  
**親Epic**: [MWD-5: WAFエンジン基盤実装](https://kencom2400.atlassian.net/browse/MWD-5)

## なぜやるか

IPアドレス/CIDRブロックと国単位のアクセス制御を実装する必要がある。

## 何をやるか（概要）

- MaxMindDB統合実装
- IP/CIDR判定ロジック実装（AllowList優先）
- 国コード判定ロジック実装
- GeoIPデータベース自動更新機能実装
- X-Forwarded-For対応実装

## 受け入れ条件

- [ ] MaxMindDBが正常に統合されている
- [ ] IP/CIDR判定ロジックが正常に動作する
- [ ] 国コード判定ロジックが正常に動作する
- [ ] GeoIPデータベース自動更新が正常に動作する
- [ ] X-Forwarded-For対応が正常に動作する

## アーキテクチャ設計

### システム構成

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ HTTP/HTTPS Request
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              Nginx (Proxy + WAF)                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  GeoIP Module (ngx_http_geoip2_module)                  ││
│  │  - X-Forwarded-For解析                                  ││
│  │  - MaxMindDB GeoLite2-Country.mmdb 参照                ││
│  │  - 変数設定: $geoip2_data_country_iso_code             ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │  GeoIP Access Control Logic                            ││
│  │  - IP/CIDR判定 (Allow/Block)                          ││
│  │  - 国コード判定 (Allow/Block)                         ││
│  │  - AllowList優先ロジック                              ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │  OpenAppSec Attachment Module                          ││
│  │  - WAF検査                                             ││
│  │  - 攻撃検知・ブロック                                  ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ Proxied Request
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                    Backend Server                            │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│               GeoIP Database Update Service                  │
│  - 週次自動更新 (cron)                                       │
│  - MaxMind API経由でダウンロード                            │
│  - Nginxリロード                                             │
└──────────────────────────────────────────────────────────────┘
```

### コンポーネント構成

#### 1. Nginx GeoIP Module

**使用モジュール**: `ngx_http_geoip2_module`

**理由**:
- MaxMind GeoIP2/GeoLite2データベース（.mmdb形式）をサポート
- 高速なメモリマップドファイルアクセス
- IPv4/IPv6対応
- X-Forwarded-Forヘッダーのサポート

**代替案との比較**:

| モジュール | GeoLite2対応 | パフォーマンス | メンテナンス状況 |
|----------|-------------|--------------|----------------|
| ngx_http_geoip2_module | ✅ 対応 | 高速 | 活発 |
| ngx_http_geoip_module (旧) | ❌ GeoIP Legacy | 高速 | 非推奨 |
| Lua + lua-resty-maxminddb | ✅ 対応 | 中速 | 活発 |

**選択理由**: ngx_http_geoip2_moduleは公式モジュールで、パフォーマンスが高く、メンテナンスも活発。

#### 2. GeoIP判定ロジック

**実装場所**: Nginx設定ファイル（各FQDN別設定）

**判定フロー**:

```nginx
# 1. X-Forwarded-Forから実IPを取得
set $real_ip $remote_addr;
if ($http_x_forwarded_for ~* "^([^,\s]+)") {
    set $real_ip $1;
}

# 2. GeoIP2モジュールでIPから国コードを取得
geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
    $geoip2_data_country_iso_code country iso_code;
}

# 3. AllowList判定（最優先）
# IP AllowList
geo $ip_allowlist {
    default 0;
    192.168.1.0/24 1;  # 内部ネットワーク
    203.0.113.0/24 1;  # 特定IPレンジ
}

# 国コード AllowList
map $geoip2_data_country_iso_code $country_allowlist {
    default 0;
    JP 1;  # 日本
    US 1;  # アメリカ
}

# 4. BlockList判定
# IP BlockList
geo $ip_blocklist {
    default 0;
    198.51.100.0/24 1;  # ブロック対象IPレンジ
}

# 国コード BlockList
map $geoip2_data_country_iso_code $country_blocklist {
    default 0;
    KP 1;  # 北朝鮮
    RU 1;  # ロシア
}

# 5. アクセス制御判定（AllowList優先）
set $access_allowed 0;

# AllowListに含まれる場合は許可
if ($ip_allowlist = "1") {
    set $access_allowed 1;
}
if ($country_allowlist = "1") {
    set $access_allowed 1;
}

# AllowListに含まれず、BlockListに含まれる場合はブロック
if ($ip_blocklist = "1") {
    set $access_allowed 0;
}
if ($country_blocklist = "1") {
    set $access_allowed 0;
}

# アクセス拒否
if ($access_allowed = "0") {
    return 403;
}
```

**注意点**:
- Nginxの`if`ディレクティブは制限が多いため、`geo`と`map`ディレクティブを組み合わせる
- AllowList優先の実装には注意が必要（ロジックの順序が重要）

#### 3. GeoIPデータベース自動更新

**実装場所**: 新規コンテナ `geoip-updater`

**更新頻度**: 週次（毎週火曜日 3:00 AM JST）

**実装方法**:

```bash
#!/bin/bash
# geoip-updater.sh

set -e

# MaxMind API設定
MAXMIND_LICENSE_KEY="${MAXMIND_LICENSE_KEY:-}"
MAXMIND_ACCOUNT_ID="${MAXMIND_ACCOUNT_ID:-}"
GEOIP_DB_PATH="/usr/share/GeoIP"
GEOIP_DB_FILE="GeoLite2-Country.mmdb"

# ダウンロード
curl -L "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" \
  -o /tmp/GeoLite2-Country.tar.gz

# 解凍
tar -xzf /tmp/GeoLite2-Country.tar.gz -C /tmp

# 既存ファイルをバックアップ
if [ -f "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" ]; then
  mv "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}.bak"
fi

# 新しいファイルを配置
mv /tmp/GeoLite2-Country_*/${GEOIP_DB_FILE} "${GEOIP_DB_PATH}/"

# Nginxリロード
docker exec mwd-nginx nginx -s reload

echo "✅ GeoIP database updated successfully"
```

**cron設定**:

```cron
# 毎週火曜日 3:00 AM JST
0 3 * * 2 /app/geoip-updater.sh >> /var/log/geoip-updater.log 2>&1
```

## 実装フェーズ

### Phase 1: MaxMindDB統合実装

#### 1.1 Dockerイメージの選定

**選択肢**:

1. **既存イメージをそのまま使用** (`ghcr.io/openappsec/nginx-attachment:latest`)
   - ✅ OpenAppSec統合済み
   - ❌ GeoIP2モジュールが含まれていない可能性がある
   - 確認方法: `docker exec mwd-nginx nginx -V 2>&1 | grep geoip2`

2. **カスタムDockerイメージを作成**
   - ✅ 必要なモジュールを確実にインストール
   - ✅ バージョン管理が容易
   - ❌ ビルド時間が増加
   - ❌ OpenAppSecモジュールとの互換性確認が必要

**推奨**: カスタムDockerイメージを作成（Phase 1で実装）

#### 1.2 Dockerfileの作成

```dockerfile
# docker/nginx/Dockerfile
FROM ghcr.io/openappsec/nginx-attachment:latest

# GeoIP2モジュールとMaxMindDBライブラリのインストール
RUN apt-get update && \
    apt-get install -y \
    libmaxminddb0 \
    libmaxminddb-dev \
    mmdb-bin \
    wget \
    build-essential \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# ngx_http_geoip2_moduleのビルドとインストール
# 注意: Nginxのバージョンに合わせてモジュールをビルドする必要がある
ARG NGINX_VERSION
ARG GEOIP2_MODULE_VERSION=3.4

RUN cd /tmp && \
    wget https://github.com/leev/ngx_http_geoip2_module/archive/${GEOIP2_MODULE_VERSION}.tar.gz && \
    tar -xzf ${GEOIP2_MODULE_VERSION}.tar.gz && \
    cd ngx_http_geoip2_module-${GEOIP2_MODULE_VERSION} && \
    # Nginxのソースコードと一緒にビルド（動的モジュールとして）
    # 詳細なビルド手順は既存のNginxバージョンに依存するため、実装時に調整

# GeoIPデータベース用ディレクトリ作成
RUN mkdir -p /usr/share/GeoIP

# GeoLite2-Country.mmdbの初期ダウンロード（オプション）
# 注意: MaxMind License Keyが必要（環境変数で渡す）
# ARG MAXMIND_LICENSE_KEY
# RUN if [ -n "$MAXMIND_LICENSE_KEY" ]; then \
#     wget -O /tmp/GeoLite2-Country.tar.gz \
#     "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" && \
#     tar -xzf /tmp/GeoLite2-Country.tar.gz -C /tmp && \
#     mv /tmp/GeoLite2-Country_*/GeoLite2-Country.mmdb /usr/share/GeoIP/ && \
#     rm -rf /tmp/GeoLite2-Country*; \
#     fi

CMD ["nginx", "-g", "daemon off;"]
```

**注意点**:
- OpenAppSecモジュールとの互換性を確認
- Nginxのバージョンに合わせてGeoIP2モジュールをビルド
- ビルド時間の最適化（マルチステージビルドの検討）

#### 1.3 docker-compose.ymlの更新

```yaml
services:
  nginx:
    # カスタムイメージを使用
    build:
      context: ./nginx
      dockerfile: Dockerfile
      args:
        - NGINX_VERSION=1.24.0  # 既存イメージのバージョンに合わせる
        - GEOIP2_MODULE_VERSION=3.4
    # ... 既存の設定 ...
    volumes:
      # GeoIPデータベースのマウント
      - geoip-data:/usr/share/GeoIP:ro

  geoip-updater:
    image: alpine:latest
    container_name: mwd-geoip-updater
    volumes:
      - ./geoip-updater:/app:ro
      - geoip-data:/usr/share/GeoIP:rw
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - MAXMIND_LICENSE_KEY=${MAXMIND_LICENSE_KEY}
      - MAXMIND_ACCOUNT_ID=${MAXMIND_ACCOUNT_ID}
      - NGINX_CONTAINER_NAME=mwd-nginx
    command: /bin/sh -c "apk add --no-cache curl bash docker-cli && crond -f"
    networks:
      - mwd-network
    restart: unless-stopped

volumes:
  # GeoIPデータベース用ボリューム
  geoip-data:
    driver: local
```

### Phase 2: IP/CIDR判定ロジック実装

#### 2.1 設定ファイル生成機能の拡張

**更新ファイル**: `config-agent/lib/nginx-config-generator.sh`

**追加機能**:
- API設定データからGeoIP設定を取得
- IP AllowList/BlockListの生成
- 国コード AllowList/BlockListの生成

**API設定データ形式**:

```json
{
  "version": "1.0.0",
  "fqdns": [
    {
      "fqdn": "example.com",
      "geoip": {
        "enabled": true,
        "ip_allowlist": [
          "192.168.1.0/24",
          "203.0.113.0/24"
        ],
        "ip_blocklist": [
          "198.51.100.0/24"
        ],
        "country_allowlist": ["JP", "US"],
        "country_blocklist": ["KP", "RU"],
        "allowlist_priority": true,
        "x_forwarded_for": {
          "enabled": true,
          "trusted_proxies": ["192.168.0.0/16"]
        }
      }
    }
  ]
}
```

#### 2.2 Nginx設定テンプレートの更新

**生成される設定例**:

```nginx
# FQDN設定: example.com
# 自動生成: 2026-02-02 15:00:00

# GeoIP2データベース読み込み（httpコンテキスト、1回のみ）
# 注意: この設定はnginx.confに追加する（各FQDN設定ファイルではない）
# geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
#     $geoip2_data_country_iso_code country iso_code;
# }

server {
    listen 80;
    server_name example.com;

    # 顧客名を変数に設定
    set $customer_name "default";

    # X-Forwarded-Forから実IPを取得
    set $real_ip $remote_addr;
    
    # 信頼できるプロキシからのX-Forwarded-Forヘッダーを使用
    set_real_ip_from 192.168.0.0/16;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    # IP AllowList（geo）
    geo $real_ip $ip_allowlist {
        default 0;
        192.168.1.0/24 1;
        203.0.113.0/24 1;
    }

    # IP BlockList（geo）
    geo $real_ip $ip_blocklist {
        default 0;
        198.51.100.0/24 1;
    }

    # 国コード AllowList（map）
    map $geoip2_data_country_iso_code $country_allowlist {
        default 0;
        JP 1;
        US 1;
    }

    # 国コード BlockList（map）
    map $geoip2_data_country_iso_code $country_blocklist {
        default 0;
        KP 1;
        RU 1;
    }

    # アクセス制御ロジック（AllowList優先）
    set $access_allowed 1;  # デフォルトは許可

    # AllowListが定義されている場合、デフォルトを拒否に変更
    if ($ip_allowlist) {
        set $access_allowed 0;
    }

    # IP AllowListに含まれる場合は許可
    if ($ip_allowlist = "1") {
        set $access_allowed 1;
    }

    # 国コード AllowListに含まれる場合は許可
    if ($country_allowlist = "1") {
        set $access_allowed 1;
    }

    # IP BlockListに含まれる場合は拒否
    if ($ip_blocklist = "1") {
        set $access_allowed 0;
    }

    # 国コード BlockListに含まれる場合は拒否
    if ($country_blocklist = "1") {
        set $access_allowed 0;
    }

    # アクセス拒否
    if ($access_allowed = "0") {
        return 403 '{"error": "Access denied", "reason": "GeoIP policy violation"}';
        add_header Content-Type application/json always;
    }

    # ログ設定
    access_log /var/log/nginx/example.com/access.log json_combined;
    error_log /var/log/nginx/example.com/error.log warn;

    location / {
        proxy_pass http://backend-server:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $real_ip;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-GeoIP-Country $geoip2_data_country_iso_code;
    }
}
```

### Phase 3: 国コード判定ロジック実装

Phase 2で同時に実装（上記参照）

### Phase 4: GeoIPデータベース自動更新機能実装

#### 4.1 更新スクリプトの作成

**ファイル**: `geoip-updater/geoip-updater.sh`

```bash
#!/bin/bash
# GeoIPデータベース自動更新スクリプト

set -e

# ログ関数
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# 設定
MAXMIND_LICENSE_KEY="${MAXMIND_LICENSE_KEY:-}"
MAXMIND_ACCOUNT_ID="${MAXMIND_ACCOUNT_ID:-}"
GEOIP_DB_PATH="/usr/share/GeoIP"
GEOIP_DB_FILE="GeoLite2-Country.mmdb"
NGINX_CONTAINER_NAME="${NGINX_CONTAINER_NAME:-mwd-nginx}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# MaxMind License Key確認
if [ -z "$MAXMIND_LICENSE_KEY" ]; then
  log "❌ エラー: MAXMIND_LICENSE_KEYが設定されていません"
  exit 1
fi

log "🔄 GeoIPデータベースの更新を開始します"

# ダウンロード
log "📥 GeoLite2-Country.mmdbをダウンロード中..."
curl -L -f \
  "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" \
  -o /tmp/GeoLite2-Country.tar.gz

# 解凍
log "📦 ファイルを解凍中..."
tar -xzf /tmp/GeoLite2-Country.tar.gz -C /tmp

# バックアップ
if [ -f "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" ]; then
  BACKUP_FILE="${GEOIP_DB_PATH}/${GEOIP_DB_FILE}.$(date +'%Y%m%d_%H%M%S').bak"
  log "💾 既存ファイルをバックアップ: ${BACKUP_FILE}"
  mv "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}" "${BACKUP_FILE}"
fi

# 新しいファイルを配置
log "📝 新しいファイルを配置中..."
find /tmp -name "${GEOIP_DB_FILE}" -exec mv {} "${GEOIP_DB_PATH}/" \;

# 権限設定
chmod 644 "${GEOIP_DB_PATH}/${GEOIP_DB_FILE}"

# 古いバックアップの削除
log "🗑️  古いバックアップを削除中（${BACKUP_RETENTION_DAYS}日以上）..."
find "${GEOIP_DB_PATH}" -name "${GEOIP_DB_FILE}.*.bak" -mtime +${BACKUP_RETENTION_DAYS} -delete

# Nginxリロード
log "🔄 Nginxをリロード中..."
docker exec "${NGINX_CONTAINER_NAME}" nginx -t && \
docker exec "${NGINX_CONTAINER_NAME}" nginx -s reload

# クリーンアップ
rm -rf /tmp/GeoLite2-Country*

log "✅ GeoIPデータベースの更新が完了しました"
```

#### 4.2 cron設定

**ファイル**: `geoip-updater/crontab`

```cron
# GeoIPデータベース自動更新
# 毎週火曜日 3:00 AM JST（月曜日 18:00 UTC）
0 18 * * 1 /app/geoip-updater.sh >> /var/log/geoip-updater.log 2>&1

# ログローテーション（毎日 4:00 AM JST）
0 19 * * * find /var/log -name "geoip-updater.log.*" -mtime +30 -delete
```

### Phase 5: X-Forwarded-For対応実装

Phase 2で同時に実装（上記参照）

### Phase 6: テストスクリプト作成

#### 6.1 統合テストスクリプト

**ファイル**: `scripts/openappsec/test-geoip.sh`

```bash
#!/bin/bash
# GeoIP機能統合テストスクリプト

set -e

# テスト対象
TEST_FQDN="${TEST_FQDN:-example.com}"
TEST_PORT="${TEST_PORT:-80}"

# テストケース1: 日本からのアクセス（許可）
echo "=== テストケース1: 日本からのアクセス（許可） ==="
curl -H "Host: ${TEST_FQDN}" \
  -H "X-Forwarded-For: 203.0.113.1" \
  http://localhost:${TEST_PORT}/

# テストケース2: AllowList IPからのアクセス（許可）
echo "=== テストケース2: AllowList IPからのアクセス（許可） ==="
curl -H "Host: ${TEST_FQDN}" \
  -H "X-Forwarded-For: 192.168.1.100" \
  http://localhost:${TEST_PORT}/

# テストケース3: BlockList IPからのアクセス（拒否）
echo "=== テストケース3: BlockList IPからのアクセス（拒否） ==="
curl -H "Host: ${TEST_FQDN}" \
  -H "X-Forwarded-For: 198.51.100.100" \
  http://localhost:${TEST_PORT}/ || echo "✅ 期待通りアクセスが拒否されました"

# テストケース4: BlockList国（ロシア）からのアクセス（拒否）
echo "=== テストケース4: BlockList国（ロシア）からのアクセス（拒否） ==="
curl -H "Host: ${TEST_FQDN}" \
  -H "X-Forwarded-For: 5.255.255.1" \
  http://localhost:${TEST_PORT}/ || echo "✅ 期待通りアクセスが拒否されました"

echo "✅ すべてのテストが完了しました"
```

### Phase 7: ドキュメント作成

#### 7.1 README作成

**ファイル**: `README-TASK-5-5.md`

- クイックスタート
- 設定方法
- トラブルシューティング
- FAQ

## セキュリティ考慮事項

### 1. MaxMind License Key管理

- 環境変数で管理（`.env`ファイル、Dockerシークレット）
- Gitにコミットしない（`.gitignore`に追加）

### 2. X-Forwarded-Forの信頼性

- 信頼できるプロキシのIPレンジを設定
- `real_ip_recursive on`で多段プロキシに対応

### 3. GeoIPデータベースの更新

- 自動更新を有効化
- バックアップを保持

## パフォーマンス考慮事項

### 1. GeoIP2モジュールのパフォーマンス

- メモリマップドファイルアクセスで高速
- キャッシュ機能あり

### 2. Nginx設定の最適化

- `geo`と`map`ディレクティブは起動時に評価されるため、リクエスト時のオーバーヘッドは最小限

## 制限事項

### 1. Nginxの`if`ディレクティブの制限

- 複雑な条件分岐には`geo`と`map`を組み合わせる
- `if`は最小限に使用

### 2. GeoIPデータベースの精度

- 100%正確ではない
- VPN/プロキシ経由のアクセスは検知困難

## 移行戦略

### 1. 段階的ロールアウト

1. Phase 1: 開発環境での動作確認
2. Phase 2: ステージング環境でのテスト
3. Phase 3: 本番環境への展開（一部FQDNのみ）
4. Phase 4: 全FQDNへの展開

### 2. ロールバック計画

- Docker Composeでの切り戻し
- バックアップからの復元

## 次のステップ

1. MaxMind License Keyの取得
2. カスタムDockerイメージのビルド
3. 開発環境での動作確認
4. 統合テストの実施
5. ドキュメント作成
6. 本番環境への展開

## 参考資料

- [MaxMind GeoIP2](https://dev.maxmind.com/geoip/geoip2/downloadable/)
- [ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module)
- [Nginx GeoIP Module](https://nginx.org/en/docs/http/ngx_http_geoip_module.html)
- [OpenAppSec Documentation](https://docs.openappsec.io/)
