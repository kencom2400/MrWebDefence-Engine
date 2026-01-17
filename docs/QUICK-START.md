# クイックスタートガイド

## 動作確認手順

### 1. サービス起動

```bash
# 全サービスを起動
./scripts/openappsec/start.sh

# または個別に起動
cd docker
docker-compose up -d
```

### 2. サービス状態確認

```bash
# サービス状態を確認
./scripts/openappsec/status.sh

# または
cd docker
docker-compose ps
```

### 3. ヘルスチェック

```bash
# ヘルスチェックスクリプトを実行
./scripts/openappsec/health-check.sh

# JSON形式で出力
./scripts/openappsec/health-check.sh --json
```

### 4. 統合テストの実行

```bash
# 統合テスト（推奨）
./scripts/openappsec/test-integration.sh
```

このスクリプトは以下を確認します：
- 全コンテナの状態
- 各FQDNでのHTTPリクエスト処理
- OpenAppSec Agentのログ
- Nginxログ

### 5. 個別フェーズのテスト

```bash
# Phase 1: 基盤構築の確認
./scripts/openappsec/test-phase1.sh

# Phase 2: 複数FQDN対応の確認
./scripts/openappsec/test-phase2.sh

# Phase 3: 設定取得エージェントの確認
./scripts/openappsec/test-phase3.sh
```

## 手動動作確認

### 1. HTTPリクエストのテスト

```bash
# テスト用FQDNにHTTPリクエストを送信
curl -H "Host: test.example.com" http://localhost/health
curl -H "Host: test.example.com" http://localhost/

# 他のFQDNもテスト
curl -H "Host: example1.com" http://localhost/health
curl -H "Host: example2.com" http://localhost/health
curl -H "Host: example3.com" http://localhost/health
```

### 2. ログの確認

```bash
# 全サービスのログを表示
./scripts/openappsec/logs.sh

# リアルタイムでログを表示
./scripts/openappsec/logs.sh -f

# 特定のサービスのログ
./scripts/openappsec/logs.sh nginx
./scripts/openappsec/logs.sh openappsec-agent
./scripts/openappsec/logs.sh config-agent
```

### 3. 設定ファイルの確認

```bash
# OpenAppSec設定ファイル
cat docker/openappsec/local_policy.yaml

# Nginx設定ファイル
ls -la docker/nginx/conf.d/
cat docker/nginx/conf.d/test.example.com.conf
```

### 4. コンテナ内での確認

```bash
cd docker

# Nginx設定の構文チェック
docker-compose exec nginx nginx -t

# OpenAppSec Agentの設定ファイル確認
docker-compose exec openappsec-agent cat /ext/appsec/local_policy.yaml

# ConfigAgentの状態確認
docker-compose exec config-agent ps aux
```

## 動作確認チェックリスト

### 基本動作

- [ ] 全コンテナが起動している
- [ ] ヘルスチェックが成功する
- [ ] 各FQDNでHTTPリクエストが処理される
- [ ] Nginxログにアクセスログが記録される

### OpenAppSec統合

- [ ] OpenAppSec Agentが起動している
- [ ] OpenAppSec Agentのログにリクエストが記録される
- [ ] `local_policy.yaml`が正しく読み込まれている
- [ ] FQDN別の設定が適用されている

### 設定取得エージェント（オプション）

- [ ] ConfigAgentが起動している
- [ ] モックAPIサーバーから設定を取得できる
- [ ] 設定ファイルが自動生成される
- [ ] 設定変更時に自動更新される

## トラブルシューティング

### コンテナが起動しない

```bash
# ログを確認
./scripts/openappsec/logs.sh

# コンテナを再起動
./scripts/openappsec/restart.sh
```

### HTTPリクエストが失敗する

```bash
# Nginx設定を確認
docker-compose exec nginx nginx -t

# Nginxログを確認
./scripts/openappsec/logs.sh nginx
```

### OpenAppSec Agentが動作しない

```bash
# OpenAppSec Agentのログを確認
./scripts/openappsec/logs.sh openappsec-agent

# 設定ファイルを確認
docker-compose exec openappsec-agent cat /ext/appsec/local_policy.yaml
```

### ConfigAgentが動作しない

```bash
# ConfigAgentのログを確認
./scripts/openappsec/logs.sh config-agent

# API接続をテスト
docker-compose exec config-agent /app/config-agent/config-agent.sh test
```

## 次のステップ

動作確認が完了したら：

1. **本番環境への移行準備**
   - Task 4.6の管理API実装を待つ
   - モックAPIを本番APIに置き換え

2. **パフォーマンステスト**
   - 複数FQDN同時アクセスの処理確認
   - 共有メモリの使用量確認

3. **セキュリティ設定**
   - APIトークンの適切な管理
   - Dockerソケットのマウント方法の見直し
