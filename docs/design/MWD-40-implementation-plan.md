# Task 5.3: ログ転送機能実装 実装設計書

## 概要

WAFエンジンのログをログ管理サーバに転送する機能を実装します。Fluentdを使用して、NginxアクセスログとOpenAppSec WAF検知ログをJSON形式で転送します。

## ログ連携方式の選択

本実装では、以下のログ連携方式を選択可能にします：

- **共有ボリューム方式（デフォルト）**: ログファイルを共有ボリュームに出力し、Fluentdが`tail`プラグインで収集
- **ログドライバ方式（オプション）**: Docker Logging Driverを使用して標準出力からログを収集
- **ハイブリッド方式（特殊用途）**: 両方式を併用

詳細な比較検討は `docs/design/MWD-40-log-integration-analysis.md` を参照してください。

**推奨**: 共有ボリューム方式（デフォルト）
- FQDN別ログの個別処理が容易
- logrotateとの連携が容易
- ログファイルへの直接アクセスが可能

## ログのFQDN別分割

### Nginxログ

Nginxログは、FQDN別のディレクトリに出力します：
- アクセスログ: `/var/log/nginx/{fqdn}/access.log`
- エラーログ: `/var/log/nginx/{fqdn}/error.log`

### OpenAppSecログ

OpenAppSecログは、OpenAppSecの設定では直接FQDN別に分けることはできませんが、Fluentd側でFQDN別に分離します：

1. **元のログ**: `/var/log/nano_agent/*.log`（すべてのFQDNのログが混在）
2. **FQDN別分離**: Fluentdの`rewrite_tag_filter`プラグインで、ログJSONからFQDN情報を抽出し、FQDN別にタグを付け直す
3. **FQDN別出力（オプション）**: Fluentdの`file`プラグインで、FQDN別のディレクトリに出力（`/var/log/nano_agent/{fqdn}/*.log`）

**FQDN情報の抽出方法**:
- OpenAppSecのログJSONから`host`, `hostname`, `requestHost`等のフィールドを抽出
- 抽出したFQDN情報を基にタグを付け直す（`openappsec.detection.{fqdn}`）

## 参照設計書

- **要件定義**: `MrWebDefence-Design/docs/REQUIREMENT.md`
- **仕様書**: `MrWebDefence-Design/docs/SPECIFICATION.md`
- **詳細設計**: `MrWebDefence-Design/docs/DESIGN.md`
- **OpenAppSec統合設計**: `docs/design/MWD-38-openappsec-integration.md`
- **タスクレビュー**: `docs/design/MWD-38-task-review.md`
- **ログ連携方法比較検討**: `docs/design/MWD-40-log-integration-analysis.md`

## 目的

- Fluentdを使用したログ転送機能の実装
- NginxアクセスログのJSON形式出力と転送
- OpenAppSec WAF検知ログの転送
- ログ管理サーバへの統合
- ログ連携方法の選択（共有ボリューム方式 / ログドライバ方式）
- ログローテーション設定（毎日ローテート、logrotate.d使用）

## アーキテクチャ概要

### システム構成

