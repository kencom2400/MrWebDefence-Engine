# Task 5.4: RateLimit機能実装 実装設計書

## 概要

本ドキュメントは、Task 5.4: RateLimit機能実装の実装設計を定義します。
設計書（`MWD-38-openappsec-integration.md`）とJIRA Issue（MWD-41）に基づいて、OpenAppSecのRateLimit機能を実装します。

## 参照設計書

- **詳細設計**: `docs/design/MWD-38-openappsec-integration.md`
- **タスクレビュー**: `docs/design/MWD-38-task-review.md`
- **OpenAppSec設定リファレンス**: `docs/design/OPENAPPSEC-CONFIGURATION-REFERENCE.md`
- **要件定義**: `MrWebDefence-Design/docs/REQUIREMENT.md`（参照）
- **仕様書**: `MrWebDefence-Design/docs/SPECIFICATION.md`（参照）
- **詳細設計**: `MrWebDefence-Design/docs/DESIGN.md`（参照）

## JIRA Issue情報

- **Issueキー**: MWD-41
- **タイトル**: Task 5.4: RateLimit機能実装
- **親タスク**: MWD-5 (Epic 5: WAFエンジン基盤実装)
- **優先度**: Medium

### Issue説明

**なぜやるか**
リクエストレート制限を実装し、DDoS攻撃や過剰なリクエストを防御する必要がある。

**何をやるか（概要）**
- Redis連携実装
- スライディングウィンドウアルゴリズム実装
- IPアドレス単位のレート制限実装
- エンドポイント単位のレート制限実装
- 分散環境対応（Redis使用）

**受け入れ条件**
- [ ] Redis連携が正常に動作する
- [ ] スライディングウィンドウアルゴリズムが正常に動作する
- [ ] IPアドレス単位のレート制限が正常に動作する
- [ ] エンドポイント単位のレート制限が正常に動作する
- [ ] 分散環境で正常に動作する

## 実装方針

### 1. OpenAppSecのRateLimit機能を使用

Issueの説明では「Redis連携実装」「スライディングウィンドウアルゴリズム実装」と記載されていますが、OpenAppSecのRateLimit機能は内部でレート制限を処理するため、追加のRedis連携は不要です。

OpenAppSecのRateLimit機能の特徴：
- **内部処理**: OpenAppSec Agentがレート制限を内部で処理
- **分散環境対応**: OpenAppSec Agentが複数インスタンス間で状態を共有（共有メモリを使用）
- **スライディングウィンドウ**: OpenAppSecが内部でスライディングウィンドウアルゴリズムを実装
- **IPアドレス単位**: ソースIPアドレス単位でレート制限を適用
- **エンドポイント単位**: URIパターン単位でレート制限を適用

### 2. Redisコンテナの追加

将来の拡張性を考慮して、Redisコンテナを追加します。現在はOpenAppSecのRateLimit機能を使用しますが、将来的にカスタムのRateLimit実装が必要になった場合に備えて、Redisコンテナを準備します。

### 3. 設定ファイル生成の拡張

`policy-generator.sh`を拡張して、`accessControlPractices`の生成を追加します。

## 既存実装状況の確認

### ✅ Task 5.1, 5.2で実装済みの機能

#### 1. ポリシー生成スクリプト（`config-agent/lib/policy-generator.sh`）
- ✅ JSONデータから`local_policy.yaml`を生成
- ✅ `specificRules`の動的生成
- ✅ v1beta2スキーマ準拠
- ✅ デフォルトモードとFQDN別モードの対応
- ⚠️ **accessControlPracticesの生成** - 未実装（本タスクで実装）

#### 2. Docker Compose構成（`docker/docker-compose.yml`）
- ✅ Nginx、OpenAppSec Agent、ConfigAgentの基本構成
- ✅ 共有メモリボリュームの設定
- ⚠️ **Redisコンテナ** - 未追加（本タスクで追加）

#### 3. 管理APIレスポンス形式
- ✅ FQDN別設定の取得
- ⚠️ **access_control_practiceフィールド** - 未対応（本タスクで対応）

## 実装詳細

### 1. OpenAppSecのRateLimit設定

#### 1.1 accessControlPracticesの定義

OpenAppSecの`local_policy.yaml`に`accessControlPractices`を追加します。

```yaml
accessControlPractices:
  - name: rate-limit-default
    practiceMode: prevent
    rateLimit:
      overrideMode: prevent
      rules:
        - uri: "/"
          limit: 100
          unit: minute
          action: prevent
          comment: "全エンドポイントのレート制限（Community Edition制限により1ルールのみ）"
```

**注意**: OpenAppSec Community Editionでは、**1つのルールのみサポートされています**。複数のルールを定義しても、最初の1つだけが有効になります。そのため、全エンドポイント（`uri: "/"`）に適用する1つのルールに統合しています。

