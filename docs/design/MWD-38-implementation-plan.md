# Task 5.1: OpenAppSec統合 実装計画

## 概要

本ドキュメントは、Task 5.1: OpenAppSec統合の実装計画を定義します。
設計書（`MWD-38-openappsec-integration.md`）に基づいて、段階的な実装手順を詳細化します。

## 実装方針

1. **段階的実装**: 最小構成から始めて、機能を段階的に追加
2. **依存関係の明確化**: 他のタスク（Task 5.0, 5.2等）との依存関係を考慮
3. **テスト駆動**: 各フェーズで動作確認を実施
4. **ドキュメント更新**: 実装と並行してドキュメントを更新

## 実装フェーズ

### Phase 0: 前提条件の確認（1日）

**目的**: 実装に必要な前提条件を確認・準備

**タスク**:
- [ ] Task 5.0（Docker Compose構成実装）の完了確認
- [ ] 管理API（Task 4.6）の実装状況確認
- [ ] 開発環境の準備（Docker、docker-compose、jq、curl）
- [ ] OpenAppSec公式ドキュメントの確認
- [ ] 設計書の最終確認

**成果物**:
- 前提条件チェックリスト
- 開発環境セットアップガイド

**依存関係**:
- Task 5.0: Docker Compose構成実装（完了必須）

---

### Phase 1: 基盤構築（3-5日）

**目的**: 最小構成でOpenAppSecとNginxを統合

#### 1.1 ディレクトリ構造の作成（0.5日）

```bash
mkdir -p docker/nginx/conf.d
mkdir -p docker/openappsec
mkdir -p config-agent/lib
mkdir -p config-agent/config
mkdir -p scripts/openappsec
```

**成果物**:
- ディレクトリ構造

#### 1.2 Docker Composeファイルの作成（1日）

**実装内容**:
- `docker/docker-compose.yml` の作成
- Nginx、OpenAppSec Agent、ConfigAgentの基本構成
- 共有メモリボリュームの設定
- ネットワーク設定

**実装手順**:
1. Task 5.0で作成された`docker-compose.yml`をベースに拡張
2. OpenAppSec Agentコンテナの追加
3. ConfigAgentコンテナの追加（初期は動作確認用の最小構成）
4. 共有メモリボリューム（`nginx-shm`）の設定
5. ネットワーク設定（`mwd-network`）

**成果物**:
- `docker/docker-compose.yml`

**テスト**:
- [ ] `docker-compose up -d` で全コンテナが起動する
- [ ] コンテナ間の通信が正常に動作する
- [ ] 共有メモリボリュームが正常にマウントされる

#### 1.3 Nginx基本設定の作成（1日）

**実装内容**:
- `docker/nginx/nginx.conf` の作成
- Attachment Moduleの読み込み設定
- 共有メモリゾーンの設定
- 基本的なHTTP設定

**実装手順**:
1. Nginx基本設定ファイルの作成
2. Attachment Moduleの読み込み設定
   ```nginx
   load_module /usr/lib/nginx/modules/ngx_cp_attachment_module.so;
   ```
3. 共有メモリゾーンの設定
   ```nginx
   openappsec_shared_memory_zone zone=openappsec:10m;
   ```
4. HTTPブロックの基本設定
5. ログ設定（アクセスログ、エラーログ）

**成果物**:
- `docker/nginx/nginx.conf`

**テスト**:
- [ ] Nginxコンテナが正常に起動する
- [ ] Attachment Moduleが正常に読み込まれている（`nginx -V`で確認）
- [ ] 共有メモリゾーンが正常に設定されている（ログで確認）

#### 1.4 OpenAppSec基本設定の作成（0.5日）

**実装内容**:
- `docker/openappsec/local_policy.yaml` の基本設定
- デフォルトポリシーの設定
- 最小限のWAF設定

**実装手順**:
1. OpenAppSec公式ドキュメントを参考に基本設定を作成
2. デフォルトポリシーの設定（`detect-learn`モード）
3. 基本的なWAF設定
4. YAML構文の検証

**成果物**:
- `docker/openappsec/local_policy.yaml`（初期版）

**テスト**:
- [ ] OpenAppSec Agentコンテナが正常に起動する
- [ ] `local_policy.yaml`が正常に読み込まれている（ログで確認）
- [ ] YAML構文エラーがない

#### 1.5 単一FQDNでの動作確認（1日）

**実装内容**:
- 1つのFQDN（例: `test.example.com`）で動作確認
- 手動でNginx設定ファイルを作成
- 基本的なHTTPリクエストのテスト