```
┌─────────────────────────────────────────────────────────┐
│              Nginx Container                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Access Log (JSON形式)                            │  │
│  │  - /var/log/nginx/access.log                      │  │
│  │  - /var/log/nginx/{fqdn}/access.log               │  │
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
│  │  (FQDN別にFluentdで分離)                           │  │
│  │  - /var/log/nano_agent/{fqdn}/*.log (オプション)  │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ ログファイル（共有ボリューム）
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Fluentd Container                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │  - Nginxアクセスログの収集                        │  │
│  │    (tail プラグイン or forward プラグイン)        │  │
│  │  - OpenAppSec WAF検知ログの収集                   │  │
│  │    (tail プラグイン or forward プラグイン)        │  │
│  │  - FQDN別のタグ付け・分離                         │  │
│  │  - メタデータの追加（ホスト名、顧客名、日時等）    │  │
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
   - FQDN別のログディレクトリ出力（`/var/log/nginx/{fqdn}/`）
   - ログローテーション設定（毎日ローテート、logrotate.d使用）

3. **OpenAppSec Agent**
   - WAF検知ログの出力
   - JSON形式でのログ出力（設定可能）
   - FQDN別のログ分離（Fluentd側で実装）

4. **ログ連携方式**
   - **デフォルト**: 共有ボリューム方式
   - **オプション**: ログドライバ方式（環境変数で選択可能）
   - **特殊用途**: ハイブリッド方式（両方式の併用）

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
- FQDN別のログディレクトリにJSON形式で出力
- ログパス: `/var/log/nginx/{fqdn}/access.log`, `/var/log/nginx/{fqdn}/error.log`

**設定例**:
```nginx
# FQDN別ディレクトリにログを出力
access_log /var/log/nginx/example1.com/access.log json_combined;
error_log /var/log/nginx/example1.com/error.log warn;
```

**理由**:
- logrotateやFluentd設定での識別がしやすい
- 1ディレクトリのファイル数が多くなりすぎることを防ぐ

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

**注意**: OpenAppSecのログファイル自体をFQDN別に分けることは、OpenAppSecの設定では直接できません。OpenAppSecは1つのログファイルにすべてのFQDNのログを出力するため、Fluentd側でFQDN別に分離する必要があります。

#### Phase 3.1.1: OpenAppSecログのFQDN別分割

**実装方法**: Fluentd側でFQDN別に分離

OpenAppSecのログJSONには、リクエストのホスト情報（FQDN）が含まれています。Fluentdの`rewrite_tag_filter`プラグインまたは`record_transformer`プラグインを使用して、FQDN別にタグを付け、FQDN別のディレクトリに出力します。

**実装方針**:
1. OpenAppSecのログJSONからFQDN情報を抽出（`host`, `hostname`, `requestHost`等のフィールドから）
2. Fluentdの`rewrite_tag_filter`プラグインでFQDN別にタグを付け直す
3. FQDN別のディレクトリにログを出力（`file`プラグインを使用）

**ログファイルパス**:
- 元のログ: `/var/log/nano_agent/*.log`
- FQDN別ログ: `/var/log/nano_agent/{fqdn}/*.log`（Fluentdで生成）

#### Phase 3.2: FluentdでのOpenAppSecログ収集設定

**ファイル**: `docker/fluentd/fluent.conf`

**実装内容**:
- OpenAppSecログファイルの監視設定
- JSON形式のログパース設定
- FQDN別のタグ付け設定（`openappsec.detection.{fqdn}`）
- FQDN別のログファイル出力（オプション）

**実装例**:
```aconf
<source>
  @type tail
  @id openappsec_detection
  path /var/log/nano_agent/*.log
  pos_file /var/log/fluentd/openappsec.detection.*.pos
  tag openappsec.detection
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S%z
  </parse>
  @if "#{ENV['LOG_COLLECTION_METHOD']}" == "shared-volume" || "#{ENV['LOG_COLLECTION_METHOD']}" == "hybrid"
</source>

# FQDN別にタグを付け直す
<filter openappsec.detection>
  @type rewrite_tag_filter
  <rule>
    key host
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # hostフィールドがない場合のフォールバック
  <rule>
    key hostname
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # デフォルトタグ（FQDNが取得できない場合）
  <rule>
    key _
    pattern /.*/
    tag openappsec.detection.unknown
  </rule>
</filter>

# FQDN別のログファイル出力（オプション）
<match openappsec.detection.**>
  @type file
  path /var/log/fluentd/output/openappsec_fqdn/${tag_parts[2]}/detection
  append true
  <format>
    @type json
  </format>
  <buffer tag,time>
    @type file
    path /var/log/fluentd/buffer/openappsec
    timekey 1d
    timekey_wait 10m
    timekey_use_utc true
  </buffer>
</match>
```

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
  - Bearerトークン認証の場合: トークン文字列を設定
  - Basic認証の場合: `username:password`をBase64エンコードした文字列を設定
  - 認証が不要な場合: 未設定（空文字列）

**認証方式の設定**:
- `out_http`プラグインの`<headers>`セクションで認証ヘッダーを設定
- Bearerトークン認証: `Authorization: Bearer #{ENV['FLUENTD_OUTPUT_AUTH']}`
- Basic認証: `Authorization: Basic #{ENV['FLUENTD_OUTPUT_AUTH']}`
- 認証方式は環境変数または設定ファイルで切り替え可能

#### Phase 4.2: Fluentd出力プラグインの設定

**ファイル**: `docker/fluentd/fluent.conf`

