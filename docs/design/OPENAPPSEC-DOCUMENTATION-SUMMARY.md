# OpenAppSec公式ドキュメントまとめ

## ドキュメントURL

- **メインページ**: https://docs.openappsec.io/getting-started/getting-started
- **Docker統合**: https://docs.openappsec.io/getting-started/start-with-docker
- **Linux統合**: https://docs.openappsec.io/getting-started/start-with-linux
- **Kubernetes統合**: https://docs.openappsec.io/getting-started/start-with-kubernetes

## 概要

OpenAppSecは、機械学習ベースのWeb Application Firewall (WAF) です。Nginx、Kubernetes、Dockerなどの環境で動作し、自動的な脅威検出と防御を提供します。

## 主要な概念

### 1. Agent（エージェント）

- OpenAppSecのコアコンポーネント
- 機械学習モデルによる脅威検出を実行
- 複数のデプロイメントモードをサポート（Linux、Docker、Kubernetes）

### 2. Attachment Module（アタッチメントモジュール）

- Nginxなどのリバースプロキシと統合するためのモジュール
- HTTP(S)トラフィックをインターセプトしてAgentに送信
- Agentからの判定結果を受信して適用

### 3. Management Portal（管理ポータル）

- Web UI（SaaS）による集中管理
- ローカルポリシーファイルによる管理も可能

## デプロイメント方法

### Docker統合（推奨）

#### 公式Docker Composeファイルの取得

```bash
mkdir open-appsec-deployment && cd open-appsec-deployment
wget https://raw.githubusercontent.com/openappsec/openappsec/main/deployment/docker-compose/nginx/docker-compose.yaml
wget https://raw.githubusercontent.com/openappsec/openappsec/main/deployment/docker-compose/nginx/.env
```

#### 必要なコンポーネント

1. **Nginx Attachment Module**
   - イメージ: `ghcr.io/openappsec/nginx-attachment:${APPSEC_VERSION}`
   - NginxにAttachment Moduleが組み込まれたイメージ
   - デフォルトで`nginx.conf`にモジュールが読み込まれている

2. **OpenAppSec Agent**
   - イメージ: `ghcr.io/openappsec/agent:${APPSEC_VERSION}`
   - WAFエンジン本体
   - コマンド: `/cp-nano-agent`

#### 環境変数設定（.envファイル）

```bash
# 必須
APPSEC_AGENT_TOKEN=<your-profile-token>  # SaaS管理の場合
NGINX_CONFIG=<host-directory-path>         # Nginx設定ディレクトリ

# オプション
COMPOSE_PROFILES=standalone               # ローカル管理の場合
APPSEC_AUTO_POLICY_LOAD=true              # ポリシーファイル自動読み込み
APPSEC_HTTPS_PROXY=<proxy-url>            # プロキシ経由の場合
APPSEC_USER_EMAIL=<email>                 # ユーザーEmail
APPSEC_VERSION=latest                     # イメージバージョン
```

#### Docker Compose設定の要点

1. **IPC設定**
   ```yaml
   ipc: host  # AgentとNginxの両方に必要
   ```

2. **共有メモリボリューム**
   ```yaml
   volumes:
     - shm-volume:/dev/shm/check-point
   
   volumes:
     shm-volume:
       driver: local
       driver_opts:
         type: tmpfs
         device: tmpfs
   ```

3. **Agent環境変数**
   ```yaml
   environment:
     - registered_server="NGINX"
     - AGENT_TOKEN=${APPSEC_AGENT_TOKEN}
     - user_email=${APPSEC_USER_EMAIL}
     - autoPolicyLoad=${APPSEC_AUTO_POLICY_LOAD}
     - https_proxy=${APPSEC_HTTPS_PROXY}
   ```

4. **Agentボリュームマウント**
   ```yaml
   volumes:
     - ${APPSEC_CONFIG}:/etc/cp/conf        # 設定ファイル
     - ${APPSEC_DATA}:/etc/cp/data          # データファイル
     - ${APPSEC_LOGS}:/var/log/nano_agent   # ログ
     - ${APPSEC_LOCALCONFIG}:/ext/appsec    # ローカルポリシー
     - shm-volume:/dev/shm/check-point      # 共有メモリ
   ```

#### Nginx設定

- **モジュール読み込み**: 公式イメージには既に組み込まれている
- **カスタムnginx.conf**: 提供する場合は、必ず以下を追加
  ```nginx
  load_module /usr/lib/nginx/modules/ngx_cp_attachment_module.so;
  ```
