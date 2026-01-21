# Task 5.2: 設定取得・動的更新機能実装 実装設計書

## 概要

本ドキュメントは、Task 5.2: 設定取得・動的更新機能実装の実装設計を定義します。
設計書（`MWD-38-openappsec-integration.md`）とJIRA Issue（MWD-39）に基づいて、段階的な実装手順を詳細化します。

## 参照設計書

- **詳細設計**: `docs/design/MWD-38-openappsec-integration.md`
- **タスクレビュー**: `docs/design/MWD-38-task-review.md`
- **要件定義**: `MrWebDefence-Design/docs/REQUIREMENT.md`（参照）
- **仕様書**: `MrWebDefence-Design/docs/SPECIFICATION.md`（参照）
- **詳細設計**: `MrWebDefence-Design/docs/DESIGN.md`（参照）

## JIRA Issue情報

- **Issueキー**: MWD-39
- **タイトル**: Task 5.2: 設定取得・動的更新機能実装
- **親タスク**: MWD-5 (Epic 5: WAFエンジン基盤実装)
- **優先度**: Medium

### Issue説明

**なぜやるか**
管理APIから設定を取得し、動的に更新する機能が必要。

**何をやるか（概要）**
- 管理APIから設定取得機能実装（ポーリング、デフォルト5分間隔）
- API呼び出し失敗時のリトライロジック
- OpenAppSec設定ファイル生成機能実装
- Nginx設定ファイル生成機能実装（FQDN別）
- 無効化されたFQDNの設定ファイル削除機能
- 設定ファイルリロード機能実装（再起動不要）
- 設定のローカルキャッシュ機能実装（TTL: 5分）
- 設定取得エージェント起動スクリプト実装

## 実装方針

1. **既存実装の確認**: Task 5.1で実装済みの機能を確認し、不足部分を補完
2. **段階的実装**: 最小構成から始めて、機能を段階的に追加
3. **テスト駆動**: 各フェーズで動作確認を実施
4. **ドキュメント更新**: 実装と並行してドキュメントを更新

## 既存実装状況の確認

### ✅ Task 5.1で実装済みの機能

Task 5.1のPhase 3で、設定取得エージェントの基本機能が実装済みです：

#### 1. APIクライアント（`config-agent/lib/api-client.sh`）
- ✅ 管理APIへのHTTPリクエスト
- ✅ APIトークン認証
- ✅ **リトライロジック（指数バックオフ）** - 実装済み
  - 最大5回のリトライ
  - 指数バックオフ（5秒、10秒、20秒、40秒、80秒）
  - HTTPステータスコードの適切な処理

#### 2. ポリシー生成スクリプト（`config-agent/lib/policy-generator.sh`）
- ✅ JSONデータから`local_policy.yaml`を生成
- ✅ `specificRules`の動的生成
- ✅ v1beta2スキーマ準拠
- ✅ デフォルトモードとFQDN別モードの対応

#### 3. Nginx設定生成スクリプト（`config-agent/lib/nginx-config-generator.sh`）
- ✅ JSONデータからNginx設定ファイルを生成
- ✅ **FQDN別設定ファイルの生成** - 実装済み
- ✅ **無効化されたFQDNの設定ファイル削除** - 実装済み
- ✅ バックエンド設定（proxy_pass）の自動生成

#### 4. 設定ファイル生成統合スクリプト（`config-agent/lib/config-generator.sh`）
- ✅ OpenAppSec設定とNginx設定の統合生成

#### 5. メインスクリプト（`config-agent/config-agent.sh`）
- ✅ 管理APIから設定取得機能（ポーリング、デフォルト5分間隔）
- ✅ 設定のローカルキャッシュ機能（TTL: 5分）
- ✅ バージョン管理による変更検知
- ✅ 設定ファイルリロード機能（再起動不要）
  - OpenAppSec Agent: ファイル変更の自動検知
  - Nginx: Dockerソケットまたはシグナルファイル方式

#### 6. 起動スクリプト（`scripts/openappsec/start-config-agent.sh`）
- ✅ 設定取得エージェント起動スクリプト - 実装済み
- ✅ 起動・停止・再起動・状態確認・ログ表示機能