**実装手順**:
1. `docker/nginx/conf.d/test.example.com.conf` を手動作成
2. バーチャルホスト設定（`server_name`、`proxy_pass`）
3. Attachment Moduleの設定
4. Docker Composeで起動
5. テスト用HTTPリクエストの送信
6. ログの確認

**成果物**:
- `docker/nginx/conf.d/test.example.com.conf`（手動作成版）
- 動作確認レポート

**テスト**:
- [ ] HTTPリクエストが正常に処理される
- [ ] OpenAppSec Agentがリクエストを検知している（ログで確認）
- [ ] 共有メモリ経由で通信が行われている（ログで確認）

---

### Phase 2: 複数FQDN対応（2-3日）

**目的**: 複数のFQDNを扱えるように拡張

#### 2.1 複数FQDNのNginx設定（1日）

**実装内容**:
- 複数のFQDN設定ファイルの作成
- 各FQDNごとのバーチャルホスト設定
- Attachment Moduleの設定（各FQDN共通）

**実装手順**:
1. 2-3個のFQDN設定ファイルを作成（手動）
2. 各FQDNの`server_name`設定
3. 各FQDNの`proxy_pass`設定（異なるバックエンド）
4. Attachment Moduleの設定（各FQDN共通）
5. Nginx設定のリロード

**成果物**:
- `docker/nginx/conf.d/*.conf`（複数ファイル）

**テスト**:
- [ ] 複数のFQDNでHTTPリクエストが正常に処理される
- [ ] 各FQDNが正しいバックエンドにプロキシされている
- [ ] OpenAppSec Agentが各FQDNのリクエストを検知している

#### 2.2 OpenAppSecのFQDN別設定（1-2日）

**実装内容**:
- `local_policy.yaml`に`specificRules`を追加
- 各FQDNごとのWAF設定
- `host`フィールドによるFQDN識別

**実装手順**:
1. OpenAppSec公式ドキュメントで`specificRules`の仕様を確認
2. `local_policy.yaml`に`specificRules`セクションを追加
3. 各FQDNの設定を追加（`host`、`mode`、`practices`）
4. YAML構文の検証
5. OpenAppSec Agentの設定リロード

**成果物**:
- `docker/openappsec/local_policy.yaml`（複数FQDN対応版）

**テスト**:
- [ ] 各FQDNで異なるWAF設定が適用されている
- [ ] `host`フィールドでFQDNが正しく識別されている
- [ ] FQDN別のWAFログが出力されている

---

### Phase 3: 設定取得エージェントの実装（5-7日）

**目的**: 管理APIから設定を取得して動的に更新

**依存関係**:
- Task 4.6: WAFエンジン向け設定配信API実装（完了必須、またはモックAPI）

#### 3.1 APIクライアントの実装（1-2日）

**実装内容**:
- `config-agent/lib/api-client.sh` の実装
- 管理APIへのHTTPリクエスト
- APIトークン認証
- エラーハンドリング

**実装手順**:
1. `api-client.sh`の基本構造を作成
2. `curl`を使用したHTTPリクエスト実装
3. APIトークン認証（`Authorization: Bearer <token>`）
4. レスポンスのJSON解析（`jq`使用）
5. エラーハンドリング（リトライロジック、指数バックオフ）
6. ログ出力

**成果物**:
- `config-agent/lib/api-client.sh`

**テスト**:
- [ ] 管理APIから設定を正常に取得できる
- [ ] APIトークン認証が正常に動作する
- [ ] エラー時のリトライが正常に動作する
- [ ] ログが適切に出力される

#### 3.2 ポリシー生成スクリプトの実装（2日）

**実装内容**:
- `config-agent/lib/policy-generator.sh` の実装
- JSONデータから`local_policy.yaml`を生成
- `specificRules`の動的生成
- YAML形式への変換

**実装手順**:
1. `policy-generator.sh`の基本構造を作成
2. JSONデータの解析（`jq`使用）
3. デフォルトポリシーの生成
4. 各FQDNの`specificRules`エントリの生成
5. YAML形式への変換（`jq` + テンプレート）
6. ファイルへの書き込み
7. YAML構文の検証

**成果物**:
- `config-agent/lib/policy-generator.sh`

**テスト**:
- [ ] JSONデータから正しい`local_policy.yaml`が生成される
- [ ] 複数のFQDN設定が正しく変換される
- [ ] YAML構文エラーがない
- [ ] OpenAppSec Agentが生成された設定を読み込める

#### 3.3 Nginx設定生成スクリプトの実装（1-2日）

**実装内容**:
- `config-agent/lib/nginx-config-generator.sh` の実装
- JSONデータからNginx設定ファイルを生成
- FQDN別の設定ファイル生成
- 無効化されたFQDNの設定ファイル削除

