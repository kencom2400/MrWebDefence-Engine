# Task 5.3: ログ転送機能実装 実装設計書

## 概要

WAFエンジンのログをログ管理サーバに転送する機能を実装します。Fluentdを使用して、NginxアクセスログとOpenAppSec WAF検知ログをJSON形式で転送します。

## 参照設計書

- **要件定義**: `MrWebDefence-Design/docs/REQUIREMENT.md`
- **仕様書**: `MrWebDefence-Design/docs/SPECIFICATION.md`
- **詳細設計**: `MrWebDefence-Design/docs/DESIGN.md`
- **OpenAppSec統合設計**: `docs/design/MWD-38-openappsec-integration.md`
- **タスクレビュー**: `docs/design/MWD-38-task-review.md`

## 目的

- Fluentdを使用したログ転送機能の実装
- NginxアクセスログのJSON形式出力と転送
- OpenAppSec WAF検知ログの転送
- ログ管理サーバへの統合

## アーキテクチャ概要

### システム構成

```
┌─────────────────────────────────────────────────────────┐
│              Nginx Container                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Access Log (JSON形式)                            │  │
│  │  - /var/log/nginx/access.log                      │  │
│  │  - /var/log/nginx/{fqdn}.access.log               │  │
│  │  Error Log                                         │  │
│  │  - /var/log/nginx/error.log                       │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ ログファイル（共有ボリューム）
                       ▼
┌─────────────────────────────────────────────────────────┐
│              OpenAppSec Agent Container                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  WAF Detection Log                                 │  │
│  │  - /var/log/nano_agent/*.log                      │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ ログファイル（共有ボリューム）
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Fluentd Container                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │  - Nginxアクセスログの収集                        │  │
│  │  - OpenAppSec WAF検知ログの収集                   │  │
│  │  - JSON形式への変換                               │  │
│  │  - ログ管理サーバへの転送                          │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ HTTP/HTTPS (JSON)
                       ▼
┌─────────────────────────────────────────────────────────┐
│              ログ管理サーバ                             │
│  - Elasticsearch / Splunk / CloudWatch / etc.          │
└─────────────────────────────────────────────────────────┘
```

### コンポーネント

1. **Fluentd**
   - ログ収集・転送エージェント
   - Nginxアクセスログの収集
   - OpenAppSec WAF検知ログの収集
   - JSON形式への変換
   - ログ管理サーバへの転送

2. **Nginx**
   - JSON形式のアクセスログ出力
   - FQDN別のログファイル出力

3. **OpenAppSec Agent**
   - WAF検知ログの出力
   - JSON形式でのログ出力（設定可能）

## 実装フェーズ

### Phase 1: Fluentd設定の実装

#### Phase 1.1: Docker ComposeへのFluentd追加

**ファイル**: `docker/docker-compose.yml`

**実装内容**:
- Fluentdサービスの追加
- ログボリュームのマウント設定
- 環境変数の設定
- ネットワーク設定

**設定項目**:
- Fluentdイメージ: `fluent/fluentd:v1.16-debian-1`
- ログボリューム: Nginxログ、OpenAppSecログ
- 設定ファイル: `docker/fluentd/fluent.conf`
- 出力先: 環境変数で指定（デフォルト: stdout）

#### Phase 1.2: Fluentd設定ファイルの作成

**ファイル**: `docker/fluentd/fluent.conf`

**実装内容**:
- Nginxアクセスログの収集設定
- OpenAppSec WAF検知ログの収集設定
- JSON形式への変換設定
- 出力先設定（HTTP/HTTPS、ファイル、stdout）

**設定項目**:
- 入力ソース: `tail`プラグイン（Nginx、OpenAppSecログ）
- パース設定: JSON形式のログをそのまま転送
- 出力先: `http`プラグインまたは`forward`プラグイン
- タグ設定: `nginx.access`, `nginx.error`, `openappsec.detection`

### Phase 2: NginxアクセスログのJSON形式出力

#### Phase 2.1: JSON形式のログフォーマット定義

**ファイル**: `docker/nginx/nginx.conf`

**実装内容**:
- JSON形式のログフォーマット定義
- アクセスログのJSON形式出力設定

**ログフォーマット例**:
```nginx
log_format json_combined escape=json
  '{'
    '"time":"$time_iso8601",'
    '"remote_addr":"$remote_addr",'
    '"remote_user":"$remote_user",'
    '"request":"$request",'
    '"status":$status,'
    '"body_bytes_sent":$body_bytes_sent,'
    '"http_referer":"$http_referer",'
    '"http_user_agent":"$http_user_agent",'
    '"http_x_forwarded_for":"$http_x_forwarded_for",'
    '"request_time":$request_time,'
    '"upstream_response_time":"$upstream_response_time",'
    '"host":"$host"'
  '}';
```

