# Task 5.2: 設定取得・動的更新機能実装 完了

## 概要

Task 5.2「設定取得・動的更新機能実装」の実装が完了しました。このドキュメントでは、実装内容と使用方法を説明します。

## 実装完了フェーズ

- ✅ **Phase 0**: 現状確認と前提条件の確認
- ✅ **Phase 1**: 既存実装の動作確認とテスト
- ✅ **Phase 2**: エラーハンドリングの強化
- ✅ **Phase 3**: 設定検証機能の実装
- ✅ **Phase 4**: ログ・監視機能の強化
- ✅ **Phase 5**: ドキュメント更新と最終確認

## 実装内容

### Phase 2: エラーハンドリングの強化

#### 2.1 ネットワークエラーの詳細化

- curlエラーの詳細ログ出力
- 接続タイムアウトの明示的な処理
- HTTPステータスコードの詳細な分類とエラーメッセージ
- サーバーエラー（5xx）のリトライ処理の改善

#### 2.2 JSONパースエラーの検出とログ出力

- JSON形式の検証を強化
- jqエラーの詳細ログ出力
- 無効なJSONデータの早期検出

#### 2.3 設定ファイル生成失敗時の詳細ログ

- YAML構文エラーの詳細ログ
- Nginx設定ファイル生成エラーの詳細ログ
- ファイル書き込みエラーの検出

#### 2.4 リロード失敗時の詳細ログ

- Nginxリロードエラーの詳細ログ
- OpenAppSec Agentリロード状態の確認

### Phase 3: 設定検証機能の実装

#### 3.1 設定データの検証機能

**実装ファイル**: `config-agent/lib/config-validator.sh`

**検証項目**:
- 必須フィールドの存在確認（`version`, `fqdns`）
- FQDN形式の検証（正規表現による形式チェック、長さチェック）
- ポート番号の範囲チェック（1-65535）
- WAFモード値の検証（detect-learn, prevent, prevent-learn等）
- カスタムレスポンスコードの検証（400-599）
- バックエンド設定の妥当性確認

**使用方法**:
```bash
# config-agent.sh内で自動的に呼び出されます
validate_config_data "$config_data"
```

### Phase 4: ログ・監視機能の強化

#### 4.1 ログ出力の詳細化

**ログレベル**:
- `DEBUG`: デバッグ情報（詳細な処理フロー）
- `INFO`: 通常の情報（デフォルト）
- `WARN`: 警告
- `ERROR`: エラー

**環境変数**:
```bash
export LOG_LEVEL="DEBUG"  # DEBUG, INFO, WARN, ERROR
```

**ログ出力の改善**:
- タイムスタンプ付きログ
- ログレベルの明示
- エラー発生時のスタックトレース（DEBUGモード時）

#### 4.2 エラー統計の記録

- 連続エラー回数の記録
- 成功回数の記録
- 最後のエラー発生時刻の記録
- 処理時間の記録

## クイックスタート

### 1. 前提条件

Task 5.1の実装が完了していることを確認してください。

```bash
# サービスが起動していることを確認
./scripts/openappsec/status.sh
```

### 2. 環境変数の設定

```bash
# 管理APIのURLとトークンを設定
export CONFIG_API_URL="http://mock-api:8080"  # または本番APIのURL
export CONFIG_API_TOKEN="test-token"  # または本番APIトークン

# ログレベルを設定（オプション）
export LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
```

### 3. ConfigAgentの起動

```bash
# ConfigAgentを起動
./scripts/openappsec/start-config-agent.sh start

# ログを確認
./scripts/openappsec/start-config-agent.sh logs

# ステータスを確認
./scripts/openappsec/start-config-agent.sh status
```

### 4. 動作確認

```bash
# API接続テスト
docker exec mwd-config-agent /app/config-agent/config-agent.sh test

# 設定ファイルの生成を確認
ls -la docker/openappsec/local_policy.yaml
ls -la docker/nginx/conf.d/*.conf
```

## 構成

### 新規追加ファイル

```
config-agent/
└── lib/
    └── config-validator.sh      # 設定検証スクリプト（新規）
```

### 更新ファイル

```
config-agent/
├── config-agent.sh              # メインスクリプト（エラーハンドリング、ログ機能強化）
└── lib/
    ├── api-client.sh            # APIクライアント（ネットワークエラー処理強化）
    ├── policy-generator.sh      # ポリシー生成（JSON検証、エラーハンドリング強化）
    └── nginx-config-generator.sh # Nginx設定生成（エラーハンドリング強化）
```

## 使用方法