**実装内容**:
- HTTP出力プラグインの設定
- Forward出力プラグインの設定（オプション）
- エラーハンドリング設定
- リトライ設定

### Phase 5: ログローテーション設定

#### Phase 5.1: logrotate設定ファイルの作成

**ファイル**: `docker/nginx/logrotate.d/nginx`

**実装内容**:
- Nginxアクセスログのローテーション設定（毎日ローテート）
- Nginxエラーログのローテーション設定（毎日ローテート）
- FQDN別ログのローテーション設定（ディレクトリ単位）

**設定例**:
```bash
# /etc/logrotate.d/nginx
/var/log/nginx/*/access.log /var/log/nginx/*/error.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    missingok
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

**特徴**:
- **ローテーション方式**: 毎日ローテート（サイズベースではない）
- **保持期間**: 30日間（設定可能）
- **圧縮**: 有効（delaycompressで1日遅延）

## 実装詳細

### 1. Docker Compose設定

#### docker/docker-compose.yml

```yaml
services:
  nginx:
    volumes:
      # 設定ファイル
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      # ログファイル（共有ボリューム方式の場合）
      - ./nginx/logs:/var/log/nginx:rw
      # logrotate設定
      - ./nginx/logrotate.d:/etc/logrotate.d:ro
      # 共有メモリ
      - nginx-shm:/dev/shm/check-point
    logging:
      # ログドライバ方式を選択する場合: driver: "fluentd"
      driver: "${NGINX_LOG_DRIVER:-json-file}"
      options:
        # ログドライバ方式の場合のオプション例
        # fluentd-address: "${NGINX_LOG_OPT_FLUENTD_ADDRESS:-fluentd:24224}"
        # tag: "${NGINX_LOG_OPT_TAG:-nginx.{{.Name}}}"
        # デフォルト（json-file）の場合、オプションは不要

  openappsec-agent:
    volumes:
      # 設定ファイル
      - ./openappsec/local_policy.yaml:/ext/appsec/local_policy.yaml:ro
      # ログファイル（共有ボリューム方式の場合）
      - ./openappsec/logs:/var/log/nano_agent:rw
      # 共有メモリ
      - nginx-shm:/dev/shm/check-point
    logging:
      # ログドライバ方式を選択する場合: driver: "fluentd"
      driver: "${OPENAPPSEC_LOG_DRIVER:-json-file}"
      options:
        # ログドライバ方式の場合のオプション例
        # fluentd-address: "${OPENAPPSEC_LOG_OPT_FLUENTD_ADDRESS:-fluentd:24224}"
        # tag: "${OPENAPPSEC_LOG_OPT_TAG:-openappsec.{{.Name}}}"
        # デフォルト（json-file）の場合、オプションは不要

  fluentd:
    image: fluent/fluentd:v1.16-debian-1
    container_name: mwd-fluentd
    volumes:
      # Fluentd設定ファイル
      - ./fluentd/fluent.conf:/fluentd/etc/fluent.conf:ro
      # Nginxログ（共有ボリューム方式の場合、読み取り専用）
      - ./nginx/logs:/var/log/nginx:ro
      # OpenAppSecログ（共有ボリューム方式の場合、読み取り専用）
      - ./openappsec/logs:/var/log/nano_agent:ro
      # Fluentdのpos_fileとバッファ（永続ボリューム、共有ボリューム方式の場合必須）
      - ./fluentd/log:/var/log/fluentd:rw
      # OpenAppSec FQDN別ログ出力用（オプション、Fluentdで生成）
      # 注意: 監視対象のパスとは別のディレクトリに出力することで、ログの無限ループを防止
      - ./openappsec/logs-fqdn:/var/log/fluentd/output/openappsec_fqdn:rw
    ports:
      # ログドライバ方式の場合、Fluentd Forward Protocol用
      - "24224:24224"
      - "24224:24224/udp"
    environment:
      - FLUENTD_OUTPUT_URL=${FLUENTD_OUTPUT_URL:-stdout}
      - FLUENTD_OUTPUT_METHOD=${FLUENTD_OUTPUT_METHOD:-stdout}
      - FLUENTD_OUTPUT_AUTH=${FLUENTD_OUTPUT_AUTH:-}
      # ログ収集方式の選択
      - LOG_COLLECTION_METHOD=${LOG_COLLECTION_METHOD:-shared-volume}
      # shared-volume: 共有ボリューム方式（デフォルト）
      # log-driver: ログドライバ方式
      # hybrid: ハイブリッド方式
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