### ⚠️ 確認・改善が必要な項目

1. **エラーハンドリングの強化**
   - 現在のリトライロジックは実装済みだが、エラーケースの網羅性を確認
   - ネットワークエラー、タイムアウト、JSONパースエラーなどの処理

2. **設定ファイル生成の堅牢性**
   - YAML構文エラーの検証
   - Nginx設定ファイルの構文チェック
   - 生成前のバックアップ機能

3. **ログ・監視機能**
   - 詳細なログ出力
   - エラー発生時のアラート機能
   - メトリクス収集（オプション）

4. **設定の検証**
   - 取得した設定データの妥当性検証
   - 必須フィールドの存在確認
   - 値の範囲チェック

## 実装フェーズ

### Phase 0: 現状確認と前提条件の確認（0.5日）

**目的**: 既存実装の確認と、実装に必要な前提条件の確認

**タスク**:
- [ ] Task 5.1の実装状況確認（Phase 3の実装内容）
- [ ] 既存スクリプトの動作確認
- [ ] 管理API（Task 4.6）の実装状況確認
- [ ] モックAPIサーバーの動作確認
- [ ] 開発環境の準備（Docker、docker-compose、jq、curl、yq（オプション））

**成果物**:
- 既存実装状況の確認結果
- 前提条件チェックリスト

**依存関係**:
- Task 5.0: Docker Compose構成実装（完了必須）
- Task 5.1: OpenAppSec統合（Phase 3まで完了必須）

---

### Phase 1: 既存実装の動作確認とテスト（1日）

**目的**: Task 5.1で実装された機能が正しく動作することを確認

#### 1.1 既存スクリプトの動作確認

**確認項目**:
- [ ] `config-agent.sh`が正常に起動する
- [ ] APIクライアントが正常に動作する（モックAPIを使用）
- [ ] 設定ファイル生成が正常に動作する
- [ ] 設定リロードが正常に動作する

**検証方法**:
```bash
# モックAPIサーバーを起動
cd docker
docker-compose up -d mock-api

# 環境変数を設定
export CONFIG_API_URL=http://mock-api:8080
export CONFIG_API_TOKEN=test-token

# ConfigAgentを起動
./scripts/openappsec/start-config-agent.sh start

# ログを確認
docker-compose logs -f config-agent
```

#### 1.2 統合テストの実施

**確認項目**:
- [ ] 設定取得からファイル生成までの一連の流れが正常に動作する
- [ ] 複数FQDNの設定が正しく生成される
- [ ] 無効化されたFQDNの設定ファイルが削除される
- [ ] 設定変更時にNginxとOpenAppSec Agentが正常にリロードされる

**成果物**:
- 動作確認結果レポート
- 発見された問題点のリスト

---

### Phase 2: エラーハンドリングの強化（1-2日）

**目的**: エラーケースの処理を強化し、堅牢性を向上させる

#### 2.1 APIクライアントのエラーハンドリング強化

**実装内容**:
- [ ] ネットワークエラーの詳細な処理
- [ ] タイムアウトエラーの処理
- [ ] JSONパースエラーの処理
- [ ] 不正なレスポンス形式の検出

**実装場所**:
- `config-agent/lib/api-client.sh`

**実装例**:
```bash
# タイムアウト設定の追加
curl --max-time 30 --connect-timeout 10 ...

# JSONパースエラーの検出
if ! echo "$response_body" | jq -e . >/dev/null 2>&1; then
    log_error "JSONパースエラー: レスポンスが有効なJSONではありません"
    return 1
fi
```

#### 2.2 設定ファイル生成のエラーハンドリング

**実装内容**:
- [ ] 設定ファイル生成前のバックアップ機能
- [ ] YAML構文エラーの検証強化
- [ ] Nginx設定ファイルの構文チェック
- [ ] 生成失敗時のロールバック機能

**実装場所**:
- `config-agent/lib/policy-generator.sh`
- `config-agent/lib/nginx-config-generator.sh`
- `config-agent/lib/config-generator.sh`