### 基本動作

1. 環境変数を設定
2. ConfigAgentを起動
3. 設定変更は自動的に反映されます（最大5分待機）

```bash
# 環境変数を設定
export CONFIG_API_URL="http://mock-api:8080"
export CONFIG_API_TOKEN="test-token"

# ConfigAgentを起動
./scripts/openappsec/start-config-agent.sh start

# ログをリアルタイム表示
./scripts/openappsec/start-config-agent.sh logs -f
```

### ログレベルの変更

```bash
# DEBUGモードで起動（詳細なログを出力）
export LOG_LEVEL="DEBUG"
./scripts/openappsec/start-config-agent.sh restart

# WARNモードで起動（警告とエラーのみ出力）
export LOG_LEVEL="WARN"
./scripts/openappsec/start-config-agent.sh restart
```

### 設定検証の確認

設定データの検証は、ConfigAgentが自動的に実行します。検証エラーが発生した場合、ログに詳細が出力されます。

```bash
# ConfigAgentのログを確認
./scripts/openappsec/start-config-agent.sh logs | grep -i "検証\|validation"
```

## エラーハンドリング

### ネットワークエラー

- **接続タイムアウト**: 10秒でタイムアウト
- **リクエストタイムアウト**: 30秒でタイムアウト
- **リトライ**: 指数バックオフ（5秒、10秒、20秒、40秒、80秒）
- **最大リトライ回数**: 5回

### JSONパースエラー

- JSON形式の検証を自動実行
- エラー詳細をログに出力
- 無効なJSONデータはスキップしてリトライ

### 設定検証エラー

- 必須フィールドの欠如
- 無効なFQDN形式
- 範囲外のポート番号
- 無効なWAFモード値

検証エラーが発生した場合、設定ファイルの生成はスキップされ、次のポーリングサイクルで再試行されます。

### 設定ファイル生成エラー

- YAML構文エラー: 詳細なエラーメッセージをログに出力
- Nginx設定エラー: ファイル書き込みエラーの詳細をログに出力
- ディスク容量不足: エラーログ出力してスキップ

## トラブルシューティング

### ConfigAgentが起動しない

```bash
# ログを確認
docker logs mwd-config-agent

# 環境変数を確認
docker exec mwd-config-agent env | grep CONFIG_API

# API接続をテスト
docker exec mwd-config-agent /app/config-agent/config-agent.sh test
```

### 設定検証エラーが発生する

```bash
# ログを確認（検証エラーの詳細）
docker logs mwd-config-agent | grep -i "検証\|validation\|エラー"

# 設定データの形式を確認
curl -H "Authorization: Bearer test-token" http://localhost:8080/engine/v1/config | jq .
```

### 設定ファイルが生成されない

```bash
# ConfigAgentのログを確認
docker logs mwd-config-agent | tail -50

# 設定データの取得を確認
docker exec mwd-config-agent /app/config-agent/config-agent.sh test

# 出力ディレクトリを確認
docker exec mwd-config-agent ls -la /app/output/
```

### ログが出力されない

```bash
# ログレベルを確認
docker exec mwd-config-agent env | grep LOG_LEVEL

# DEBUGモードで再起動
export LOG_LEVEL="DEBUG"
./scripts/openappsec/start-config-agent.sh restart
```

## 本番環境への移行

### 1. 管理APIの実装

Task 4.6で実装される管理APIを使用する場合：

```bash
export CONFIG_API_URL="http://your-api-server:8080"
export CONFIG_API_TOKEN="your-production-token"
```

### 2. ログレベルの設定

本番環境では、`INFO`または`WARN`レベルを推奨します。

```bash
export LOG_LEVEL="INFO"
```

### 3. セキュリティ設定

- APIトークンの適切な管理
- ログファイルの適切な管理（機密情報の漏洩防止）
- エラーログの監視とアラート設定

## 参考資料

- 実装設計書: `docs/design/MWD-39-implementation-plan.md`
- 実装サマリー: `docs/design/IMPLEMENTATION-SUMMARY.md`
- Task 5.1完了報告: `README-TASK-5-1.md`
- Docker README: `docker/README.md`

## 次のステップ

1. **Task 4.6の実装**: 管理APIの実装が完了したら、モックAPIを本番APIに置き換え
2. **パフォーマンステスト**: 複数FQDN同時アクセスの処理確認
3. **エラーケースのテスト**: 各種エラーケースでの動作確認
4. **監視・アラート**: エラー統計の監視とアラート設定
5. **メトリクス収集**: オプション機能としてメトリクス収集の実装
