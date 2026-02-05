# Task 5.8: SSL/TLS証明書管理機能

## 概要

本タスクでは、Let's Encryptを使用したSSL/TLS証明書の自動取得・更新・管理機能を実装しました。

**関連ドキュメント**:
- 設計書: `docs/design/MWD-104-ssl-tls-architecture.md`
- 実装計画: `docs/design/MWD-104-implementation-plan.md`

**Jiraチケット**: MWD-104

## 実装内容

### 1. Certbot Manager Dockerサービス

SSL/TLS証明書の取得・更新を管理するDockerサービスを実装しました。

#### ファイル構成

```
certbot-manager/
├── Dockerfile              # Certbotベースのコンテナイメージ
├── certbot-manager.sh      # 証明書管理スクリプト
└── crontab                 # 自動更新スケジュール
```

#### 主要機能

1. **初回証明書取得** (`init`コマンド)
   - Let's Encryptから証明書を取得
   - ドメイン検証（ACME Challenge）
   - 証明書の保存

2. **証明書自動更新** (`renew`コマンド)
   - 毎日18:00 UTC（3:00 AM JST）に実行
   - ランダム待機時間（0〜60分）で負荷分散
   - 更新成功時にNginxを自動リロード

3. **テストモード** (`test`コマンド)
   - ステージング環境で証明書取得テスト
   - 本番環境への影響なし

#### 環境変数

| 変数名 | 説明 | 必須 | デフォルト値 |
|--------|------|------|-------------|
| `EMAIL` | Let's Encrypt登録用メールアドレス | ✅ | - |
| `DOMAINS` | 証明書取得対象ドメイン（カンマ区切り） | ✅ | - |
| `STAGING` | ステージング環境フラグ | ❌ | `false` |
| `NGINX_CONTAINER_NAME` | Nginxコンテナ名 | ❌ | `mwd-nginx` |

#### 使用例

```bash
# 初回証明書取得
docker-compose exec certbot-manager /app/certbot-manager.sh init

# 証明書更新（手動実行）
docker-compose exec certbot-manager /app/certbot-manager.sh renew

# テストモード（ステージング環境）
docker-compose exec certbot-manager /app/certbot-manager.sh test

# バージョン確認
docker-compose exec certbot-manager /app/certbot-manager.sh version
```

### 2. ConfigAgentのSSL設定生成機能

ConfigAgentを拡張し、SSL/TLS証明書が存在する場合にHTTPS設定を自動生成する機能を追加しました。

#### 追加関数

1. **`generate_ssl_config()`**
   - HTTPS設定ファイルを生成
   - SSL証明書パスの設定
   - TLS 1.2/1.3の設定
   - セキュリティヘッダーの追加

2. **`generate_http_redirect_config()`**
   - HTTP→HTTPSリダイレクト設定を生成
   - ACME Challenge用の例外設定

3. **`generate_fqdn_ssl_config()`**
   - 証明書の存在確認
   - SSL設定とHTTPリダイレクト設定を生成

#### 動作

- 証明書が存在する場合：HTTPS設定 + HTTPリダイレクト設定を生成
- 証明書が存在しない場合：HTTP設定のみを生成（警告メッセージ出力）

### 3. docker-compose.yml更新

#### certbot-managerサービスの追加

```yaml
certbot-manager:
  container_name: mwd-certbot-manager
  build:
    context: ../certbot-manager
    dockerfile: Dockerfile
  volumes:
    - certbot-data:/etc/letsencrypt:rw
    - certbot-webroot:/var/www/certbot:rw
    - /var/run/docker.sock:/var/run/docker.sock:ro
  environment:
    - EMAIL=${CERTBOT_EMAIL}
    - NGINX_CONTAINER_NAME=mwd-nginx
    - DOMAINS=${CERTBOT_DOMAINS}
    - STAGING=${CERTBOT_STAGING:-false}
```

#### ボリュームの追加

```yaml
volumes:
  certbot-data:      # 証明書データ
    driver: local
  certbot-webroot:   # ACME Challenge用
    driver: local
```

#### Nginxサービスの更新

