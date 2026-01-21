# Task 5.0: Docker Compose構成実装 - タスクリスト

## 現状確認

### 実装済みの構成

#### コンテナ定義
- ✅ **nginx**: OpenAppSec公式のNginxイメージ（Attachment Module組み込み）
- ✅ **openappsec-agent**: OpenAppSec公式のAgentイメージ
- ✅ **config-agent**: 設定取得エージェント
- ✅ **mock-api**: モックAPIサーバー（動作確認用）

#### ボリューム設定
- ✅ **nginx-shm**: 共有メモリ用のtmpfsボリューム（NginxとOpenAppSec Agent間のIPC通信）
- ✅ **mock-api-config**: モックAPI設定ファイル用

#### ネットワーク設定
- ✅ **mwd-network**: ブリッジネットワーク（全コンテナ間の通信）

#### 環境変数設定
- ✅ **openappsec-agent**: `registered_server`, `autoPolicyLoad`, `OPENAPPSEC_LOG_LEVEL`
- ✅ **config-agent**: `CONFIG_API_URL`, `CONFIG_API_TOKEN`, `POLLING_INTERVAL`, `CACHE_TTL`
- ✅ **mock-api**: `MOCK_API_PORT`, `MOCK_API_CONFIG_FILE`

### 未コミットの変更
- 複数の設定ファイルが変更されている
- 新しいドキュメントファイルが追加されている

## 実施すべきタスク

### 1. 現状のdocker-compose.ymlの構成確認・検証
**目的**: 各コンテナの定義が要件を満たしているか確認

**確認項目**:
- [ ] Nginxコンテナの定義（Attachment Module読み込み対応）
- [ ] OpenAppSec Agentコンテナの定義
- [ ] ConfigAgentコンテナの定義
- [ ] Mock APIコンテナの定義
- [ ] 各コンテナの依存関係（depends_on）の確認

**検証方法**:
```bash
cd docker
docker-compose config --quiet  # 構文チェック
docker-compose config --services  # サービス一覧確認
```

### 2. 共有メモリボリューム（nginx-shm）の設定確認と動作検証
**目的**: 共有メモリボリュームが正しく設定され、正常にマウントされることを確認

**確認項目**:
- [ ] `nginx-shm`ボリュームの定義（tmpfsタイプ）
- [ ] Nginxコンテナでのマウントポイント（`/dev/shm/check-point`）
- [ ] OpenAppSec Agentコンテナでのマウントポイント（`/dev/shm/check-point`）
- [ ] IPC設定（`ipc: host`）の確認

**検証方法**:
```bash
cd docker
docker-compose up -d
docker-compose exec nginx ls -la /dev/shm/check-point
docker-compose exec openappsec-agent ls -la /dev/shm/check-point
```

### 3. ネットワーク設定（mwd-network）の確認とコンテナ間通信の検証
**目的**: ネットワークが正しく設定され、コンテナ間で通信できることを確認

**確認項目**:
- [ ] `mwd-network`ネットワークの定義（bridgeドライバー）
- [ ] 全コンテナが同じネットワークに接続されているか
- [ ] コンテナ間の名前解決（サービス名で通信可能か）

**検証方法**:
```bash
cd docker
docker-compose up -d
docker-compose exec nginx ping -c 1 openappsec-agent
docker-compose exec config-agent ping -c 1 mock-api
docker network inspect docker_mwd-network
```

### 4. 環境変数の設定確認
**目的**: 各コンテナの環境変数が正しく設定されているか確認

**確認項目**:
- [ ] OpenAppSec Agentの環境変数（`registered_server`, `autoPolicyLoad`, `OPENAPPSEC_LOG_LEVEL`）
- [ ] ConfigAgentの環境変数（`CONFIG_API_URL`, `CONFIG_API_TOKEN`, `POLLING_INTERVAL`, `CACHE_TTL`）
- [ ] Mock APIの環境変数（`MOCK_API_PORT`, `MOCK_API_CONFIG_FILE`）
- [ ] デフォルト値の確認

**検証方法**:
```bash
cd docker
docker-compose exec openappsec-agent env | grep -E "(registered_server|autoPolicyLoad|OPENAPPSEC_LOG_LEVEL)"
docker-compose exec config-agent env | grep -E "(CONFIG_API|POLLING|CACHE)"
docker-compose exec mock-api env | grep MOCK_API
```

