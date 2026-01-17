# OpenAppSec SaaS管理UI セットアップガイド

このドキュメントは、OpenAppSecのSaaS管理UI（my.openappsec.io）を使用する場合のセットアップ手順です。

## 概要

OpenAppSecには2つの管理モードがあります：

1. **ローカル管理（Local/Declarative Management）**
   - `local_policy.yaml`ファイルで管理
   - デフォルトの設定

2. **SaaS管理UI（Central Management）**
   - Web UI（my.openappsec.io）で管理
   - このドキュメントで説明

## 前提条件

1. OpenAppSecのアカウント（https://my.openappsec.io）
2. Deployment Profileの作成
3. Agent Tokenの取得

## セットアップ手順

### 1. OpenAppSec Web UIでDeployment Profileを作成

1. https://my.openappsec.io にログイン
2. **Deployment Profile** を作成または選択
3. **Token** をコピー（後で使用します）

### 2. 環境変数ファイルの作成

`docker/.env` ファイルを作成し、以下の環境変数を設定します：

```bash
# OpenAppSec SaaS管理UI設定
APPSEC_AGENT_TOKEN=your-token-from-webui
APPSEC_USER_EMAIL=your-email@example.com
APPSEC_AUTO_POLICY_LOAD=false

# その他の設定（オプション）
OPENAPPSEC_LOG_LEVEL=info
# APPSEC_HTTPS_PROXY=http://proxy.example.com:8080
```

**重要**: `APPSEC_AGENT_TOKEN` は必須です。Web UIから取得したTokenを設定してください。

### 3. 必要なディレクトリの作成

SaaS管理用のボリュームディレクトリを作成します：

```bash
cd docker
mkdir -p appsec-config appsec-data appsec-logs
```

### 4. Docker Composeで起動

SaaS管理モードで起動する場合：

```bash
cd docker
docker-compose -f docker-compose.yml -f docker-compose.saas.yml up -d
```

ローカル管理モードで起動する場合（デフォルト）：

```bash
cd docker
docker-compose up -d
```

### 5. 動作確認

1. **Agentのステータス確認**:
   ```bash
   docker-compose exec openappsec-agent open-appsec-ctl --status
   ```

2. **Web UIでAgentを確認**:
   - https://my.openappsec.io にログイン
   - **Agents** タブでAgentが表示されていることを確認

## 管理モードの違い

### ローカル管理（Local/Declarative Management）

- `local_policy.yaml`ファイルで管理
- `docker-compose.yml`のみ使用
- `APPSEC_AUTO_POLICY_LOAD=true`（デフォルト）
- Web UIは設定を読み取り専用で表示

### SaaS管理UI（Central Management）

- Web UI（my.openappsec.io）で管理
- `docker-compose.yml` + `docker-compose.saas.yml`を使用
- `APPSEC_AGENT_TOKEN`と`APPSEC_USER_EMAIL`を設定
- `APPSEC_AUTO_POLICY_LOAD=false`（推奨）
- Web UIから直接設定を変更可能

## ボリュームマウント

SaaS管理モードでは、以下のボリュームがマウントされます：

- `/etc/cp/conf` → `docker/appsec-config`（設定ファイル）
- `/etc/cp/data` → `docker/appsec-data`（データファイル、永続化）
- `/var/log/nano_agent` → `docker/appsec-logs`（ログファイル）
- `/ext/appsec` → `docker/openappsec`（ローカルポリシー、Declarative Configurationモードの場合のみ使用）

## トラブルシューティング

### AgentがWeb UIに表示されない

1. `APPSEC_AGENT_TOKEN`が正しく設定されているか確認
2. Agentのログを確認:
   ```bash
   docker-compose logs openappsec-agent
   ```
3. ネットワーク接続を確認（プロキシが必要な場合は`APPSEC_HTTPS_PROXY`を設定）

### 設定が反映されない

1. Web UIで設定を保存した後、Agentが設定を取得するまで数秒待つ
2. Agentのステータスを確認:
   ```bash
   docker-compose exec openappsec-agent open-appsec-ctl --status --extended
   ```

### ローカル管理とSaaS管理の切り替え

**ローカル管理からSaaS管理に切り替え**:
1. `.env`ファイルに`APPSEC_AGENT_TOKEN`を設定
2. `docker-compose -f docker-compose.yml -f docker-compose.saas.yml up -d`

**SaaS管理からローカル管理に切り替え**:
1. `docker-compose.saas.yml`を使用せずに起動
2. `docker-compose up -d`

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/getting-started/using-the-web-ui-saas/connect-deployed-agents-to-saas-management-docker)
- [参考docker-compose.yaml](https://raw.githubusercontent.com/openappsec/open-appsec-npm/main/deployment/managed-from-open-appsec-ui/docker-compose.yaml)