- **サイト設定**: `${NGINX_CONFIG}/conf.d/default.conf`に配置

#### 起動手順

```bash
# 1. 環境変数を設定
vim .env

# 2. サービス起動
docker compose up -d

# 3. 確認
docker ps
```

#### 管理モード

**Central Management (SaaS)**
- Web UI（my.openappsec.io）で管理
- `APPSEC_AGENT_TOKEN`を設定
- ポータルでAgentが表示される

**Local/Declarative Management**
- `COMPOSE_PROFILES=standalone`を設定
- `local_policy.yaml`を`./appsec-localconfig`に配置
- `APPSEC_AUTO_POLICY_LOAD=true`で自動適用

### Linux統合

#### インストール方法

1. **自動インストール**
   ```bash
   wget https://downloads.openappsec.io/open-appsec-install
   chmod +x open-appsec-install
   sudo ./open-appsec-install --auto
   ```

2. **手動インストール**
   ```bash
   ./open-appsec-install --download
   # 手動でモジュールとライブラリを配置
   ```

#### 設定ファイル

- Nginx設定: `/etc/nginx/nginx.conf`
- ポリシーファイル: `/ext/appsec/local_policy.yaml` または `/etc/cp/conf/local_policy.yaml`

### Kubernetes統合

- CRD（Custom Resource Definition）を使用
- Operatorによる自動管理
- ポリシーをKubernetesリソースとして管理

## ポリシー設定

### Local Policy File（v1beta2）

#### 基本構造

```yaml
apiVersion: v1beta2
policies:
  default:
    mode: detect-learn
    accessControlPractices: [access-control-practice-example]
    threatPreventionPractices: [threat-prevention-practice-example]
    triggers: [log-trigger-example]
    customResponse: web-user-response-example
    sourceIdentifiers: ""
    trustedSources: ""
    exceptions:
      - exception-example
  
  specificRules:
    - host: "example.com"
      mode: prevent-learn
      threatPreventionPractices: [threat-prevention-practice-example]
      accessControlPractices: [access-control-practice-example]
      triggers: [log-trigger-example]
      customResponse: web-user-response-example
      sourceIdentifiers: ""
      trustedSources: ""
      exceptions:
        - exception-example

# プラクティス定義
threatPreventionPractices:
  - name: threat-prevention-practice-example
    practiceMode: inherited
    webAttacks:
      overrideMode: inherited
      minimumConfidence: high
    intrusionPrevention:
      overrideMode: inherited
      maxPerformanceImpact: medium
      minSeverityLevel: medium
      minCveYear: 2016
      highConfidenceEventAction: inherited
      mediumConfidenceEventAction: inherited
      lowConfidenceEventAction: detect
    fileSecurity:
      overrideMode: inherited
      minSeverityLevel: medium
      highConfidenceEventAction: inherited
      mediumConfidenceEventAction: inherited
      lowConfidenceEventAction: detect
    snortSignatures:
      overrideMode: inherited
      configmap: []
      files: []
    schemaValidation:
      overrideMode: inherited
      configmap: []
      files: []
    antiBot:
      overrideMode: inherited
      injectedUris: []
      validatedUris: []

accessControlPractices:
  - name: access-control-practice-example
    practiceMode: inherited
    rateLimit:
      overrideMode: inherited
      rules: []
      # rule例:
      # - action: inherited|prevent|detect
      #   uri: "/api/*"
      #   limit: 100
      #   unit: minute
      #   triggers: []
      #   comment: "Example rate limit"

customResponses:
  - name: web-user-response-example
    mode: response-code-only
    httpResponseCode: 403
    # redirectUrl: "https://example.com/blocked"
    # redirectAddXEventId: false

logTriggers:
  - name: log-trigger-example
    accessControlLogging:
      allowEvents: false
      dropEvents: true
    appsecLogging:
      detectEvents: true
      preventEvents: true
      allWebRequests: false
    extendedLogging:
      urlPath: true
      urlQuery: true
      httpHeaders: false
      requestBody: false
    additionalSuspiciousEventsLogging:
      enabled: true
      minSeverity: high
      responseBody: false
      responseCode: true
    logDestination:
      cloud: true
      logToAgent: false
      stdout:
        format: json

exceptions:
  - name: exception-example
    action: "accept"
    condition:
      - key: "countryCode"
        value: "US"

trustedsources:
  - name: trusted-sources-example
    minNumOfSources: 3
    sourcesIdentifiers:
      - 1.0.0.27
      - 1.0.0.28
      - 1.0.0.29

sourcesIdentifiers:
  - name: sources-identifier-example
    - identifier: sourceip
      value:
        - "0.0.0.0"
```