**実装例**:
```bash
# バックアップ機能
backup_config_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Nginx設定の構文チェック
validate_nginx_config() {
    local config_file="$1"
    if docker exec mwd-nginx nginx -t -c "$config_file" >/dev/null 2>&1; then
        return 0
    else
        log_error "Nginx設定ファイルの構文エラー: $config_file"
        return 1
    fi
}
```

#### 2.3 メインループのエラーハンドリング強化

**実装内容**:
- [ ] 連続エラー時の処理（最大リトライ回数、エスカレーション）
- [ ] エラー発生時の詳細ログ出力
- [ ] エラー統計の記録

**実装場所**:
- `config-agent/config-agent.sh`

---

### Phase 3: 設定検証機能の実装（1日）

**目的**: 取得した設定データの妥当性を検証する機能を実装

#### 3.1 設定データの検証機能

**実装内容**:
- [ ] 必須フィールドの存在確認
  - `version`: バージョン番号（必須）
  - `fqdns`: FQDNリスト（必須）
- [ ] 値の範囲チェック
  - FQDNの形式検証
  - ポート番号の範囲チェック（1-65535）
  - モード値の検証（detect-learn, prevent, prevent-learn等）
- [ ] データ整合性の確認
  - アクティブなFQDNの存在確認
  - バックエンド設定の妥当性

**実装場所**:
- `config-agent/lib/config-validator.sh`（新規作成）

**実装例**:
```bash
# 設定データの検証
validate_config_data() {
    local config_data="$1"
    
    # 必須フィールドの確認
    if ! echo "$config_data" | jq -e '.version' >/dev/null 2>&1; then
        log_error "バージョン番号が存在しません"
        return 1
    fi
    
    if ! echo "$config_data" | jq -e '.fqdns' >/dev/null 2>&1; then
        log_error "FQDNリストが存在しません"
        return 1
    fi
    
    # FQDNの形式検証
    local invalid_fqdns
    invalid_fqdns=$(echo "$config_data" | jq -r '.fqdns[]? | select(.fqdn | test("^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$") | not) | .fqdn')
    
    if [ -n "$invalid_fqdns" ]; then
        log_error "無効なFQDN形式: $invalid_fqdns"
        return 1
    fi
    
    return 0
}
```

#### 3.2 メインループへの統合

**実装内容**:
- [ ] 設定取得後に検証を実行
- [ ] 検証失敗時のエラーハンドリング
- [ ] 検証結果のログ出力

---

### Phase 4: ログ・監視機能の強化（1日）

**目的**: 詳細なログ出力と監視機能を実装

#### 4.1 ログ出力の詳細化

**実装内容**:
- [ ] ログレベルの設定（INFO, WARNING, ERROR）
- [ ] 構造化ログの出力（JSON形式、オプション）
- [ ] ログローテーション設定
- [ ] エラー発生時のスタックトレース出力

**実装場所**:
- `config-agent/config-agent.sh`（ログ関数の拡張）

#### 4.2 メトリクス収集（オプション）

**実装内容**:
- [ ] 設定取得回数の記録
- [ ] エラー発生回数の記録
- [ ] 設定更新回数の記録
- [ ] 処理時間の記録

**実装場所**:
- `config-agent/lib/metrics.sh`（新規作成、オプション）

---

### Phase 5: ドキュメント更新と最終確認（0.5日）

**目的**: 実装内容をドキュメント化し、最終確認を実施

#### 5.1 ドキュメント更新

**更新内容**:
- [ ] `README-TASK-5-2.md`の作成
- [ ] 使用方法の説明
- [ ] トラブルシューティングガイド
- [ ] API仕様の確認

#### 5.2 最終確認

**確認項目**:
- [ ] すべての機能が正常に動作する
- [ ] エラーハンドリングが適切に実装されている
- [ ] ドキュメントが最新の状態である
- [ ] 受け入れ条件を満たしている

---

## 実装詳細

### 1. ディレクトリ構造