```aconf
# 共有ボリューム方式の場合（デフォルト）
<source>
  @type tail
  @id nginx_access
  path /var/log/nginx/*/access.log
  pos_file /var/log/fluentd/nginx.access.*.pos
  tag nginx.access.${File.dirname(path).split('/').last}
  # 一時的なタグ（FQDNのみ）: nginx.access.example1.com
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S%z
  </parse>
  @if "#{ENV['LOG_COLLECTION_METHOD']}" == "shared-volume" || "#{ENV['LOG_COLLECTION_METHOD']}" == "hybrid"
</source>

# Nginxアクセスログのタグを完全な形式に変換（ホスト名、顧客名、FQDN名、年、月、日、時間を含む）
<filter nginx.access.**>
  @type record_transformer
  <record>
    # メタデータをレコードに追加
    log_type "nginx"
    hostname "#{ENV['HOSTNAME'] || Socket.gethostname}"
    customer_name ${record["customer_name"] || ENV["CUSTOMER_NAME"] || "default"}
    fqdn ${tag_parts[2]}
    year ${Time.at(time).strftime("%Y")}
    month ${Time.at(time).strftime("%m")}
    day ${Time.at(time).strftime("%d")}
    hour ${Time.at(time).strftime("%H")}
    minute ${Time.at(time).strftime("%M")}
    second ${Time.at(time).strftime("%S")}
  </record>
  # タグを動的に生成: nginx.access.{hostname}.{customer_name}.{fqdn}.{year}.{month}.{day}.{hour}
  tag "nginx.access.${record['hostname']}.${record['customer_name']}.${record['fqdn']}.${record['year']}.${record['month']}.${record['day']}.${record['hour']}"
</filter>

# ログドライバ方式の場合
<source>
  @type forward
  @id docker_logs
  port 24224
  bind 0.0.0.0
  @if "#{ENV['LOG_COLLECTION_METHOD']}" == "log-driver" || "#{ENV['LOG_COLLECTION_METHOD']}" == "hybrid"
</source>

<source>
  @type tail
  @id nginx_error
  path /var/log/nginx/*/error.log
  pos_file /var/log/fluentd/nginx.error.*.pos
  tag nginx.error.${File.dirname(path).split('/').last}
  # 一時的なタグ（FQDNのみ）: nginx.error.example1.com
  <parse>
    # Nginxエラーログの形式: YYYY/MM/DD HH:MM:SS [level] pid.tid: message
    @type regexp
    expression /^(?<time>\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}) \[(?<level>[^\]]+)\] (?<pid>\d+).(?<tid>\d+): (?<message>.*)$/
    time_format %Y/%m/%d %H:%M:%S
  </parse>
  @if "#{ENV['LOG_COLLECTION_METHOD']}" == "shared-volume" || "#{ENV['LOG_COLLECTION_METHOD']}" == "hybrid"
</source>

# Nginxエラーログのタグを完全な形式に変換（ホスト名、顧客名、FQDN名、年、月、日、時間を含む）
<filter nginx.error.**>
  @type record_transformer
  <record>
    # メタデータをレコードに追加
    log_type "nginx"
    hostname "#{ENV['HOSTNAME'] || Socket.gethostname}"
    customer_name ${record["customer_name"] || ENV["CUSTOMER_NAME"] || "default"}
    fqdn ${tag_parts[2]}
    year ${Time.at(time).strftime("%Y")}
    month ${Time.at(time).strftime("%m")}
    day ${Time.at(time).strftime("%d")}
    hour ${Time.at(time).strftime("%H")}
    minute ${Time.at(time).strftime("%M")}
    second ${Time.at(time).strftime("%S")}
  </record>
  # タグを動的に生成: nginx.error.{hostname}.{customer_name}.{fqdn}.{year}.{month}.{day}.{hour}
  tag "nginx.error.${record['hostname']}.${record['customer_name']}.${record['fqdn']}.${record['year']}.${record['month']}.${record['day']}.${record['hour']}"
</filter>

<source>
  @type tail
  @id openappsec_detection
  path /var/log/nano_agent/*.log
  pos_file /var/log/fluentd/openappsec.detection.*.pos
  tag openappsec.detection
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S%z
  </parse>
  @if "#{ENV['LOG_COLLECTION_METHOD']}" == "shared-volume" || "#{ENV['LOG_COLLECTION_METHOD']}" == "hybrid"
</source>

# OpenAppSecログをFQDN別にタグ付け（中間ステップ）
<filter openappsec.detection>
  @type rewrite_tag_filter
  <rule>
    key host
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # hostフィールドがない場合のフォールバック
  <rule>
    key hostname
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # requestHostフィールドのフォールバック
  <rule>
    key requestHost
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # デフォルトタグ（FQDNが取得できない場合）
  <rule>
    key _
    pattern /.*/
    tag openappsec.detection.unknown
  </rule>
</filter>

# OpenAppSecログのタグを完全な形式に変換（ホスト名、顧客名、FQDN名、signature、protectionName、ruleName、年、月、日、時間を含む）
<filter openappsec.detection.**>
  @type record_transformer
  <record>
    # メタデータをレコードに追加
    log_type "openappsec"
    source "waf-engine"
    # タグからFQDNを抽出（タグ形式: openappsec.detection.{fqdn}）
    fqdn ${tag_parts[2]}
    # ホスト名（環境変数またはコンテナ名から取得）
    hostname "#{ENV['HOSTNAME'] || Socket.gethostname}"
    # 顧客名（ログレコードから取得、または環境変数から）
    customer_name ${record["customer_name"] || ENV["CUSTOMER_NAME"] || "default"}
    # シグニチャ情報（OpenAppSecログから抽出）
    signature_raw ${record["signature"] || "unknown"}
    signature ${record["signature_raw"].downcase.gsub(/[^a-z0-9_-]/, "_")}
    protection_name_raw ${record["protectionName"] || "unknown"}
    protection_name ${record["protection_name_raw"].downcase.gsub(/[^a-z0-9_-]/, "_")}
    rule_name_raw ${record["ruleName"] || "unknown"}
    rule_name ${record["rule_name_raw"].downcase.gsub(/[^a-z0-9_-]/, "_")}
    # 日時情報を抽出（timeフィールドから）
    year ${Time.at(time).strftime("%Y")}
    month ${Time.at(time).strftime("%m")}
    day ${Time.at(time).strftime("%d")}
    hour ${Time.at(time).strftime("%H")}
    minute ${Time.at(time).strftime("%M")}
    second ${Time.at(time).strftime("%S")}
  </record>
  # タグを動的に生成: openappsec.detection.{hostname}.{customer_name}.{fqdn}.{signature}.{protectionName}.{ruleName}.{year}.{month}.{day}.{hour}
  tag "openappsec.detection.${record['hostname']}.${record['customer_name']}.${record['fqdn']}.${record['signature']}.${record['protection_name']}.${record['rule_name']}.${record['year']}.${record['month']}.${record['day']}.${record['hour']}"
</filter>

# NginxログとOpenAppSecログの統合出力設定
<match {nginx,openappsec}.**>
  @type http
  endpoint "#{ENV['FLUENTD_OUTPUT_URL']}"
  http_method post
  # 認証情報の設定（環境変数から取得）
  # Bearerトークン認証の場合
  <headers>
    Authorization "Bearer #{ENV['FLUENTD_OUTPUT_AUTH']}"
  </headers>
  # Basic認証の場合（コメントアウト）
  # <headers>
  #   Authorization "Basic #{ENV['FLUENTD_OUTPUT_AUTH']}"
  # </headers>
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
# 注意: customer_nameはConfigAgentが設定ファイル生成時に追加する変数（$customer_name）を使用
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
    '"host":"$host",'
    '"customer_name":"$customer_name"'
  '}';

# 従来のログフォーマット（互換性のため保持）
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

# デフォルトのアクセスログ（JSON形式）
    access_log /var/log/nginx/access.log json_combined;
    
    # FQDN別ログは conf.d/{fqdn}.conf で設定
    # access_log /var/log/nginx/{fqdn}/access.log json_combined;
```