**実装手順**:
1. `nginx-config-generator.sh`の基本構造を作成
2. JSONデータの解析（`jq`使用）
3. 各FQDNのNginx設定ファイル生成（`conf.d/{fqdn}.conf`）
4. バーチャルホスト設定の生成
5. Attachment Module設定の追加
6. 無効化されたFQDNの設定ファイル削除
7. Nginx設定の検証（`nginx -t`相当）

**成果物**:
- `config-agent/lib/nginx-config-generator.sh`

**テスト**:
- [ ] JSONデータから正しいNginx設定ファイルが生成される
- [ ] 複数のFQDN設定ファイルが正しく生成される
- [ ] 無効化されたFQDNの設定ファイルが削除される
- [ ] 生成された設定でNginxが正常に起動する

#### 3.4 メインスクリプトの実装（1-2日）

**実装内容**:
- `config-agent/config-agent.sh` の実装
- ポーリングループ
- 設定のバージョン管理
- キャッシュ機能
- 設定リロード機能

**実装手順**:
1. `config-agent.sh`の基本構造を作成
2. 環境変数の読み込み（`CONFIG_API_URL`、`CONFIG_API_TOKEN`等）
3. ポーリングループの実装（デフォルト5分間隔）
4. キャッシュ機能の実装（TTL: 5分）
5. バージョン管理の実装（バージョン番号の比較）
6. 設定ファイル生成の呼び出し
7. OpenAppSec Agent設定リロード
8. Nginx設定リロード（`nginx -s reload`）
9. エラーハンドリング
10. ログ出力

**成果物**:
- `config-agent/config-agent.sh`

**テスト**:
- [ ] ポーリングが正常に動作する（5分間隔）
- [ ] 設定変更時に設定ファイルが更新される
- [ ] バージョン管理が正常に動作する（変更がない場合はスキップ）
- [ ] キャッシュが正常に動作する
- [ ] OpenAppSec AgentとNginxの設定リロードが正常に動作する

---

### Phase 4: スクリプト実装（2-3日）

**目的**: 運用・管理用スクリプトの実装

#### 4.1 インストールスクリプトの実装（1日）

**実装内容**:
- `scripts/openappsec/install.sh` の実装
- 依存関係の確認
- 設定ファイルの検証
- Docker Composeでのサービス起動

**実装手順**:
1. `install.sh`の基本構造を作成
2. 依存関係の確認（Docker、docker-compose、jq、curl）
3. ディレクトリ構造の作成
4. 設定ファイルの検証
5. 環境変数の確認
6. Docker Composeでのサービス起動
7. 起動確認

**成果物**:
- `scripts/openappsec/install.sh`

**テスト**:
- [ ] インストールスクリプトが正常に動作する
- [ ] 依存関係の確認が正常に動作する
- [ ] 設定ファイルの検証が正常に動作する
- [ ] サービスが正常に起動する

#### 4.2 ヘルスチェックスクリプトの実装（0.5-1日）

**実装内容**:
- `scripts/openappsec/health-check.sh` の実装
- Nginx状態チェック
- OpenAppSec Agent状態チェック
- ConfigAgent状態チェック
- 設定ファイルの存在確認

**実装手順**:
1. `health-check.sh`の基本構造を作成
2. Nginx状態チェック（プロセス確認、ポート確認）
3. OpenAppSec Agent状態チェック（プロセス確認、ログ確認）
4. ConfigAgent状態チェック（プロセス確認、ログ確認）
5. 設定ファイルの存在確認
6. 結果の出力（JSON形式）

**成果物**:
- `scripts/openappsec/health-check.sh`

**テスト**:
- [ ] 各コンポーネントの状態チェックが正常に動作する
- [ ] 設定ファイルの存在確認が正常に動作する
- [ ] 結果が正しく出力される

#### 4.3 起動スクリプトの実装（0.5-1日）

**実装内容**:
- `scripts/openappsec/start-config-agent.sh` の実装
- ConfigAgentの起動
- 環境変数の設定確認
- エラーハンドリング

**実装手順**:
1. `start-config-agent.sh`の基本構造を作成
2. 環境変数の設定確認（`CONFIG_API_URL`、`CONFIG_API_TOKEN`）
3. ConfigAgentの起動
4. エラーハンドリング
5. ログ出力

**成果物**:
- `scripts/openappsec/start-config-agent.sh`

**テスト**:
- [ ] ConfigAgentが正常に起動する
- [ ] 環境変数の確認が正常に動作する
- [ ] エラーハンドリングが正常に動作する

---

### Phase 5: 統合テスト・検証（3-5日）

**目的**: 全体の動作確認とパフォーマンステスト

#### 5.1 基本動作確認（1-2日）