#### モード

- **detect-learn**: 検知のみ（ブロックしない）、学習データを収集
- **prevent-learn**: ブロックしつつ学習データを収集
- **detect**: 検知のみ（学習データを収集しない）
- **prevent**: ブロック（学習データを収集しない）
- **inactive**: 無効化

#### specificRules

FQDN別の設定を定義できます：

```yaml
specificRules:
  - host: "api.example.com"
    mode: prevent-learn
    threatPreventionPractices: [threat-prevention-practice-example]
    accessControlPractices: [access-control-practice-example]
```

#### 公式サンプルファイル

```bash
wget https://raw.githubusercontent.com/openappsec/openappsec/main/config/linux/v1beta2/example/local_policy.yaml
```

## 重要な設定項目

### 1. 共有メモリ通信

- NginxとAgent間の通信に使用
- Docker環境では`ipc: host`が必須（公式ドキュメント推奨）
- 共有tmpfsボリューム: `/dev/shm/check-point`にマウント
- ボリューム定義:
  ```yaml
  volumes:
    shm-volume:
      driver: local
      driver_opts:
        type: tmpfs
        device: tmpfs
  ```

### 2. ポリシーファイルのパス

- **Docker**: `/ext/appsec/local_policy.yaml`
- **Linux**: `/ext/appsec/local_policy.yaml` または `/etc/cp/conf/local_policy.yaml`
- `autoPolicyLoad=true`環境変数で自動読み込み（変更を検知して自動適用）
- 手動適用: `open-appsec-ctl --apply-policy`

### 3. Agentボリュームマウント

公式推奨のマウントポイント：

```yaml
volumes:
  - ${APPSEC_CONFIG}:/etc/cp/conf        # 設定ファイル
  - ${APPSEC_DATA}:/etc/cp/data          # データファイル（永続化）
  - ${APPSEC_LOGS}:/var/log/nano_agent   # ログ
  - ${APPSEC_LOCALCONFIG}:/ext/appsec    # ローカルポリシー
```

### 4. ログ設定

- **Agentログ**: `/var/log/nano_agent`
- **Nginxログ**: 標準のNginxログパス
- **ログ形式**: JSON形式もサポート（`logTriggers`で設定）

### 5. 環境変数

主要な環境変数：

- `registered_server="NGINX"` - サーバータイプ
- `AGENT_TOKEN` - SaaS管理用のトークン
- `user_email` - ユーザーEmail
- `autoPolicyLoad` - ポリシーファイル自動読み込み
- `https_proxy` - プロキシ設定
- `SHARED_STORAGE_HOST` - 共有ストレージホスト（standaloneモード）
- `LEARNING_HOST` - 学習サービスホスト（standaloneモード）
- `TUNING_HOST` - チューニングサービスホスト（standaloneモード）

## トラブルシューティング

### よくある問題

1. **Attachment Moduleが読み込まれない**
   - モジュールパスを確認: `/usr/lib/nginx/modules/ngx_cp_attachment_module.so`
   - Nginxバージョンとの互換性を確認

2. **Agentが起動しない**
   - ポリシーファイルのパスを確認
   - 共有メモリのマウントを確認
   - ログを確認: `docker logs <container-name>`

3. **共有メモリ通信エラー**
   - `ipc: host`の設定を確認
   - 共有ボリュームのマウントを確認

## セキュリティプラクティス

### Threat Prevention Practices

- デフォルトの脅威検出ルール
- 機械学習モデルによる自動検出
- カスタムルールの追加

### Access Control Practices

- レート制限
- IP制限
- 地理的制限

## 管理方法

### Web UI（SaaS）

- 集中管理ポータル
- 複数のAgentを一元管理
- リアルタイム監視

### Local Policy File

- ローカルファイルによる管理
- バージョン管理が容易
- CI/CDパイプラインとの統合が可能

## 参考資料