### 4. Nginx設定生成スクリプトの更新

#### config-agent/lib/nginx-config-generator.sh

**変更内容**:
- JSON形式のログフォーマットを使用するように更新
- FQDN別ログディレクトリにJSON形式で出力するように更新
- ログディレクトリの自動作成

**変更例**:
```bash
# FQDN別ログディレクトリを作成
mkdir -p /var/log/nginx/${fqdn}

# JSON形式のログフォーマットを使用
access_log /var/log/nginx/${fqdn}/access.log json_combined;
error_log /var/log/nginx/${fqdn}/error.log warn;
```

## Fluentdタグ設計

### タグ構造

Fluentdのタグは、以下の構造で設計します：

#### Nginxログ

```
{log_type}.{log_category}.{hostname}.{customer_name}.{fqdn}.{year}.{month}.{day}.{hour}
```

**例**:
- `nginx.access.waf-engine-01.customer-a.example1.com.2024.01.15.14`
- `nginx.error.waf-engine-01.customer-a.example1.com.2024.01.15.14`

**タグの各要素**:
- `{log_type}`: `nginx`
- `{log_category}`: `access` または `error`
- `{hostname}`: ホスト名（環境変数`HOSTNAME`またはコンテナ名）
- `{customer_name}`: 顧客名（環境変数`CUSTOMER_NAME`またはログレコードから取得）
- `{fqdn}`: FQDN名（ファイルパスまたはログレコードから抽出）
- `{year}`: 年（4桁、例: `2024`）
- `{month}`: 月（2桁、例: `01`）
- `{day}`: 日（2桁、例: `15`）
- `{hour}`: 時間（2桁、例: `14`）

