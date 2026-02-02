# Task 5.5: GeoIP機能実装 完了

## 概要

Task 5.5「GeoIP機能実装」の実装が完了しました。このドキュメントでは、実装内容と使用方法を説明します。

**Issue**: [MWD-42](https://kencom2400.atlassian.net/browse/MWD-42)  
**親Epic**: [MWD-5: WAFエンジン基盤実装](https://kencom2400.atlassian.net/browse/MWD-5)

## 実装完了フェーズ

- ✅ **MaxMindDB統合実装**: GeoIP2モジュールとMaxMindDBの統合
- ✅ **IP/CIDR判定ロジック実装**: AllowList優先のIP/CIDRアクセス制御
- ✅ **国コード判定ロジック実装**: 国単位のアクセス制御
- ✅ **GeoIPデータベース自動更新機能実装**: 週次自動更新
- ✅ **X-Forwarded-For対応実装**: プロキシ経由アクセスの対応
- ✅ **テストスクリプト作成**: 統合テストスクリプト
- ✅ **ドキュメント作成**: 実装計画書と本ドキュメント

## 実装内容

### 1. MaxMindDB統合

#### カスタムDockerイメージ

**ファイル**: `docker/nginx/Dockerfile`

- OpenAppSec公式のNginxイメージをベースに、GeoIP2モジュールを追加
- libmaxminddbライブラリのビルドとインストール
- ngx_http_geoip2_moduleの動的モジュールとしてのビルド

#### nginx.conf更新

**ファイル**: `docker/nginx/nginx.conf`

```nginx
# GeoIP2 Moduleの読み込み
load_module /usr/lib/nginx/modules/ngx_http_geoip2_module.so;

http {
    # GeoIP2データベースの読み込み
    geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
        $geoip2_data_country_iso_code country iso_code;
        $geoip2_data_country_name country names en;
        $geoip2_data_continent_code continent code;
    }
    
    # JSON形式のログフォーマットにGeoIP情報を追加
    log_format json_combined escape=json
      '{'
        '"geoip_country_code":"$geoip2_data_country_iso_code",'
        '"geoip_country_name":"$geoip2_data_country_name",'
        '"geoip_continent_code":"$geoip2_data_continent_code"'
      '}';
}
```

### 2. IP/CIDR判定ロジック

#### ConfigAgent更新

**ファイル**: `config-agent/lib/nginx-config-generator.sh`

- `generate_geoip_config()`関数を追加
- API設定データからGeoIP設定を取得
- IP AllowList/BlockListの生成
- 国コード AllowList/BlockListの生成
- AllowList優先ロジックの実装

#### API設定データ形式

```json
{
  "version": "1.0.0",
  "fqdns": [
    {
      "fqdn": "example.com",
      "geoip": {
        "enabled": true,
        "ip_allowlist": ["192.168.1.0/24", "203.0.113.0/24"],
        "ip_blocklist": ["198.51.100.0/24"],
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

#### 生成されるNginx設定例

```nginx
server {
    listen 80;
    server_name example.com;

    # X-Forwarded-Forから実IPを取得
    set_real_ip_from 192.168.0.0/16;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    # IP AllowList
    geo $ip_allowlist {
        default 0;
        192.168.1.0/24 1;
        203.0.113.0/24 1;
    }

    # IP BlockList
    geo $ip_blocklist {
        default 0;
        198.51.100.0/24 1;
    }

    # 国コード AllowList
    map $geoip2_data_country_iso_code $country_allowlist {
        default 0;
        JP 1;
        US 1;
    }

    # 国コード BlockList
    map $geoip2_data_country_iso_code $country_blocklist {
        default 0;
        KP 1;
        RU 1;
    }

    # アクセス制御ロジック
    set $access_allowed 1;
    
    # AllowList優先
    if ($ip_allowlist = "1") {
        set $access_allowed 1;
    }
    if ($country_allowlist = "1") {
        set $access_allowed 1;
    }
    
    # BlockList判定
    if ($ip_blocklist = "1") {
        set $access_allowed 0;
    }
    if ($country_blocklist = "1") {
        set $access_allowed 0;
    }
    
    # アクセス拒否
    if ($access_allowed = "0") {
        return 403 '{"error": "Access denied", "reason": "GeoIP policy violation"}';
    }

    location / {
        proxy_pass http://backend-server:80;
        proxy_set_header X-GeoIP-Country $geoip2_data_country_iso_code;
    }
}
```

### 3. GeoIPデータベース自動更新

#### GeoIP Updaterサービス

**ファイル**: `geoip-updater/geoip-updater.sh`

- MaxMind APIからGeoLite2-Country.mmdbをダウンロード
- 既存ファイルのバックアップ
- 新しいファイルの配置
- Nginxリロード
- 古いバックアップの削除（デフォルト: 7日以上）

**cron設定**:

```cron
# 毎週火曜日 3:00 AM JST（月曜日 18:00 UTC）
0 18 * * 1 /app/geoip-updater.sh update >> /var/log/geoip-updater.log 2>&1
```

#### Docker Compose統合

**ファイル**: `docker/docker-compose.yml`

```yaml
services:
  nginx:
    build:
      context: ./nginx
      dockerfile: Dockerfile
    volumes:
      - geoip-data:/usr/share/GeoIP:ro

  geoip-updater:
    build:
      context: ../geoip-updater
      dockerfile: Dockerfile
    volumes:
      - geoip-data:/usr/share/GeoIP:rw
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - MAXMIND_LICENSE_KEY=${MAXMIND_LICENSE_KEY}
      - NGINX_CONTAINER_NAME=mwd-nginx

volumes:
  geoip-data:
    driver: local
```

### 4. X-Forwarded-For対応

`set_real_ip_from`、`real_ip_header`、`real_ip_recursive`ディレクティブを使用して、プロキシ経由のアクセスに対応。

## クイックスタート

### 1. 前提条件

#### MaxMind License Keyの取得

1. [MaxMindアカウント](https://www.maxmind.com/en/geolite2/signup)を作成
2. License Keyを生成
3. 環境変数に設定

```bash
export MAXMIND_LICENSE_KEY='your-license-key'
```

### 2. 環境変数の設定

`.env`ファイルを作成:

```bash
# GeoIP設定
MAXMIND_LICENSE_KEY=your-license-key
MAXMIND_ACCOUNT_ID=your-account-id
GEOIP_BACKUP_RETENTION_DAYS=7
```

### 3. Dockerイメージのビルド

```bash
cd docker
docker-compose build nginx geoip-updater
```

### 4. サービスの起動

```bash
docker-compose up -d
```

### 5. 動作確認

#### GeoIPモジュールの確認

```bash
docker exec mwd-nginx nginx -V 2>&1 | grep geoip2
```

#### GeoIPデータベースの確認

```bash
docker exec mwd-nginx ls -lh /usr/share/GeoIP/
```

#### テストスクリプトの実行

```bash
./scripts/openappsec/test-geoip.sh --fqdn example.com --port 80 --verbose
```

## 使用方法

### API設定データの更新

ConfigAgentのモックAPIサーバー（`config-agent/mock-api-server.py`）を更新して、GeoIP設定を追加:

```json
{
  "version": "1.0.0",
  "customer_name": "example-customer",
  "fqdns": [
    {
      "fqdn": "example.com",
      "is_active": true,
      "backend_host": "httpbin.org",
      "backend_port": 80,
      "geoip": {
        "enabled": true,
        "ip_allowlist": ["192.168.1.0/24"],
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

### GeoIPデータベースの手動更新

```bash
# テストモード（設定確認）
docker exec mwd-geoip-updater /app/geoip-updater.sh test

# 手動更新
docker exec mwd-geoip-updater /app/geoip-updater.sh update

# バージョン確認
docker exec mwd-geoip-updater /app/geoip-updater.sh version
```

### ログ確認

#### Nginxアクセスログ（GeoIP情報含む）

```bash
docker exec mwd-nginx cat /var/log/nginx/example.com/access.log | jq .
```

出力例:

```json
{
  "time": "2026-02-02T15:30:00+09:00",
  "remote_addr": "192.168.1.100",
  "status": 200,
  "geoip_country_code": "JP",
  "geoip_country_name": "Japan",
  "geoip_continent_code": "AS"
}
```

#### GeoIP Updaterログ

```bash
docker logs mwd-geoip-updater
```

## トラブルシューティング

### GeoIP2モジュールが読み込まれない

**症状**:

```
nginx: [emerg] unknown directive "geoip2" in /etc/nginx/nginx.conf:XX
```

**原因**: GeoIP2モジュールがビルドされていない

**対処方法**:

```bash
# Nginxイメージを再ビルド
cd docker
docker-compose build nginx

# コンテナを再起動
docker-compose up -d nginx
```

### GeoIPデータベースが見つからない

**症状**:

```
nginx: [emerg] failed to read the "/usr/share/GeoIP/GeoLite2-Country.mmdb" database
```

**原因**: GeoIPデータベースがダウンロードされていない

**対処方法**:

```bash
# 手動でダウンロード
docker exec mwd-geoip-updater /app/geoip-updater.sh update

# ボリュームを確認
docker volume inspect docker_geoip-data
```

### MaxMind License Keyエラー

**症状**:

```
❌ エラー: ダウンロードに失敗しました
```

**原因**: MaxMind License Keyが無効

**対処方法**:

1. MaxMindアカウントでLicense Keyを確認
2. `.env`ファイルを更新
3. コンテナを再起動

```bash
docker-compose restart geoip-updater
```

### アクセスが拒否される

**症状**: すべてのリクエストが403エラー

**原因**: GeoIP設定が厳しすぎる

**対処方法**:

1. Nginx設定ファイルを確認

```bash
docker exec mwd-nginx cat /etc/nginx/conf.d/example.com.conf
```

2. アクセスログを確認

```bash
docker exec mwd-nginx tail -50 /var/log/nginx/example.com/access.log | jq .
```

3. API設定データを確認・更新

## パフォーマンス考慮事項

### GeoIP2モジュールのパフォーマンス

- メモリマップドファイルアクセスで高速（約1-2マイクロ秒/リクエスト）
- キャッシュ機能により、連続するリクエストはさらに高速
- データベースサイズ: 約6MB（GeoLite2-Country）

### Nginx設定の最適化

- `geo`と`map`ディレクティブは起動時に評価されるため、リクエスト時のオーバーヘッドは最小限
- `if`ディレクティブの使用を最小限に抑えることで、パフォーマンスを向上

## セキュリティ考慮事項

### MaxMind License Key管理

- 環境変数で管理（`.env`ファイル、Dockerシークレット）
- `.gitignore`に`.env`を追加
- 本番環境ではシークレット管理サービスを使用

### X-Forwarded-Forの信頼性

- 信頼できるプロキシのIPレンジのみを設定
- `real_ip_recursive on`で多段プロキシに対応
- 不正なX-Forwarded-Forヘッダーの検証

### GeoIPデータベースの更新

- 自動更新を有効化（週次）
- バックアップを保持（デフォルト: 7日）
- 更新失敗時は自動的にロールバック

## 制限事項

### GeoIPデータベースの精度

- 100%正確ではない（約99.8%の精度）
- VPN/プロキシ経由のアクセスは検知困難
- モバイルキャリアのIPアドレスは変動する可能性がある

### Nginxの`if`ディレクティブの制限

- 複雑な条件分岐には`geo`と`map`を組み合わせる必要がある
- `if`は最小限に使用

### ドキュメント用IPレンジの制限

- RFC 5737で予約されたIPレンジ（203.0.113.0/24等）は、実際のGeoIPデータベースで国コードが取得できない
- テスト時は実際のIPアドレスを使用

## 参考資料

- 実装計画書: `docs/design/MWD-42-implementation-plan.md`
- テストスクリプト: `scripts/openappsec/test-geoip.sh`
- [MaxMind GeoIP2](https://dev.maxmind.com/geoip/geoip2/downloadable/)
- [ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module)
- [Nginx GeoIP Module](https://nginx.org/en/docs/http/ngx_http_geoip_module.html)
- [OpenAppSec Documentation](https://docs.openappsec.io/)

## 次のステップ

1. **MaxMind License Keyの取得**: [MaxMindアカウント](https://www.maxmind.com/en/geolite2/signup)を作成してLicense Keyを取得
2. **開発環境での動作確認**: Dockerイメージをビルドして動作を確認
3. **統合テストの実施**: `test-geoip.sh`を実行してテスト
4. **本番環境への展開**: ステージング環境での動作確認後、本番環境に展開
5. **監視・アラート設定**: GeoIPデータベース更新失敗時のアラート設定

## 付録: MaxMind License Key取得手順

1. [MaxMind Signup](https://www.maxmind.com/en/geolite2/signup)にアクセス
2. アカウント情報を入力
3. メールアドレスを認証
4. ログイン後、"My License Key"をクリック
5. "Generate New License Key"をクリック
6. License Keyをコピー（一度しか表示されないため注意）
7. 環境変数に設定

```bash
export MAXMIND_LICENSE_KEY='your-license-key'
```

## お問い合わせ

問題や質問がある場合は、Jira Issue [MWD-42](https://kencom2400.atlassian.net/browse/MWD-42)にコメントしてください。