#### 1.2 RateLimitルールの設定項目

| フィールド | 型 | 必須 | 説明 | 可能な値 / デフォルト |
|---|---|---|---|---|
| `uri` | string | オプション | 適用するURIパターン | 例: `/api/*`, `/login` |
| `limit` | integer | **必須** | リクエスト数の制限 | - |
| `unit` | string | オプション | 時間単位 | `second`, `minute`<br>**デフォルト**: `minute` |
| `action` | string | オプション | 制限超過時のアクション | `inherited`, `prevent`, `detect`<br>**デフォルト**: `inherited` |
| `comment` | string | オプション | 人間が読むためのコメント | - |

#### 1.3 スライディングウィンドウアルゴリズム

OpenAppSecのRateLimit機能は、内部でスライディングウィンドウアルゴリズムを実装しています。追加の実装は不要です。

#### 1.4 IPアドレス単位のレート制限

OpenAppSecのRateLimit機能は、デフォルトでソースIPアドレス単位でレート制限を適用します。追加の実装は不要です。

#### 1.5 エンドポイント単位のレート制限

OpenAppSecのRateLimit機能は、URIパターン単位でレート制限を適用できます。`uri`フィールドで指定します。

#### 1.6 分散環境対応

OpenAppSecのRateLimit機能は、複数のOpenAppSec Agentインスタンス間で状態を共有します。共有メモリを使用して、分散環境でも正常に動作します。

### 2. policy-generator.shの拡張

#### 2.1 accessControlPracticesの生成

`policy-generator.sh`を拡張して、`accessControlPractices`の生成を追加します。

**実装内容**:
1. APIレスポンスから`access_control_practice`フィールドを取得
2. `accessControlPractices`の使用判定
3. `accessControlPractices`の定義をYAMLに追加

**実装箇所**:
- `config-agent/lib/policy-generator.sh`の`generate_openappsec_policy()`関数

#### 2.2 実装詳細

```bash
# FQDN別設定（specificRules）を生成
specific_rules_json=$(echo "$config_data" | jq -r '.fqdns[]? | select(.is_active == true) | {
    host: .fqdn,
    mode: (.waf_mode // "detect-learn"),
    customResponse: (.custom_response // 403),
    accessControlPractice: (.access_control_practice // "rate-limit-default")
}' | jq -s '.')

# accessControlPracticesの使用判定
local use_access_control="false"
if echo "$specific_rules_json" | jq -e '.[] | select(.accessControlPractice != null and .accessControlPractice != "")' >/dev/null 2>&1; then
    use_access_control="true"
fi

# accessControlPracticesの生成
local default_access_control="[]"
if [ "$use_access_control" = "true" ]; then
    default_access_control="[rate-limit-default]"
fi
```

#### 2.3 YAML生成時のaccessControlPracticesの追加

`use_threat_prevention`が`true`の場合と`false`の場合の両方で、`accessControlPractices`を追加します。

**use_threat_preventionがtrueの場合**:
```yaml
policies:
  default:
    mode: ${default_mode}
    threatPreventionPractices: [threat-prevention-basic]
    accessControlPractices: ${default_access_control}
    triggers: [log-trigger-basic]
    ...
```

**use_threat_preventionがfalseの場合**:
```yaml
policies:
  default:
    mode: ${default_mode}
    threatPreventionPractices: []
    accessControlPractices: ${default_access_control}
    triggers: []
    ...
```

#### 2.4 accessControlPractices定義の追加

`use_access_control`が`true`の場合、`accessControlPractices`の定義をYAMLに追加します。

```yaml
# アクセス制御プラクティス定義
accessControlPractices:
  - name: rate-limit-default
    practiceMode: inherited
    rateLimit:
      overrideMode: inherited
      rules:
        - uri: "/login"
          limit: 10
          unit: minute
          action: prevent
          comment: "ログイン試行のレート制限"
        - uri: "/api/*"
          limit: 100
          unit: minute
          action: detect
          comment: "API呼び出しのレート制限"
```

### 3. Redisコンテナの追加

#### 3.1 docker-compose.ymlへの追加

`docker/docker-compose.yml`にRedisコンテナを追加します。

```yaml
  redis:
    # Redis（RateLimit機能用）
    image: redis:7-alpine
    platform: linux/amd64
    container_name: mwd-redis
    volumes:
      # Redisデータの永続化（オプション）
      - redis-data:/data
    ports:
      - "6379:6379"
    networks:
      - mwd-network
    command: redis-server --appendonly yes
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

#### 3.2 Redisボリュームの追加

```yaml
volumes:
  ...
  # Redisデータの永続化
  redis-data:
    driver: local