#### OpenAppSecログ

```
{log_type}.{log_category}.{hostname}.{customer_name}.{fqdn}.{signature}.{protectionName}.{ruleName}.{year}.{month}.{day}.{hour}
```

**例**:
- `openappsec.detection.waf-engine-01.customer-a.example1.com.sql-injection-attempt.threat-prevention-basic.rule-001.2024.01.15.14`
- `openappsec.detection.waf-engine-01.customer-a.example1.com.xss-attempt.xss-protection.rule-002.2024.01.15.14`

**タグの各要素**:
- `{log_type}`: `openappsec`
- `{log_category}`: `detection`
- `{hostname}`: ホスト名（環境変数`HOSTNAME`またはコンテナ名）
- `{customer_name}`: 顧客名（環境変数`CUSTOMER_NAME`またはログレコードから取得）
- `{fqdn}`: FQDN名（ログJSONから抽出: `host`, `hostname`, `requestHost`）
- `{signature}`: シグニチャ（ログJSONから抽出: `signature`。存在しない場合は`unknown`。特殊文字はアンダースコアに正規化）
- `{protectionName}`: 保護名（ログJSONから抽出: `protectionName`。存在しない場合は`unknown`。特殊文字はアンダースコアに正規化）
- `{ruleName}`: ルール名（ログJSONから抽出: `ruleName`。存在しない場合は`unknown`。特殊文字はアンダースコアに正規化）
- `{year}`: 年（4桁、例: `2024`）
- `{month}`: 月（2桁、例: `01`）
- `{day}`: 日（2桁、例: `15`）
- `{hour}`: 時間（2桁、例: `14`）

**注意**: `signature`、`protectionName`、`ruleName`は可変長の文字列で、特殊文字が含まれる可能性があるため、タグに含める前に正規化（特殊文字をアンダースコアに置換、小文字化等）を行います。各フィールドが存在しない場合は`unknown`を使用します。

### タグに含まれる要素

#### Nginxアクセスログ

| 要素 | 取得方法 | タグ内の位置 | レコード内のフィールド |
|------|---------|------------|---------------------|
| ログ種別 | 固定値 | `nginx` | `log_type: "nginx"` |
| ログカテゴリ | 固定値 | `access` または `error` | - |
| ホスト名 | 環境変数またはコンテナ名 | `{hostname}` | `hostname` |
| 顧客名 | 環境変数またはログレコード | `{customer_name}` | `customer_name` |
| FQDN名 | ファイルパスから抽出 | `{fqdn}` | `fqdn`, `host` |
| 年 | タイムスタンプから抽出 | `{year}` | `year` |
| 月 | タイムスタンプから抽出 | `{month}` | `month` |
| 日 | タイムスタンプから抽出 | `{day}` | `day` |
| 時間 | タイムスタンプから抽出 | `{hour}` | `hour`, `minute`, `second` |

#### OpenAppSecログ

