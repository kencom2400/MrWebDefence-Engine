# Task 5.0: Docker Compose構成実装

## 概要

このディレクトリには、OpenAppSecとNginxを統合したDocker Compose構成が含まれています。
Task 5.0では、OpenAppSec、Nginx、設定取得エージェントを統合して動作させるためのDocker Compose構成を実装しています。

## 構成

### コンテナ

- **nginx**: OpenAppSec公式のNginxイメージ（Attachment Module組み込み）
  - コンテナ名: `mwd-nginx`
  - ポート: 80, 443
  - Attachment Moduleが組み込まれた公式イメージを使用

- **openappsec-agent**: OpenAppSec公式のAgentイメージ
  - コンテナ名: `mwd-openappsec-agent`
  - Nginxと共有メモリで通信

- **config-agent**: 設定取得エージェント
  - コンテナ名: `mwd-config-agent`
  - 管理APIから設定を取得し、OpenAppSec設定ファイルとNginx設定ファイルを生成

- **mock-api**: モックAPIサーバー（動作確認用）
  - コンテナ名: `mwd-mock-api`
  - ポート: 8080
  - 開発・テスト環境での動作確認用

### ボリューム

- **nginx-shm**: 共有メモリ用のtmpfsボリューム
  - OpenAppSec AgentとNginx間のIPC通信に使用
  - マウントポイント: `/dev/shm/check-point`
  - タイプ: tmpfs

- **mock-api-config**: モックAPI設定ファイル用
  - モックAPIサーバーの設定データを保存

### ネットワーク

- **mwd-network**: ブリッジネットワーク
  - 全コンテナが同じネットワークに接続
  - コンテナ間の名前解決が可能

### 環境変数

#### openappsec-agent
- `registered_server=NGINX`: サーバータイプ（必須）
- `autoPolicyLoad=true`: ローカルポリシーファイルの自動読み込み（デフォルト: true）
- `OPENAPPSEC_LOG_LEVEL=info`: ログレベル（デフォルト: info）

#### config-agent
- `CONFIG_API_URL`: 管理APIのURL（デフォルト: `http://mock-api:8080`）
- `CONFIG_API_TOKEN`: APIトークン（デフォルト: `test-token`）
- `POLLING_INTERVAL`: ポーリング間隔（秒、デフォルト: 300）
- `CACHE_TTL`: キャッシュTTL（秒、デフォルト: 300）
- `OUTPUT_DIR`: 出力ディレクトリ（デフォルト: `/app/output`）
- `NGINX_CONTAINER_NAME`: Nginxコンテナ名（デフォルト: `mwd-nginx`）

#### mock-api
- `MOCK_API_PORT`: ポート番号（デフォルト: 8080）
- `MOCK_API_CONFIG_FILE`: 設定ファイルパス（デフォルト: `/tmp/mock-api-config.json`）

## 起動方法

### 前提条件

- Docker と docker-compose がインストールされていること
- ポート80、443が使用可能であること

### 起動手順

1. **このディレクトリに移動**
   ```bash
   cd docker
   ```

2. **Docker Composeで起動**
   ```bash
   docker-compose up -d
   ```

3. **起動確認**
   ```bash
   # コンテナの状態確認
   docker-compose ps
   
   # ログの確認
   docker-compose logs -f
   ```

4. **動作確認**
   ```bash
   # テスト用FQDNにHTTPリクエストを送信
   curl -H "Host: test.example.com" http://localhost/
   
   # ヘルスチェック
   curl -H "Host: test.example.com" http://localhost/health
   ```

## 設定ファイル

- `nginx/nginx.conf`: Nginx基本設定
- `nginx/conf.d/*.conf`: FQDN別設定（自動生成される）
- `openappsec/local_policy.yaml`: OpenAppSecポリシー設定

## トラブルシューティング

### コンテナが起動しない

```bash
# ログを確認
docker-compose logs

# コンテナを再起動
docker-compose restart
```

### Nginx設定エラー

```bash
# Nginx設定の構文チェック
docker-compose exec nginx nginx -t
```

### OpenAppSec Agentが起動しない

```bash
# OpenAppSec Agentのログを確認
docker-compose logs openappsec-agent

# local_policy.yamlの構文チェック
docker-compose exec openappsec-agent cat /ext/appsec/local_policy.yaml
```

### Attachment Moduleが読み込まれない

```bash
# Nginxのモジュール一覧を確認
docker-compose exec nginx nginx -V 2>&1 | grep -i module

# エラーログを確認
docker-compose logs nginx | grep -i error
```

## SaaS管理UI対応版

SaaS管理UI（my.openappsec.io）を使用する場合は、`docker-compose.saas.yml`を使用します。

### 使用方法

1. `.env`ファイルに以下を設定:
   ```bash
   APPSEC_AGENT_TOKEN=your-agent-token
   APPSEC_USER_EMAIL=your-email@example.com
   APPSEC_AUTO_POLICY_LOAD=false
   ```

2. マージして起動:
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.saas.yml up -d
   ```

詳細は `README-SAAS.md` を参照してください。

## 受け入れ条件（Task 5.0）

Task 5.0の実装完了条件:

- [x] Docker Composeで全コンテナが正常に起動する
- [x] 共有メモリボリュームが正常にマウントされる
- [x] コンテナ間の通信が正常に動作する
- [x] 環境変数が正しく設定される

## 注意事項

1. **共有メモリ**: `/dev/shm`をtmpfsボリュームとしてマウントしています
2. **IPC設定**: `ipc: host`を設定して、コンテナ間のIPC通信を有効化しています
   - 開発環境: 公式ドキュメントに従って`ipc: host`を使用
   - 本番環境: セキュリティリスクを考慮し、共有ボリュームのみの使用を検討
3. **ポリシーファイルのパス**: OpenAppSec Agentの設定ファイルパスは公式ドキュメントで確認が必要です
4. **Dockerソケット**: ConfigAgentがNginxをリロードするためにDockerソケットが必要ですが、セキュリティリスクがあるため、現在はコメントアウトされています。代替手段として`watch-config.sh`スクリプトを使用しています

## 依存関係

- **nginx** → `depends_on: openappsec-agent`
- **config-agent** → `depends_on: mock-api`

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [OpenAppSec Docker統合ガイド](https://docs.openappsec.io/getting-started/start-with-docker/)
- 設計書: `docs/design/MWD-38-task-review.md`（Task 5.0の要件定義）
- 実装計画: `docs/design/MWD-38-implementation-plan.md`