```

#### 3.3 Nginxコンテナの依存関係の追加

NginxコンテナがRedisコンテナに依存するように設定します（将来の拡張用）。

```yaml
  nginx:
    ...
    depends_on:
      - openappsec-agent
      - redis
```

### 4. 管理APIレスポンス形式の拡張

#### 4.1 access_control_practiceフィールドの追加

管理APIのレスポンスに`access_control_practice`フィールドを追加します。

**レスポンス例**:
```json
{
  "version": "1.0.0-20240101-120000",
  "default_mode": "detect-learn",
  "fqdns": [
    {
      "fqdn": "example1.com",
      "is_active": true,
      "backend_host": "backend1",
      "backend_port": 3000,
      "waf_mode": "prevent-learn",
      "threat_prevention_practice": "webapp-strict-practice",
      "access_control_practice": "rate-limit-strict",
      "log_trigger": "example1-log-trigger",
      "custom_response": "example1-block-response"
    }
  ]
}
```

#### 4.2 access_control_practiceの値

- `rate-limit-default`: デフォルトのRateLimit設定
- `rate-limit-strict`: 厳格なRateLimit設定
- `rate-limit-relaxed`: 緩いRateLimit設定
- カンマ区切りで複数のプラクティスを指定可能（例: `rate-limit-default,rate-limit-api`）

### 5. 実装ファイル一覧

#### 5.1 変更ファイル

1. **config-agent/lib/policy-generator.sh**
   - `accessControlPractices`の生成を追加
   - APIレスポンスから`access_control_practice`を取得
   - `accessControlPractices`の定義をYAMLに追加

2. **docker/docker-compose.yml**
   - Redisコンテナの追加
   - Redisボリュームの追加
   - Nginxコンテナの依存関係の追加

#### 5.2 新規ファイル

なし（既存ファイルの拡張のみ）

## 実装フェーズ

### Phase 1: OpenAppSecのRateLimit設定の実装（完了）

#### 1.1 policy-generator.shの拡張

**実装内容**:
- [x] `accessControlPractices`の使用判定を追加
- [x] APIレスポンスから`access_control_practice`を取得
- [x] `accessControlPractices`の生成を追加
- [x] `accessControlPractices`の定義をYAMLに追加

**実装箇所**:
- `config-agent/lib/policy-generator.sh`

**成果物**:
- 更新された`policy-generator.sh`

#### 1.2 accessControlPractices定義の追加

**実装内容**:
- [x] `rate-limit-default`プラクティスの定義を追加
- [x] デフォルトのRateLimitルールを定義

**実装箇所**:
- `config-agent/lib/policy-generator.sh`のYAML生成部分

**成果物**:
- `accessControlPractices`定義を含む`local_policy.yaml`

### Phase 2: Redisコンテナの追加（完了）

#### 2.1 docker-compose.ymlへの追加

**実装内容**:
- [x] Redisコンテナの定義を追加
- [x] Redisボリュームの追加
- [x] Nginxコンテナの依存関係の追加

**実装箇所**:
- `docker/docker-compose.yml`

**成果物**:
- 更新された`docker-compose.yml`

### Phase 3: テストと動作確認（実施中）

#### 3.1 基本動作確認

**テスト項目**:
- [x] `accessControlPractices`が正しく生成される
- [x] `rate-limit-default`プラクティスが正しく定義される
- [ ] Redisコンテナが正常に起動する（オプション、将来の拡張用）
- [x] OpenAppSec AgentがRateLimit設定を正しく読み込む

**テスト手順**:
1. Docker Composeでサービスを起動
2. 設定取得エージェントが`local_policy.yaml`を生成
3. `accessControlPractices`が含まれていることを確認
4. OpenAppSec Agentのログを確認
5. RateLimitが正常に動作することを確認

#### 3.2 RateLimit機能のテスト

**テスト項目**:
- [ ] `/login`エンドポイントへのレート制限が正常に動作する
- [ ] `/api/*`エンドポイントへのレート制限が正常に動作する
- [ ] 制限超過時に正しいレスポンスが返される
- [ ] IPアドレス単位でレート制限が適用される

**テスト手順**:
1. レート制限を超えるリクエストを送信
2. 制限超過時のレスポンスを確認
3. 異なるIPアドレスからのリクエストでレート制限が個別に適用されることを確認

#### 3.3 分散環境でのテスト

**テスト項目**:
- [ ] 複数のOpenAppSec Agentインスタンス間でレート制限が正常に動作する
- [ ] 共有メモリを使用して状態が共有される

**テスト手順**:
1. 複数のOpenAppSec Agentインスタンスを起動
2. 各インスタンスからレート制限を超えるリクエストを送信
3. レート制限が正常に適用されることを確認

## 受け入れ条件

### 必須条件

- [x] `accessControlPractices`が正しく生成される
- [x] `rate-limit-default`プラクティスが正しく定義される
- [ ] Redisコンテナが正常に起動する（オプション、将来の拡張用）
- [x] OpenAppSec AgentがRateLimit設定を正しく読み込む
- [ ] `/login`エンドポイントへのレート制限が正常に動作する（確認中）
- [ ] `/api/*`エンドポイントへのレート制限が正常に動作する（確認中）
- [ ] 制限超過時に正しいレスポンスが返される（確認中）
- [ ] IPアドレス単位でレート制限が適用される（確認中）

### オプション条件

- [ ] 複数のOpenAppSec Agentインスタンス間でレート制限が正常に動作する
- [ ] カスタムのRateLimitルールを追加できる
- [ ] RateLimit設定を動的に更新できる

## 技術的な詳細

### 1. OpenAppSecのRateLimit機能

#### 1.1 アルゴリズム

OpenAppSecのRateLimit機能は、内部でスライディングウィンドウアルゴリズムを実装しています。

**スライディングウィンドウアルゴリズム**:
- 時間窓をスライドさせながら、リクエスト数をカウント
- より正確なレート制限が可能
- 固定ウィンドウアルゴリズムよりも公平

#### 1.2 分散環境対応

OpenAppSecのRateLimit機能は、共有メモリを使用して複数のOpenAppSec Agentインスタンス間で状態を共有します。

**共有メモリ**:
- NginxとOpenAppSec Agent間のIPC通信に使用
- 複数のOpenAppSec Agentインスタンス間で状態を共有
- 分散環境でも正常に動作

#### 1.3 IPアドレス単位のレート制限

OpenAppSecのRateLimit機能は、デフォルトでソースIPアドレス単位でレート制限を適用します。

**ソースIPアドレスの取得**:
- `$remote_addr`変数から取得
- `X-Forwarded-For`ヘッダーも考慮（設定により）

#### 1.4 エンドポイント単位のレート制限

OpenAppSecのRateLimit機能は、URIパターン単位でレート制限を適用できます。

**URIパターン**:
- 完全一致: `/login`
- ワイルドカード: `/api/*`
- 正規表現: `/api/v[0-9]+/.*`

### 2. Redisコンテナ

#### 2.1 用途

現在はOpenAppSecのRateLimit機能を使用しますが、将来的にカスタムのRateLimit実装が必要になった場合に備えて、Redisコンテナを準備します。

**将来の拡張性**:
- カスタムのRateLimit実装
- 外部システムとの連携
- レート制限の統計情報の保存

#### 2.2 設定

**永続化**:
- `appendonly yes`: AOF（Append Only File）を有効化
- データの永続化を保証

**ネットワーク**:
- `mwd-network`に接続
- 他のコンテナからアクセス可能

### 3. 設定ファイル生成

#### 3.1 生成フロー

```
管理APIレスポンス
  ↓
access_control_practiceフィールドの取得
  ↓
accessControlPracticesの使用判定
  ↓
accessControlPracticesの生成
  ↓
YAMLファイルの生成
  ↓
accessControlPractices定義の追加
  ↓
local_policy.yamlの完成
```

#### 3.2 エラーハンドリング

**エラーケース**:
- `access_control_practice`フィールドが存在しない場合: デフォルト値（`rate-limit-default`）を使用
- `access_control_practice`が空の場合: `accessControlPractices`を使用しない
- YAML生成エラー: エラーログを出力し、処理を中断

## リスクと対策

### リスク1: OpenAppSecのRateLimit機能の理解不足

**影響**: RateLimit設定が正しく動作しない

**対策**:
- OpenAppSec公式ドキュメントを詳細に確認
- 小規模な設定から段階的に拡張
- 動作確認を頻繁に実施

### リスク2: 管理APIレスポンス形式の変更

**影響**: `access_control_practice`フィールドが取得できない

**対策**:
- デフォルト値（`rate-limit-default`）を使用
- エラーハンドリングを適切に実装
- ログを詳細に出力

### リスク3: 分散環境での動作確認不足

**影響**: 複数のOpenAppSec Agentインスタンス間でレート制限が正常に動作しない

**対策**:
- 複数のインスタンスでテストを実施
- 共有メモリの使用状況を確認
- ログを詳細に確認

## 次のステップ

1. **テストと動作確認**: Phase 3のテストを実施
2. **ドキュメント更新**: 実装完了後にドキュメントを更新
3. **受け入れ条件の確認**: すべての受け入れ条件を満たしていることを確認

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [OpenAppSec設定リファレンス](./OPENAPPSEC-CONFIGURATION-REFERENCE.md)
- [OpenAppSec統合設計](./MWD-38-openappsec-integration.md)