| 要素 | 取得方法 | タグ内の位置 | レコード内のフィールド |
|------|---------|------------|---------------------|
| ログ種別 | 固定値 | `openappsec` | `log_type: "openappsec"` |
| ログカテゴリ | 固定値 | `detection` | - |
| ホスト名 | 環境変数またはコンテナ名 | `{hostname}` | `hostname` |
| 顧客名 | 環境変数またはログレコード | `{customer_name}` | `customer_name` |
| FQDN名 | ログJSONから抽出 | `{fqdn}` | `host`, `hostname`, `requestHost` |
| 年 | タイムスタンプから抽出 | `{year}` | `year` |
| 月 | タイムスタンプから抽出 | `{month}` | `month` |
| 日 | タイムスタンプから抽出 | `{day}` | `day` |
| 時間 | タイムスタンプから抽出 | `{hour}` | `hour`, `minute`, `second` |
| シグニチャ | ログJSONから抽出 | `{signature}` | `signature` |
| 保護名 | ログJSONから抽出 | `{protectionName}` | `protectionName` |
| ルール名 | ログJSONから抽出 | `{ruleName}` | `ruleName` |

### タグ設計の実装

#### 1. タグの生成

**共有ボリューム方式（Nginx）**:

最初のタグはFQDNのみを含むシンプルな構造で生成し、その後`record_transformer`で完全なタグを生成します。

```aconf
<source>
  @type tail
  path /var/log/nginx/*/access.log
  tag nginx.access.${File.dirname(path).split('/').last}
  # 一時的なタグ例: nginx.access.example1.com
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S%z
  </parse>
</source>

# 完全なタグを生成（ホスト名、顧客名、FQDN名、年、月、日、時間を含む）
<filter nginx.access.**>
  @type record_transformer
  <record>
    # メタデータをレコードに追加
    log_type "nginx"
    hostname "#{ENV['HOSTNAME'] || Socket.gethostname}"
    customer_name ${record["customer_name"] || ENV["CUSTOMER_NAME"] || "default"}
    fqdn ${tag_parts[2]}
    year ${Time.at(time).strftime("%Y")}
    month ${Time.at(time).strftime("%m")}
    day ${Time.at(time).strftime("%d")}
    hour ${Time.at(time).strftime("%H")}
    minute ${Time.at(time).strftime("%M")}
    second ${Time.at(time).strftime("%S")}
  </record>
  # タグを動的に生成
  tag "nginx.access.${record['hostname']}.${record['customer_name']}.${record['fqdn']}.${record['year']}.${record['month']}.${record['day']}.${record['hour']}"
</filter>
```

**タグ生成の例**:
- 入力タグ: `nginx.access.example1.com`
- 生成タグ: `nginx.access.waf-engine-01.customer-a.example1.com.2024.01.15.14`

**共有ボリューム方式（OpenAppSec）**:

最初のタグは`openappsec.detection`で生成し、その後`rewrite_tag_filter`でFQDN別にタグを付け直し、最後に`record_transformer`で完全なタグを生成します。