**テスト項目**:
- [ ] 複数FQDNでのHTTPリクエスト処理
- [ ] FQDN別WAF設定の適用
- [ ] 設定変更時の動的更新
- [ ] 設定取得エージェントのポーリング
- [ ] OpenAppSec Agentの設定リロード
- [ ] Nginxの設定リロード

**テスト手順**:
1. 3-5個のFQDNを設定
2. 各FQDNで異なるWAF設定を適用
3. HTTPリクエストを送信して動作確認
4. 管理APIで設定を変更
5. 設定変更が反映されることを確認（最大5分待機）
6. ログを確認

#### 5.2 パフォーマンステスト（1-2日）

**テスト項目**:
- [ ] 複数FQDN同時アクセスの処理
- [ ] 共有メモリの使用量確認
- [ ] 設定更新時のパフォーマンス影響
- [ ] ポーリング間隔の調整

**テスト手順**:
1. 10-20個のFQDNを設定
2. 同時にHTTPリクエストを送信
3. レスポンス時間を測定
4. 共有メモリの使用量を確認
5. 設定更新時の影響を測定

#### 5.3 エラーケースのテスト（1日）

**テスト項目**:
- [ ] 管理API接続エラー時の動作
- [ ] 設定ファイル生成エラー時の動作
- [ ] OpenAppSec Agent停止時の動作
- [ ] Nginx設定エラー時の動作

**テスト手順**:
1. 各エラーケースを意図的に発生
2. エラーハンドリングが正常に動作することを確認
3. ログを確認
4. 復旧処理を確認

---

## 実装順序と依存関係

```
Phase 0: 前提条件の確認
  ↓
Phase 1: 基盤構築
  ├─ 1.1 ディレクトリ構造の作成
  ├─ 1.2 Docker Composeファイルの作成
  ├─ 1.3 Nginx基本設定の作成
  ├─ 1.4 OpenAppSec基本設定の作成
  └─ 1.5 単一FQDNでの動作確認
  ↓
Phase 2: 複数FQDN対応
  ├─ 2.1 複数FQDNのNginx設定
  └─ 2.2 OpenAppSecのFQDN別設定
  ↓
Phase 3: 設定取得エージェントの実装
  ├─ 3.1 APIクライアントの実装（Task 4.6に依存）
  ├─ 3.2 ポリシー生成スクリプトの実装
  ├─ 3.3 Nginx設定生成スクリプトの実装
  └─ 3.4 メインスクリプトの実装
  ↓
Phase 4: スクリプト実装
  ├─ 4.1 インストールスクリプトの実装
  ├─ 4.2 ヘルスチェックスクリプトの実装
  └─ 4.3 起動スクリプトの実装
  ↓
Phase 5: 統合テスト・検証
  ├─ 5.1 基本動作確認
  ├─ 5.2 パフォーマンステスト
  └─ 5.3 エラーケースのテスト
```

## リスクと対策

### リスク1: 管理API（Task 4.6）の実装遅延

**影響**: Phase 3の実装が遅延

**対策**:
- モックAPIを用意してPhase 3を先行実装可能にする
- Task 4.6の実装状況を定期的に確認

### リスク2: OpenAppSecの設定形式の理解不足

**影響**: 設定ファイルの生成が正しく動作しない

**対策**:
- 公式ドキュメントを事前に詳細に確認
- 小規模な設定から段階的に拡張
- 動作確認を頻繁に実施

### リスク3: 共有メモリの設定エラー

**影響**: NginxとOpenAppSec Agentの通信ができない

**対策**:
- 公式ドキュメントの設定例を参考
- ログを詳細に確認
- 段階的に設定を追加

### リスク4: 複数FQDN対応の複雑さ

**影響**: 設定ファイルの生成ロジックが複雑になる

**対策**:
- 1つのFQDNから始めて段階的に拡張
- テンプレート機能を活用
- テストを頻繁に実施

## 受け入れ条件の確認

実装完了時に、以下の受け入れ条件をすべて満たすこと：

- [ ] OpenAppSecが正常にインストールされている
- [ ] Nginxと正常に統合されている
- [ ] Nginx Attachment Moduleが正常に読み込まれている
- [ ] 共有メモリゾーンが正常に設定されている
- [ ] 複数FQDN対応のバーチャルホスト設定が正常に動作する
- [ ] `docker/nginx/nginx.conf`が完成している
- [ ] 設定ファイルの動的更新が正常に動作する
- [ ] 設定のバージョン管理が正常に動作する

## 次のステップ

1. Phase 0の開始（前提条件の確認）
2. Task 5.0の完了確認
3. Task 4.6の実装状況確認
4. Phase 1の実装開始