```yaml
nginx:
  volumes:
    - certbot-webroot:/var/www/certbot:ro  # ACME Challenge用
    - certbot-data:/etc/letsencrypt:ro     # SSL証明書
  ports:
    - "80:80"
    - "443:443"  # HTTPS用ポート追加
```

### 4. nginx.confのSSL/TLS設定

#### 追加設定

```nginx
# SSL/TLSセッション設定
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# SSL/TLSプロトコル
ssl_protocols TLSv1.2 TLSv1.3;

# SSL暗号スイート（Mozillaの推奨設定）
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...';
ssl_prefer_server_ciphers off;

# SSLセッションチケット
ssl_session_tickets on;
```

#### セキュリティ強化

- TLS 1.2以上を使用（TLS 1.0/1.1は非対応）
- 前方秘匿性を提供する暗号スイート（ECDHE）
- 認証付き暗号化モード（GCM）
- モバイルデバイス向けの高速暗号（CHACHA20-POLY1305）

## テスト

### 統合テストスクリプト

**ファイル**: `scripts/openappsec/test-ssl-tls.sh`

#### テストケース（14項目）

1. サービス状態確認（Nginx、OpenAppSec Agent、Config Agent）
2. Docker Compose設定確認
3. Nginx設定確認（構文チェック、SSL設定）
4. Certbot Manager動作確認
5. 証明書取得テスト（ステージング環境）
6. 証明書存在確認
7. ACME Challenge設定確認
8. HTTP→HTTPSリダイレクト確認
9. HTTPS接続確認
10. 証明書有効性確認
11. セキュリティヘッダー確認
12. SSL/TLSプロトコル・暗号確認
13. ログ確認

#### 実行方法

```bash
# 基本実行（デフォルトFQDN: test.example.com）
./scripts/openappsec/test-ssl-tls.sh

# FQDN指定
./scripts/openappsec/test-ssl-tls.sh --fqdn example.com

# 証明書テストをスキップ（設計検証のみ）
./scripts/openappsec/test-ssl-tls.sh --skip-cert-test

# コンテナを再起動しない（CI環境、既に起動済みの場合）
./scripts/openappsec/test-ssl-tls.sh --no-restart
```

### CI/CD統合

#### GitHub Actions

ワークフロー: `.github/workflows/test-log-forwarding.yml`

**追加対応**:
- GeoIP設定ファイルの削除ステップ（ConfigAgent問題の暫定対策）

#### 環境変数

`.env`ファイルに以下を設定：

```bash
# Certbot設定
CERTBOT_EMAIL=your-email@example.com
CERTBOT_DOMAINS=example.com,www.example.com
CERTBOT_STAGING=true  # 本番環境ではfalseに設定
```

## デプロイ手順

### 初回デプロイ

```bash
# 1. 環境変数を設定
cp .env.example .env
# .envを編集（CERTBOT_EMAIL、CERTBOT_DOMAINSを設定）

# 2. サービスを起動
cd docker
docker-compose up -d

# 3. サービス起動確認
docker-compose ps

# 4. 初回証明書取得
docker-compose exec certbot-manager /app/certbot-manager.sh init

# 5. 証明書取得確認
docker-compose exec certbot-manager ls -la /etc/letsencrypt/live/

# 6. Nginx設定リロード（ConfigAgentが自動生成）
# ConfigAgentが証明書を検出し、HTTPS設定を生成します
# 約5分待機後、Nginx設定を確認

# 7. HTTPS接続確認
curl -I -k https://example.com/
```

### 証明書更新

証明書は**毎日18:00 UTC（3:00 AM JST）**に自動更新されます。

手動で更新する場合：

```bash
docker-compose exec certbot-manager /app/certbot-manager.sh renew
```

### ログ確認

```bash
# Certbot Managerのログ
docker logs mwd-certbot-manager

# Nginxのログ
docker logs mwd-nginx

# ConfigAgentのログ
docker logs mwd-config-agent
```

## トラブルシューティング

### 証明書取得に失敗する

#### 原因1: DNS設定が正しくない

```bash
# DNS確認
dig example.com +short

# 解決策
# DNSレコードを正しく設定してください（A/AAAAレコード）
```