#### Phase 2.2: FQDN別ログファイルのJSON形式出力

**ファイル**: `docker/nginx/conf.d/*.conf`（自動生成）

**実装内容**:
- 各FQDN設定ファイルでJSON形式のログフォーマットを使用
- FQDN別のログファイルにJSON形式で出力

**設定例**:
```nginx
access_log /var/log/nginx/example1.com.access.log json_combined;
```

### Phase 3: OpenAppSec WAF検知ログの転送設定

#### Phase 3.1: OpenAppSecログ設定の確認

**ファイル**: `docker/openappsec/local_policy.yaml`（自動生成）

**実装内容**:
- OpenAppSecのログ出力設定を確認
- JSON形式でのログ出力設定（`logDestination.stdout.format: json`）
- ログトリガーの設定確認

**設定項目**:
- `logDestination.stdout.format: json`
- `logDestination.logToAgent: true`
- ログファイルパス: `/var/log/nano_agent/*.log`

#### Phase 3.2: FluentdでのOpenAppSecログ収集設定

**ファイル**: `docker/fluentd/fluent.conf`

**実装内容**:
- OpenAppSecログファイルの監視設定
- JSON形式のログパース設定
- タグ付け設定（`openappsec.detection`）

### Phase 4: ログ転送先の設定

#### Phase 4.1: 環境変数による設定

**ファイル**: `docker/docker-compose.yml`

**実装内容**:
- ログ転送先URLの環境変数設定
- 認証情報の環境変数設定（必要に応じて）
- 転送プロトコルの選択（HTTP/HTTPS/Forward）

**環境変数**:
- `FLUENTD_OUTPUT_URL`: ログ転送先URL（デフォルト: stdout）
- `FLUENTD_OUTPUT_METHOD`: 転送方法（http, forward, stdout）
- `FLUENTD_OUTPUT_AUTH`: 認証情報（必要に応じて）

#### Phase 4.2: Fluentd出力プラグインの設定

**ファイル**: `docker/fluentd/fluent.conf`

**実装内容**:
- HTTP出力プラグインの設定
- Forward出力プラグインの設定（オプション）
- エラーハンドリング設定
- リトライ設定

### Phase 5: ログローテーション設定（オプション）

#### Phase 5.1: logrotate設定ファイルの作成

**ファイル**: `docker/fluentd/logrotate.conf`

**実装内容**:
- Nginxアクセスログのローテーション設定
- Nginxエラーログのローテーション設定
- OpenAppSecログのローテーション設定
- FQDN別ログのローテーション設定

## 実装詳細

### 1. Docker Compose設定

#### docker/docker-compose.yml