### 5. Docker Composeで全コンテナが正常に起動することを確認
**目的**: 受け入れ条件の最重要項目 - 全コンテナが正常に起動することを確認

**確認項目**:
- [ ] 全コンテナが正常に起動する
- [ ] コンテナのヘルス状態が正常
- [ ] エラーログがない

**検証方法**:
```bash
cd docker
docker-compose up -d
docker-compose ps  # 全コンテナの状態確認
docker-compose logs --tail=50  # ログ確認
```

### 6. docker-compose.saas.ymlの確認
**目的**: SaaS管理UI対応版の構成が正しく設定されているか確認

**確認項目**:
- [ ] `docker-compose.saas.yml`の存在確認
- [ ] SaaS管理用の環境変数設定（`AGENT_TOKEN`, `user_email`, `autoPolicyLoad`）
- [ ] SaaS管理用のボリューム設定（`appsec-config`, `appsec-data`, `appsec-logs`）
- [ ] マージ動作の確認（`docker-compose -f docker-compose.yml -f docker-compose.saas.yml config`）

**検証方法**:
```bash
cd docker
docker-compose -f docker-compose.yml -f docker-compose.saas.yml config --quiet
```

### 7. Task 5.0専用のREADME.mdまたはドキュメントの作成・更新
**目的**: Task 5.0の実装内容と使用方法を文書化

**作成内容**:
- [ ] Task 5.0の概要説明
- [ ] Docker Compose構成の説明
- [ ] 各コンテナの役割説明
- [ ] 起動方法と動作確認手順
- [ ] トラブルシューティング

**ファイル**:
- `docker/README-TASK-5-0.md` または既存の`docker/README.md`を更新

### 8. 未コミットの変更の整理とレビュー
**目的**: Task 5.0に関連する変更のみをコミット対象にする

**確認項目**:
- [ ] 変更されたファイルの確認（`git status`）
- [ ] Task 5.0に関連する変更の特定
- [ ] 不要な変更の除外（Task 5.1など他のタスクの変更）
- [ ] 新規追加ファイルの確認

**確認方法**:
```bash
git status
git diff --stat
```

### 9. 受け入れ条件の最終確認と動作テストの実施
**目的**: すべての受け入れ条件を満たしていることを確認

**受け入れ条件**:
- [ ] Docker Composeで全コンテナが正常に起動する
- [ ] 共有メモリボリュームが正常にマウントされる
- [ ] コンテナ間の通信が正常に動作する
- [ ] 環境変数が正しく設定される

**テスト手順**:
```bash
# 1. 全コンテナの起動
cd docker
docker-compose up -d

# 2. コンテナ状態の確認
docker-compose ps

# 3. 共有メモリボリュームの確認
docker-compose exec nginx ls -la /dev/shm/check-point
docker-compose exec openappsec-agent ls -la /dev/shm/check-point

# 4. コンテナ間通信の確認
docker-compose exec nginx ping -c 1 openappsec-agent
docker-compose exec config-agent curl -s http://mock-api:8080/health

# 5. 環境変数の確認
docker-compose exec openappsec-agent env | grep -E "(registered_server|autoPolicyLoad)"
docker-compose exec config-agent env | grep CONFIG_API

# 6. ログの確認（エラーがないこと）
docker-compose logs --tail=100 | grep -i error
```

## 参考資料

- 設計書: `docs/design/MWD-38-task-review.md`（Task 5.0の要件定義）
- 実装計画: `docs/design/MWD-38-implementation-plan.md`（Task 5.1の実装計画、Task 5.0の依存関係）
- 既存のREADME: `docker/README.md`
- SaaS版README: `docker/README-SAAS.md`

## 注意事項

1. **Task 5.1との関係**: Task 5.1は既に完了しているが、Task 5.0は独立したタスクとして完了させる必要がある
2. **未コミットの変更**: Task 5.1の実装時に作成された変更が含まれている可能性があるため、整理が必要
3. **受け入れ条件**: 設計書（MWD-38-task-review.md）に記載されている受け入れ条件を満たす必要がある