- [公式ドキュメント](https://docs.openappsec.io/)
- [GitHubリポジトリ](https://github.com/openappsec)
- [Attachment Module](https://github.com/openappsec/attachment)

## 注意事項

### 公式ドキュメントに存在しない設定

以下の設定は公式ドキュメントには記載されていませんが、設計書で言及されている場合があります：

- `openappsec_shared_memory_zone` - NGINXのshared_memory_zoneディレクティブは使用されない
- `openappsec_agent_url` - 公式ドキュメントには存在しない
- `openappsec_enabled` - 公式ドキュメントには存在しない

**実際の動作**: 
- OpenAppSecはモジュールを読み込むことで自動的に有効化されます
- 設定は`local_policy.yaml`で行います
- Nginx設定ファイルに追加する必要があるのは`load_module`ディレクティブのみです
- インストーラーが自動的に`cp-nano-nginx-attachment`で始まる行を追加します（手動で追加する必要はありません）

### Nginx設定に関する重要なポイント

1. **モジュール読み込み**
   - 公式イメージには既に組み込まれている
   - カスタムnginx.confを使用する場合は、必ず以下を追加：
     ```nginx
     load_module /usr/lib/nginx/modules/ngx_cp_attachment_module.so;
     ```
   - または: `/usr/lib/nginx/modules/libngx_module.so`（ビルド方法によって異なる）

2. **自動追加される設定**
   - インストーラーが`/etc/nginx/conf.d`または`/etc/nginx/sites-enabled`に自動的に`cp-nano-nginx-attachment`で始まる行を追加
   - これらは手動で編集する必要はありません
   - Nginxアップグレード時は一時的にコメントアウトする必要があります

3. **共有メモリ**
   - OSレベルの`/dev/shm`を使用
   - Docker環境では`ipc: host`とtmpfsボリュームの両方が推奨されています
   - マウントポイント: `/dev/shm/check-point`

### 推奨事項

1. **イメージバージョン**: `:latest`タグではなく、特定バージョンを指定（再現性のため）
   - 環境変数`APPSEC_VERSION`で管理
   - 例: `APPSEC_VERSION=1.6.0`

2. **IPC設定**: 公式ドキュメントでは`ipc: host`が推奨されています
   - セキュリティリスクがあるため、本番環境では共有ボリュームのみを使用することを検討
   - ただし、公式ドキュメントでは`ipc: host`が標準的な方法として記載されています

3. **Dockerソケット**: 本番環境ではマウントを避け、より安全な方法を検討
   - シグナルファイル方式など

4. **管理モードの選択**
   - **Central Management (SaaS)**: 複数環境の一元管理、Web UIでの監視
   - **Local/Declarative**: GitOps、CI/CD統合、バージョン管理

5. **ポリシーファイルの適用**
   - `autoPolicyLoad=true`で自動適用（約30秒で反映）
   - 手動適用: `open-appsec-ctl --apply-policy`

## 公式ドキュメントの主要リンク

### Getting Started
- [Getting Started Overview](https://docs.openappsec.io/getting-started/getting-started)
- [Start with Docker](https://docs.openappsec.io/getting-started/start-with-docker)
- [Deploy with Docker Compose](https://docs.openappsec.io/getting-started/start-with-docker/deploy-with-docker-compose)
- [Start with Linux](https://docs.openappsec.io/getting-started/start-with-linux)
- [Start with Kubernetes](https://docs.openappsec.io/getting-started/start-with-kubernetes)

### Configuration
- [Local Policy File v1beta2](https://docs.openappsec.io/getting-started/start-with-linux/local-policy-file-v1beta2-beta)
- [Configuration Using CRDs v1beta2](https://docs.openappsec.io/getting-started/start-with-kubernetes/configuration-using-crds-v1beta2)
- [Load the Attachment in Proxy Configuration](https://docs.openappsec.io/deployment-and-upgrade/load-the-attachment-in-proxy-configuration)

### Management
- [Using the Web UI (SaaS)](https://docs.openappsec.io/getting-started/using-the-web-ui-saas)
- [Connect Deployed Agents to SaaS Management](https://docs.openappsec.io/getting-started/using-the-web-ui-saas/connect-deployed-agents-to-saas-management-docker)

### Docker Compose Files
- [NGINX docker-compose.yaml](https://raw.githubusercontent.com/openappsec/openappsec/main/deployment/docker-compose/nginx/docker-compose.yaml)
- [NGINX .env template](https://raw.githubusercontent.com/openappsec/openappsec/main/deployment/docker-compose/nginx/.env)

### Example Files
- [Local Policy v1beta2 Example](https://raw.githubusercontent.com/openappsec/openappsec/main/config/linux/v1beta2/example/local_policy.yaml)

## 更新履歴

- 2026-01-16: 初版作成
- 公式ドキュメント（https://docs.openappsec.io/）を参照
- Docker Compose設定の詳細を追加
- v1beta2ポリシーファイルの完全な構造を追加