```yaml
services:
  fluentd:
    image: fluent/fluentd:v1.16-debian-1
    container_name: mwd-fluentd
    volumes:
      # Fluentd設定ファイル
      - ./fluentd/fluent.conf:/fluentd/etc/fluent.conf:ro
      # Nginxログ
      - ./nginx/logs:/var/log/nginx:ro
      # OpenAppSecログ
      - ./openappsec/logs:/var/log/nano_agent:ro
    environment:
      - FLUENTD_OUTPUT_URL=${FLUENTD_OUTPUT_URL:-stdout}
      - FLUENTD_OUTPUT_METHOD=${FLUENTD_OUTPUT_METHOD:-stdout}
      - FLUENTD_OUTPUT_AUTH=${FLUENTD_OUTPUT_AUTH:-}
    networks:
      - mwd-network
    depends_on:
      - nginx
      - openappsec-agent
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 2. Fluentd設定ファイル

#### docker/fluentd/fluent.conf

```xml
<source>
  @type tail
  @id nginx_access
  path /var/log/nginx/*.access.log
  pos_file /var/log/fluentd/nginx.access.pos
  tag nginx.access
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S%z
  </parse>
</source>

<source>
  @type tail
  @id nginx_error
  path /var/log/nginx/error.log
  pos_file /var/log/fluentd/nginx.error.pos
  tag nginx.error
  <parse>
    @type nginx
  </parse>
</source>

<source>
  @type tail
  @id openappsec_detection
  path /var/log/nano_agent/*.log
  pos_file /var/log/fluentd/openappsec.detection.pos
  tag openappsec.detection
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S%z
  </parse>
</source>

<filter nginx.**>
  @type record_transformer
  <record>
    log_type "nginx"
    source "waf-engine"
  </record>
</filter>

<filter openappsec.**>
  @type record_transformer
  <record>
    log_type "openappsec"
    source "waf-engine"
  </record>
</filter>

<match nginx.**>
  @type http
  endpoint "#{ENV['FLUENTD_OUTPUT_URL']}"
  http_method post
  <buffer>
    @type file
    path /var/log/fluentd/buffer
    flush_interval 5s
    retry_type exponential_backoff
    retry_wait 1s
    retry_max_interval 60s
    retry_timeout 60m
  </buffer>
</match>

<match openappsec.**>
  @type http
  endpoint "#{ENV['FLUENTD_OUTPUT_URL']}"
  http_method post
  <buffer>
    @type file
    path /var/log/fluentd/buffer
    flush_interval 5s
    retry_type exponential_backoff
    retry_wait 1s
    retry_max_interval 60s
    retry_timeout 60m
  </buffer>
</match>

# デフォルト出力（stdout、開発・デバッグ用）
<match **>
  @type stdout
</match>
```

### 3. Nginx JSON形式ログフォーマット

#### docker/nginx/nginx.conf

```nginx
# JSON形式のログフォーマット
log_format json_combined escape=json
  '{'
    '"time":"$time_iso8601",'
    '"remote_addr":"$remote_addr",'
    '"remote_user":"$remote_user",'
    '"request":"$request",'
    '"status":$status,'
    '"body_bytes_sent":$body_bytes_sent,'
    '"http_referer":"$http_referer",'
    '"http_user_agent":"$http_user_agent",'
    '"http_x_forwarded_for":"$http_x_forwarded_for",'
    '"request_time":$request_time,'
    '"upstream_response_time":"$upstream_response_time",'
    '"host":"$host"'
  '}';

# 従来のログフォーマット（互換性のため保持）
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

# デフォルトのアクセスログ（JSON形式）
access_log /var/log/nginx/access.log json_combined;
```

### 4. Nginx設定生成スクリプトの更新

#### config-agent/lib/nginx-config-generator.sh

**変更内容**:
- JSON形式のログフォーマットを使用するように更新
- FQDN別ログファイルにJSON形式で出力するように更新

**変更例**:
```bash
# JSON形式のログフォーマットを使用
access_log /var/log/nginx/${fqdn}.access.log json_combined;
```

## 受け入れ条件

- [ ] Fluentdコンテナが正常に起動する
- [ ] NginxアクセスログがJSON形式で出力される
- [ ] FluentdがNginxアクセスログを正常に収集できる
- [ ] OpenAppSec WAF検知ログが正常に収集できる
- [ ] ログがログ管理サーバに正常に転送される（設定した場合）
- [ ] ログのタグ付けが正しく行われる
- [ ] エラーハンドリングとリトライが正常に動作する
- [ ] ログローテーションが正常に動作する（実装した場合）

## 依存関係

- Task 5.0: Docker Compose構成実装（完了）
- Task 5.1: OpenAppSec統合（完了）
- Task 5.2: 設定取得・動的更新機能実装（完了）

## テスト項目

### 1. Fluentd起動テスト

- Fluentdコンテナが正常に起動することを確認
- 設定ファイルが正しく読み込まれることを確認

### 2. ログ収集テスト

- NginxアクセスログがFluentdに収集されることを確認
- OpenAppSec WAF検知ログがFluentdに収集されることを確認
- JSON形式のログが正しくパースされることを確認

### 3. ログ転送テスト

- ログがログ管理サーバに正常に転送されることを確認（設定した場合）
- エラー時のリトライが正常に動作することを確認

### 4. パフォーマンステスト

- 大量のログが発生した場合のパフォーマンスを確認
- バッファリングが正常に動作することを確認

## 注意事項

1. **ログファイルのパス**: NginxとOpenAppSecのログファイルパスが正しくマウントされていることを確認
2. **権限設定**: Fluentdがログファイルを読み取れる権限があることを確認
3. **ログローテーション**: ログファイルがローテートされた場合のFluentdの動作を確認
4. **セキュリティ**: ログ転送時の認証情報の取り扱いに注意
5. **パフォーマンス**: 大量のログが発生した場合のパフォーマンス影響を考慮

## 参考資料

- [Fluentd公式ドキュメント](https://docs.fluentd.org/)
- [Nginxログフォーマット](https://nginx.org/en/docs/http/ngx_http_log_module.html)
- [OpenAppSecログ設定](https://docs.openappsec.io/)
