# Task 5.1: OpenAppSec統合 実装完了

## 概要

Task 5.1「OpenAppSec統合」の実装が完了しました。このドキュメントでは、実装内容と使用方法を説明します。

## 実装完了フェーズ

- ✅ **Phase 1**: 基盤構築
- ✅ **Phase 2**: 複数FQDN対応
- ✅ **Phase 3**: 設定取得エージェントの実装
- ✅ **Phase 4**: スクリプト実装
- ✅ **Phase 5**: 統合テスト・検証

## クイックスタート

### 1. インストール

```bash
# プロジェクトのルートディレクトリで実行してください
./scripts/openappsec/install.sh
```

### 2. 全サービスを起動

```bash
# 方法1: サービス管理スクリプトを使用（推奨）
./scripts/openappsec/start.sh

# 方法2: 直接docker-composeを使用
cd docker
docker-compose up -d
```

### 3. 動作確認

```bash
# 統合テスト（推奨：すべての確認を一度に実行）
./scripts/openappsec/test-integration.sh

# ヘルスチェック
./scripts/openappsec/health-check.sh

# 個別テスト
./scripts/openappsec/test-phase1.sh  # Phase 1: 基盤構築
./scripts/openappsec/test-phase2.sh  # Phase 2: 複数FQDN対応
./scripts/openappsec/test-phase3.sh  # Phase 3: 設定取得エージェント
```

詳細な動作確認手順は `docs/QUICK-START.md` を参照してください。

### 簡易動作確認

```bash
# 簡易動作確認スクリプト（推奨）
./scripts/openappsec/verify-operation.sh
```

## 構成

### コンテナ

- **nginx**: OpenAppSec公式のNginxイメージ（Attachment Module組み込み）
- **openappsec-agent**: OpenAppSec公式のAgentイメージ
- **config-agent**: 設定取得エージェント（オプション）
- **mock-api**: モックAPIサーバー（動作確認用）

### ディレクトリ構造

```
docker/
├── docker-compose.yml          # Docker Compose構成
├── nginx/
│   ├── nginx.conf              # Nginx基本設定
│   └── conf.d/                 # FQDN別設定（自動生成）
└── openappsec/
    └── local_policy.yaml        # OpenAppSec設定（自動生成）

config-agent/
├── config-agent.sh              # メインスクリプト
└── lib/
    ├── api-client.sh            # APIクライアント
    ├── policy-generator.sh      # ポリシー生成
    ├── nginx-config-generator.sh # Nginx設定生成
    └── config-generator.sh      # 統合スクリプト

scripts/openappsec/
├── install.sh                   # インストールスクリプト
├── service.sh                   # サービス管理スクリプト（メイン）
├── start.sh                     # サービス起動（ショートカット）
├── stop.sh                      # サービス停止（ショートカット）
├── restart.sh                   # サービス再起動（ショートカット）
├── status.sh                    # サービス状態表示（ショートカット）
├── logs.sh                      # ログ表示（ショートカット）
├── health-check.sh              # ヘルスチェック
├── start-config-agent.sh        # ConfigAgent起動スクリプト
├── test-phase1.sh              # Phase 1動作確認
├── test-phase2.sh              # Phase 2動作確認
├── test-phase3.sh              # Phase 3動作確認
└── test-integration.sh          # 統合テスト
```

## 使用方法

### サービス管理

```bash
# 全サービスを起動
./scripts/openappsec/start.sh

# 全サービスを停止
./scripts/openappsec/stop.sh

# 全サービスを再起動
./scripts/openappsec/restart.sh

# サービス状態を確認
./scripts/openappsec/status.sh

# ログを表示（最新50行）
./scripts/openappsec/logs.sh

# ログをリアルタイム表示
./scripts/openappsec/logs.sh -f

# 特定のサービスのみ操作
./scripts/openappsec/start.sh nginx
./scripts/openappsec/stop.sh config-agent
./scripts/openappsec/logs.sh nginx openappsec-agent

# 詳細な使用方法
./scripts/openappsec/service.sh help
```

### 基本動作（ConfigAgentなし）

1. 手動で設定ファイルを編集
2. サービスを再起動

```bash
# 設定ファイルを編集
vim docker/openappsec/local_policy.yaml
vim docker/nginx/conf.d/test.example.com.conf

# サービスを再起動
./scripts/openappsec/restart.sh nginx openappsec-agent
```

### 動的設定更新（ConfigAgent使用）

1. 環境変数を設定

```bash
export CONFIG_API_URL="http://mock-api:8080"  # または本番APIのURL
export CONFIG_API_TOKEN="your-api-token"
```

2. ConfigAgentを起動

```bash
./scripts/openappsec/start-config-agent.sh start
```

3. 設定変更は自動的に反映されます（最大5分待機）

## テスト用FQDN

以下のFQDNが設定済みです：

- `test.example.com`
- `example1.com`
- `example2.com`
- `example3.com`

### テスト方法

```bash
# ヘルスチェック
curl -H "Host: test.example.com" http://localhost/health

# 通常のリクエスト
curl -H "Host: test.example.com" http://localhost/
```

## 本番環境への移行

### 1. 管理APIの実装

Task 4.6で実装される管理APIを使用する場合：

```bash
export CONFIG_API_URL="http://your-api-server:8080"
export CONFIG_API_TOKEN="your-production-token"
```

### 2. モックAPIサーバーの削除

本番環境では、`docker-compose.yml`から`mock-api`サービスを削除するか、環境変数で無効化してください。

### 3. セキュリティ設定

- APIトークンの適切な管理
- Dockerソケットのマウント方法の見直し（必要に応じて）

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

# 設定ファイルの確認
docker-compose exec openappsec-agent cat /ext/appsec/local_policy.yaml
```

### ConfigAgentが動作しない

```bash
# ConfigAgentのログを確認
docker-compose logs config-agent

# API接続をテスト
docker-compose exec config-agent /app/config-agent/config-agent.sh test
```

## 参考資料

- 実装計画: `docs/design/MWD-38-implementation-plan.md`
- 実装サマリー: `docs/design/IMPLEMENTATION-SUMMARY.md`
- Phase 1完了報告: `docs/design/PHASE1-COMPLETION.md`
- Phase 5完了報告: `docs/design/PHASE5-COMPLETION.md`
- Docker README: `docker/README.md`

## 次のステップ

1. **Task 4.6の実装**: 管理APIの実装が完了したら、モックAPIを本番APIに置き換え
2. **パフォーマンステスト**: 複数FQDN同時アクセスの処理確認
3. **エラーケースのテスト**: 各種エラーケースでの動作確認
4. **セキュリティ強化**: APIトークン管理、Dockerソケットの見直し