```aconf
<source>
  @type tail
  path /var/log/nano_agent/*.log
  tag openappsec.detection
  # 一時的なタグ: openappsec.detection
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S%z
  </parse>
</source>

# FQDN別にタグを付け直す（中間ステップ）
<filter openappsec.detection>
  @type rewrite_tag_filter
  <rule>
    key host
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # hostフィールドがない場合のフォールバック
  <rule>
    key hostname
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # requestHostフィールドのフォールバック
  <rule>
    key requestHost
    pattern /^(.+)$/
    tag openappsec.detection.${1}
  </rule>
  # デフォルトタグ（FQDNが取得できない場合）
  <rule>
    key _
    pattern /.*/
    tag openappsec.detection.unknown
  </rule>
</filter>

# 完全なタグを生成（ホスト名、顧客名、FQDN名、signature、protectionName、ruleName、年、月、日、時間を含む）
<filter openappsec.detection.**>
  @type record_transformer
  <record>
    # メタデータをレコードに追加
    log_type "openappsec"
    source "waf-engine"
    # タグからFQDNを抽出（タグ形式: openappsec.detection.{fqdn}）
    fqdn ${tag_parts[2]}
    # ホスト名（環境変数またはコンテナ名から取得）
    hostname "#{ENV['HOSTNAME'] || Socket.gethostname}"
    # 顧客名（ログレコードから取得、または環境変数から）
    customer_name ${record["customer_name"] || ENV["CUSTOMER_NAME"] || "default"}
    # シグニチャ情報（OpenAppSecログから抽出）
    signature_raw ${record["signature"] || "unknown"}
    signature ${record["signature_raw"].downcase.gsub(/[^a-z0-9_-]/, "_")}
    protection_name_raw ${record["protectionName"] || "unknown"}
    protection_name ${record["protection_name_raw"].downcase.gsub(/[^a-z0-9_-]/, "_")}
    rule_name_raw ${record["ruleName"] || "unknown"}
    rule_name ${record["rule_name_raw"].downcase.gsub(/[^a-z0-9_-]/, "_")}
    # 日時情報を抽出（timeフィールドから）
    year ${Time.at(time).strftime("%Y")}
    month ${Time.at(time).strftime("%m")}
    day ${Time.at(time).strftime("%d")}
    hour ${Time.at(time).strftime("%H")}
    minute ${Time.at(time).strftime("%M")}
    second ${Time.at(time).strftime("%S")}
  </record>
  # タグを動的に生成: openappsec.detection.{hostname}.{customer_name}.{fqdn}.{signature}.{protectionName}.{ruleName}.{year}.{month}.{day}.{hour}
  tag "openappsec.detection.${record['hostname']}.${record['customer_name']}.${record['fqdn']}.${record['signature']}.${record['protection_name']}.${record['rule_name']}.${record['year']}.${record['month']}.${record['day']}.${record['hour']}"
</filter>
```

**タグ生成の例**:
- 入力タグ: `openappsec.detection.example1.com`
- シグニチャ情報:
  - `signature`: `SQL Injection Attempt` → 正規化後: `sql_injection_attempt`
  - `protectionName`: `Threat Prevention Basic` → 正規化後: `threat_prevention_basic`
  - `ruleName`: `Rule-001` → 正規化後: `rule_001`
- 生成タグ: `openappsec.detection.waf-engine-01.customer-a.example1.com.sql_injection_attempt.threat_prevention_basic.rule_001.2024.01.15.14`

#### 2. メタデータの追加

`record_transformer`プラグインを使用して、タグに含まれる要素をレコードに追加します（上記のFluentd設定例を参照）。

#### 3. 顧客名の取得方法

顧客名は、以下の優先順位で取得します：

1. **ログレコード内のフィールド**: `customer_name`フィールドが存在する場合
2. **環境変数**: `CUSTOMER_NAME`環境変数が設定されている場合
3. **デフォルト値**: `"default"`

**実装方針**:
- **Nginxログ**: ConfigAgentが管理APIから取得した設定情報に顧客名が含まれている場合、Nginxの`log_format`に`$customer_name`変数を追加
  - `log_format json_combined`に`"customer_name":"$customer_name"`を追加（上記の設定例を参照）
  - ConfigAgentがNginx設定ファイル生成時に、`set $customer_name "customer-name";`を追加
- **OpenAppSecログ**: ConfigAgentが設定ファイルに顧客名を追加（将来的な拡張）
  - 現時点では、環境変数`CUSTOMER_NAME`から取得するか、デフォルト値を使用

## 受け入れ条件

- [ ] Fluentdコンテナが正常に起動する
- [ ] NginxアクセスログがJSON形式で出力される
- [ ] FQDN別ログが `/var/log/nginx/{fqdn}/[access.log|error.log]` に出力される
- [ ] FluentdがNginxアクセスログを正常に収集できる（共有ボリューム方式）
- [ ] FluentdがDocker Logging Driverからログを正常に受信できる（ログドライバ方式）
- [ ] OpenAppSec WAF検知ログが正常に収集できる
- [ ] OpenAppSecログがFQDN別に正常に分離される
- [ ] ログがログ管理サーバに正常に転送される（設定した場合）
- [ ] ログのタグ付けが正しく行われる（FQDN別タグを含む）
- [ ] メタデータ（ホスト名、顧客名、日時、検知シグニチャ等）が正しく追加される
- [ ] エラーハンドリングとリトライが正常に動作する
- [ ] ログローテーションが毎日正常に動作する（logrotate.d使用）
- [ ] Fluentd永続ボリュームが正常にマウントされる（共有ボリューム方式の場合）
- [ ] 環境変数によるログ収集方式の選択が正常に動作する

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