```
config-agent/
├── config-agent.sh              # メインスクリプト（既存）
├── lib/
│   ├── api-client.sh            # APIクライアント（既存、強化）
│   ├── config-generator.sh      # 設定ファイル生成統合（既存）
│   ├── nginx-config-generator.sh # Nginx設定生成（既存）
│   ├── policy-generator.sh      # OpenAppSecポリシー生成（既存）
│   ├── config-validator.sh      # 設定検証（新規）
│   └── metrics.sh               # メトリクス収集（新規、オプション）
└── Dockerfile                   # Dockerイメージ（既存）

scripts/openappsec/
├── start-config-agent.sh        # 起動スクリプト（既存）
└── ...
```

### 2. 環境変数

| 環境変数 | 説明 | デフォルト値 | 必須 |
|---------|------|------------|------|
| `CONFIG_API_URL` | 管理APIのURL | `http://mock-api:8080` | いいえ |
| `CONFIG_API_TOKEN` | APIトークン | - | **はい** |
| `POLLING_INTERVAL` | ポーリング間隔（秒） | `300`（5分） | いいえ |
| `CACHE_TTL` | キャッシュTTL（秒） | `300`（5分） | いいえ |
| `OUTPUT_DIR` | 出力ディレクトリ | `/app/output` | いいえ |
| `NGINX_CONTAINER_NAME` | Nginxコンテナ名 | `mwd-nginx` | いいえ |
| `LOG_LEVEL` | ログレベル | `INFO` | いいえ |

### 3. 管理API仕様

#### エンドポイント: `GET /engine/v1/config`

**リクエスト**:
```http
GET /engine/v1/config HTTP/1.1
Host: config-api:8080
Authorization: Bearer <API_TOKEN>
Accept: application/json
```

**レスポンス（成功）**:
```json
{
  "version": "20250121-120000",
  "default_mode": "detect-learn",
  "default_custom_response": 403,
  "fqdns": [
    {
      "fqdn": "example1.com",
      "is_active": true,
      "waf_mode": "prevent",
      "custom_response": 403,
      "backend_host": "backend1.example.com",
      "backend_port": 8080,
      "backend_path": ""
    },
    {
      "fqdn": "example2.com",
      "is_active": true,
      "waf_mode": "detect-learn",
      "custom_response": 403,
      "backend_host": "backend2.example.com",
      "backend_port": 8080,
      "backend_path": "/api"
    }
  ]
}
```

**レスポンス（エラー）**:
```json
{
  "error": "Unauthorized",
  "message": "Invalid API token"
}
```

### 4. 設定ファイル生成仕様

#### 4.1 OpenAppSec設定ファイル（`local_policy.yaml`）

**生成ロジック**:
- デフォルトポリシー: `default_mode`を使用
- FQDN別設定: `specificRules`に各FQDNの設定を追加
- モードに応じた`threatPreventionPractices`の設定
- v1beta2スキーマ準拠

**生成場所**:
- `docker/openappsec/local_policy.yaml`

#### 4.2 Nginx設定ファイル（`conf.d/{fqdn}.conf`）

**生成ロジック**:
- アクティブなFQDNごとに設定ファイルを生成
- バックエンド設定（`proxy_pass`）の自動生成
- FQDN別のログ設定
- 無効化されたFQDNの設定ファイルは削除

**生成場所**:
- `docker/nginx/conf.d/{fqdn}.conf`

### 5. 設定リロード仕様

#### 5.1 OpenAppSec Agentのリロード

- ファイル変更を自動検知（約30秒で反映）
- 特別な操作は不要

#### 5.2 Nginxのリロード

**方法1: Dockerソケットがマウントされている場合**
```bash
docker exec mwd-nginx nginx -s reload
```

**方法2: Dockerソケットがマウントされていない場合（現在の実装）**
- シグナルファイル方式を使用
- `docker/nginx/conf.d/.reload_signal`を作成
- Nginxコンテナ内の`watch-config.sh`が監視してリロード

### 6. エラーハンドリング仕様

#### 6.1 API呼び出しエラー

- **ネットワークエラー**: 60秒待機してリトライ
- **認証エラー（401）**: リトライせずにエラー終了
- **エンドポイントエラー（404）**: リトライせずにエラー終了
- **サーバーエラー（5xx）**: 指数バックオフでリトライ（最大5回）

#### 6.2 設定ファイル生成エラー

