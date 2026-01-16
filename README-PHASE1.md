# Phase 1: 基盤構築 - 実装ガイド

## 概要

Phase 1では、最小構成でOpenAppSecとNginxを統合します。

## 実装状況

### ✅ 完了した項目

- [x] Phase 1.1: ディレクトリ構造の作成
- [x] Phase 1.2: Docker Composeファイルの作成
- [x] Phase 1.3: Nginx基本設定の作成
- [x] Phase 1.4: OpenAppSec基本設定の作成
- [x] Phase 1.5: 単一FQDN設定ファイルの作成（テスト用）

## ファイル構成

```
MrWebDefence-Engine/
├── docker/
│   ├── docker-compose.yml          # Docker Compose構成
│   ├── nginx/
│   │   ├── nginx.conf              # Nginx基本設定
│   │   └── conf.d/
│   │       ├── .gitkeep
│   │       └── test.example.com.conf  # テスト用FQDN設定
│   └── openappsec/
│       ├── .gitkeep
│       └── local_policy.yaml        # OpenAppSec基本設定
├── config-agent/                    # 設定取得エージェント（Phase 3で実装）
├── scripts/
│   └── openappsec/                  # 運用スクリプト（Phase 4で実装）
└── docs/
    └── design/
        └── MWD-38-implementation-plan.md
```

## 起動方法

### 前提条件

- Docker と docker-compose がインストールされていること
- ポート80、443が使用可能であること

### 起動手順

1. **環境変数の設定（オプション）**
   ```bash
   # 必要に応じて環境変数を設定
   export CONFIG_API_URL=http://config-api:8080
   export CONFIG_API_TOKEN=your-api-token
   ```

2. **Docker Composeで起動**
   ```bash
   cd docker
   docker-compose up -d
   ```
   
   または、プロジェクトルートから：
   ```bash
   # プロジェクトのルートディレクトリで実行してください
   docker-compose -f docker/docker-compose.yml up -d
   ```

3. **起動確認**
   ```bash
   # dockerディレクトリに移動している場合
   docker-compose ps
   docker-compose logs -f
   
   # プロジェクトルートから実行する場合
   docker-compose -f docker/docker-compose.yml ps
   docker-compose -f docker/docker-compose.yml logs -f
   ```

4. **動作確認**
   ```bash
   # テスト用FQDNにHTTPリクエストを送信
   curl -H "Host: test.example.com" http://localhost/
   
   # ヘルスチェック
   curl -H "Host: test.example.com" http://localhost/health
   ```

## 注意事項

### OpenAppSec Attachment Moduleについて

現在の`nginx.conf`では、OpenAppSec Attachment Moduleの読み込みがコメントアウトされています。
これは、標準のNginxイメージにはOpenAppSecモジュールが含まれていないためです。

**次のステップ**:
- OpenAppSecモジュールを含むカスタムNginxイメージを作成する
- または、OpenAppSec公式のNginxイメージを使用する

### 共有メモリ設定について

現在の`nginx.conf`では、共有メモリゾーンの設定もコメントアウトされています。
これは、Attachment Moduleが読み込まれていないためです。

**次のステップ**:
- Attachment Moduleを読み込んだ後、共有メモリ設定を有効化する

### OpenAppSec設定について

`local_policy.yaml`は基本的な設定のみです。
実際の運用では、設定取得エージェント（Phase 3で実装）が自動生成します。

## トラブルシューティング

### コンテナが起動しない

```bash
# dockerディレクトリに移動している場合
docker-compose logs
docker-compose restart

# プロジェクトルートから実行する場合
docker-compose -f docker/docker-compose.yml logs
docker-compose -f docker/docker-compose.yml restart
```

### Nginx設定エラー

```bash
# dockerディレクトリに移動している場合
docker-compose exec nginx nginx -t

# プロジェクトルートから実行する場合
docker-compose -f docker/docker-compose.yml exec nginx nginx -t
```

### OpenAppSec Agentが起動しない

```bash
# dockerディレクトリに移動している場合
docker-compose logs openappsec-agent
docker-compose exec openappsec-agent cat /etc/openappsec/local_policy.yaml

# プロジェクトルートから実行する場合
docker-compose -f docker/docker-compose.yml logs openappsec-agent
docker-compose -f docker/docker-compose.yml exec openappsec-agent cat /etc/openappsec/local_policy.yaml
```

## 次のステップ

Phase 1の実装が完了したら、以下を実施してください：

1. **動作確認**: 単一FQDNでのHTTPリクエスト処理を確認
2. **ログ確認**: NginxとOpenAppSec Agentのログを確認
3. **Phase 2へ**: 複数FQDN対応の実装に進む