#### 原因2: ACME Challenge用ディレクトリにアクセスできない

```bash
# ACME Challengeテスト
curl http://example.com/.well-known/acme-challenge/test

# 解決策
# Nginx設定を確認してください
```

#### 原因3: ポート80がファイアウォールでブロックされている

```bash
# 解決策
# ファイアウォールでポート80を開放してください
```

### Nginxが起動しない

#### 原因1: 証明書ファイルが見つからない

```bash
# 証明書確認
docker-compose exec nginx ls -la /etc/letsencrypt/live/

# 解決策
# 初回証明書取得を実行してください
docker-compose exec certbot-manager /app/certbot-manager.sh init
```

#### 原因2: Nginx設定エラー

```bash
# 設定チェック
docker-compose exec nginx nginx -t

# 解決策
# エラーメッセージに従って設定を修正してください
```

### ConfigAgentの問題

#### GeoIP設定が生成される（MWD-111で対応予定）

**問題**: ConfigAgentが`geoip.enabled: false`でもGeoIP設定を生成

**暫定対策**:
```bash
# GeoIP設定ファイルを削除
rm -f docker/nginx/geoip/*.conf

# Nginxリロード
docker-compose exec nginx nginx -s reload
```

**根本対策**: MWD-111（ConfigAgent条件分岐追加）完了後に解消されます

## セキュリティ上の注意

### 1. Let's Encrypt Rate Limits

- **証明書発行**: 20件/週（同一ドメイン）
- **重複証明書**: 5件/週
- **テスト**: ステージング環境を使用（`STAGING=true`）

### 2. Dockerソケットのマウント

```yaml
# 読み取り専用で十分（docker execが可能）
- /var/run/docker.sock:/var/run/docker.sock:ro
```

### 3. 証明書の保護

- 証明書データは`certbot-data`ボリュームに保存
- Nginxは読み取り専用でマウント
- バックアップを定期的に取得

### 4. TLS設定

- TLS 1.2以上を使用
- 前方秘匿性を提供する暗号スイート
- セキュリティヘッダーの追加（HSTS、X-Frame-Options等）

## パフォーマンス最適化

### SSLセッションキャッシュ

```nginx
ssl_session_cache shared:SSL:10m;  # 10MB = 約40,000セッション
ssl_session_timeout 10m;
```

### HTTP/2サポート

```nginx
listen 443 ssl http2;
```

## 監視とメンテナンス

### 証明書有効期限の確認

```bash
# 証明書情報の確認
docker-compose exec certbot-manager certbot certificates

# 有効期限の確認
openssl s_client -connect example.com:443 -servername example.com < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

### 自動更新の確認

```bash
# Certbot Managerのcronログ
docker logs mwd-certbot-manager

# 最近の更新履歴
docker-compose exec certbot-manager ls -lt /etc/letsencrypt/live/
```

## 関連チケット

- **MWD-104**: SSL/TLS証明書管理機能（本タスク）
- **MWD-111**: ConfigAgent条件分岐追加（中期対策、GeoIP問題）
- **MWD-112**: GeoIP機能再実装（長期対策）

## 完了基準

- [x] Certbot Manager Dockerサービスの作成
- [x] ConfigAgentのSSL設定生成ロジック実装
- [x] docker-compose.ymlの更新
- [x] nginx.confのSSL/TLS設定追加
- [x] 統合テストスクリプトの作成
- [x] ドキュメント作成
- [ ] 統合テストの実行とCI通過確認

## 次のステップ

### Phase 2: 高度な機能（将来実装）

1. **証明書のバックアップ・リストア**
   - 定期的なバックアップ
   - ディザスタリカバリ手順

2. **証明書の監視とアラート**
   - 有効期限の監視
   - 更新失敗時のアラート
   - Prometheus/Grafanaとの連携

3. **ワイルドカード証明書**
   - DNS-01チャレンジの実装
   - DNS API連携

4. **証明書のローテーション**
   - 複数証明書の管理
   - ブルーグリーンデプロイメント

## 参考資料

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [OWASP Transport Layer Protection Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)