- **YAML構文エラー**: バックアップから復元
- **Nginx設定エラー**: バックアップから復元
- **ディスク容量不足**: エラーログ出力してスキップ

#### 6.3 リロードエラー

- **Nginxリロード失敗**: 次のポーリングサイクルで再試行
- **OpenAppSec Agentリロード失敗**: ログ出力（自動検知のため通常は問題なし）

---

## 受け入れ条件

設計書（`MWD-38-task-review.md`）に基づく受け入れ条件:

- [ ] 管理APIから設定取得機能が正常に動作する（ポーリング、デフォルト5分間隔）
- [ ] API呼び出し失敗時のリトライロジック（指数バックオフ）が正常に動作する
- [ ] OpenAppSec設定ファイル生成機能が正常に動作する
- [ ] Nginx設定ファイル生成機能（FQDN別）が正常に動作する
- [ ] 無効化されたFQDNの設定ファイル削除機能が正常に動作する
- [ ] 設定ファイルリロード機能が正常に動作する（再起動不要）
- [ ] 設定のローカルキャッシュ機能が正常に動作する（TTL: 5分）
- [ ] 設定取得エージェント起動スクリプトが正常に動作する
- [ ] バージョン管理による変更検知が正常に動作する

---

## テスト計画

### 単体テスト

1. **APIクライアントのテスト**
   - 正常なレスポンスの処理
   - エラーレスポンスの処理
   - リトライロジックの動作確認

2. **設定ファイル生成のテスト**
   - OpenAppSec設定ファイルの生成
   - Nginx設定ファイルの生成
   - 無効化されたFQDNの削除

3. **設定検証のテスト**
   - 必須フィールドの検証
   - 値の範囲チェック
   - データ整合性の確認

### 統合テスト

1. **エンドツーエンドテスト**
   - モックAPIから設定取得
   - 設定ファイル生成
   - NginxとOpenAppSec Agentのリロード

2. **エラーケースのテスト**
   - API接続エラー
   - 不正な設定データ
   - 設定ファイル生成エラー

### 動作確認手順

```bash
# 1. モックAPIサーバーを起動
cd docker
docker-compose up -d mock-api

# 2. 環境変数を設定
export CONFIG_API_URL=http://mock-api:8080
export CONFIG_API_TOKEN=test-token

# 3. ConfigAgentを起動
./scripts/openappsec/start-config-agent.sh start

# 4. ログを確認
docker-compose logs -f config-agent

# 5. 設定ファイルの生成を確認
ls -la docker/openappsec/local_policy.yaml
ls -la docker/nginx/conf.d/*.conf

# 6. 設定変更のテスト（モックAPIの設定を変更）
# モックAPIサーバーの設定ファイルを編集して、設定を変更

# 7. 設定更新の確認
# ConfigAgentのログで設定更新を確認
# 設定ファイルの更新時刻を確認
```

---

## 依存関係

### 必須依存関係

- **Task 5.0**: Docker Compose構成実装（完了必須）
- **Task 5.1**: OpenAppSec統合（Phase 3まで完了必須）
- **管理API**: `GET /engine/v1/config`エンドポイント（Task 4.6、またはモックAPI）

### オプション依存関係

- **yq**: YAML構文検証（オプション、なくても動作する）

---

## 参考資料

- 設計書: `docs/design/MWD-38-openappsec-integration.md`
- タスクレビュー: `docs/design/MWD-38-task-review.md`
- Task 5.1実装サマリー: `docs/design/IMPLEMENTATION-SUMMARY.md`
- Task 5.1実装計画: `docs/design/MWD-38-implementation-plan.md`
- OpenAppSec設定リファレンス: `docs/design/OPENAPPSEC-CONFIGURATION-REFERENCE.md`

---

## 注意事項

1. **既存実装の活用**: Task 5.1で実装済みの機能を最大限活用する
2. **後方互換性**: 既存の動作に影響を与えないよう注意
3. **エラーハンドリング**: すべてのエラーケースを適切に処理する
4. **パフォーマンス**: 設定ファイル生成とリロードのパフォーマンスを考慮
5. **セキュリティ**: APIトークンの適切な管理
