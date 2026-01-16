# OpenAppSec統合 Docker構成

## 概要

このディレクトリには、OpenAppSecとNginxを統合したDocker Compose構成が含まれています。

## 構成

- **Nginx**: OpenAppSec公式のNginxイメージ（Attachment Module組み込み）
- **OpenAppSec Agent**: OpenAppSec公式のAgentイメージ
- **共有メモリ**: `/dev/shm`をtmpfsボリュームとしてマウント

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

## 注意事項

1. **共有メモリ**: `/dev/shm`をtmpfsボリュームとしてマウントしています
2. **IPC設定**: `ipc: host`を設定して、コンテナ間のIPC通信を有効化しています
3. **ポリシーファイルのパス**: OpenAppSec Agentの設定ファイルパスは公式ドキュメントで確認が必要です

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [OpenAppSec Docker統合ガイド](https://docs.openappsec.io/getting-started/start-with-docker/)
