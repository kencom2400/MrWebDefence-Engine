# MWD-103: Task 5.7: インストール・セットアップスクリプト実装

## 概要

### 目的
開発者が簡単にOpenAppSec環境をセットアップできるインストールスクリプトを実装し、環境構築の自動化とエラーハンドリングを強化する。

### 関連情報
- **JIRA Issue**: MWD-103
- **親タスク**: MWD-5 (Epic 5: WAFエンジン基盤実装)
- **ブランチ**: feature/MWD-103-task-5-7
- **関連ドキュメント**: 
  - `docs/design/MWD-38-task-review.md`
  - `docker/README.md`

---

## 既存の状態分析

### 既存の`install.sh`
現在の`scripts/openappsec/install.sh`には基本的な機能が実装されているが、以下の問題がある：

#### 問題点
1. **環境変数設定の不足**
   - `.env`ファイルの作成・確認がない
   - 必須環境変数の設定ガイダンスが不足
   
2. **エラーハンドリングの不足**
   - Docker Composeの起動失敗時の詳細なエラー表示がない
   - ロールバック機能がない
   
3. **初期設定の不足**
   - ログディレクトリの作成がない
   - 初期ポリシーファイルの確認がない
   - サンプル設定ファイルのコピー機能がない
   
4. **検証機能の不足**
   - サービスの起動完了を待つ仕組みが不十分（単純なsleep 5）
   - 各サービスのヘルスチェックがない
   
5. **クリーンアップ機能の不足**
   - アンインストールスクリプトがない
   - 既存コンテナの確認・停止機能がない

### 現在のディレクトリ構造

```
/Users/kencom/github/MrWebDefence-Engine/
├── docker/
│   ├── docker-compose.yml          # メイン構成
│   ├── docker-compose.override.yml # 開発環境用オーバーライド
│   ├── docker-compose.saas.yml     # SaaS管理UI用
│   ├── .env.template               # 環境変数テンプレート
│   ├── README.md                   # 使用方法
│   ├── README-SAAS.md              # SaaS使用方法
│   ├── nginx/
│   │   ├── nginx.conf
│   │   ├── conf.d/
│   │   │   ├── .gitkeep
│   │   │   └── *.conf (サンプル)
│   │   └── logs/                   # ログ出力先
│   ├── openappsec/
│   │   ├── .gitkeep
│   │   ├── local_policy.yaml
│   │   └── logs/                   # ログ出力先
│   ├── fluentd/
│   └── health-api/
└── scripts/openappsec/
    └── install.sh                  # インストールスクリプト
```

---

## 実装計画

### 1. 環境変数設定機能

#### 1.1 `.env`ファイルの作成
```bash
# .envファイルの確認と作成
check_and_create_env_file() {
    local env_file="${DOCKER_DIR}/.env"
    local env_template="${DOCKER_DIR}/.env.template"
    
    if [ ! -f "$env_file" ]; then
        echo "⚠️  .envファイルが見つかりません"
        
        if [ -f "$env_template" ]; then
            echo "📝 .env.templateから.envファイルを作成します"
            cp "$env_template" "$env_file"
            echo "✅ .envファイルを作成しました: $env_file"
            echo ""
            echo "⚠️  重要: 以下の環境変数を設定してください:"
            echo "   - SaaS管理UIを使用する場合: APPSEC_AGENT_TOKEN"
            echo "   - ローカル管理の場合: 設定は不要（デフォルトで動作）"
            echo ""
            echo "エディタで編集してください:"
            echo "   vim $env_file"
            echo ""
            read -p "Enterキーを押して続行（またはCtrl+Cで中断）..." dummy
        else
            echo "❌ エラー: .env.templateが見つかりません"
            exit 1
        fi
    else
        echo "✅ .envファイルが存在します"
    fi
}
```

#### 1.2 必須ディレクトリの作成
```bash
# ログディレクトリの作成
create_required_directories() {
    local log_dirs=(
        "${DOCKER_DIR}/nginx/logs"
        "${DOCKER_DIR}/openappsec/logs"
        "${DOCKER_DIR}/fluentd/log"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "📁 ディレクトリを作成: $dir"
            mkdir -p "$dir"
        fi
    done
    
    echo "✅ 必要なディレクトリを作成しました"
}
```

### 2. サービス起動確認機能

#### 2.1 ヘルスチェック機能
```bash
# サービスのヘルスチェック
wait_for_service_ready() {
    local service_name=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    echo "🔄 ${service_name}の起動を待機中..."
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose ps "$service_name" 2>/dev/null | grep -q "Up"; then
            echo "✅ ${service_name}が起動しました"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "❌ ${service_name}の起動がタイムアウトしました"
    echo "ログを確認してください:"
    echo "   docker-compose logs $service_name"
    return 1
}

# 全サービスの起動確認
verify_all_services() {
    local services=("nginx" "openappsec-agent" "mock-api" "config-agent" "redis" "fluentd" "health-api")
    local failed=false
    
    echo "📋 全サービスの起動確認"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for service in "${services[@]}"; do
        if ! wait_for_service_ready "$service" 30; then
            failed=true
        fi
    done
    
    if [ "$failed" = true ]; then
        echo ""
        echo "❌ 一部のサービスが起動しませんでした"
        echo "全サービスの状態:"
        docker-compose ps
        return 1
    fi
    
    echo ""
    echo "✅ 全サービスが正常に起動しました"
    return 0
}
```

#### 2.2 エンドポイントのヘルスチェック
```bash
# エンドポイントのヘルスチェック
check_http_endpoint() {
    local url=$1
    local expected_code=${2:-200}
    local max_attempts=${3:-30}
    local attempt=0
    
    echo "🔄 HTTPエンドポイントを確認中: $url"
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -q "$expected_code"; then
            echo "✅ エンドポイントが応答しました: $url"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "⚠️  エンドポイントの確認がタイムアウトしました: $url"
    return 1
}

# 主要エンドポイントの確認
verify_endpoints() {
    echo "📋 エンドポイントの確認"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Health API（開発環境ではポート公開されている）
    check_http_endpoint "http://localhost:8888/health" 200 30
    
    # Nginx（Hostヘッダーが必要）
    echo "🔄 Nginxエンドポイントを確認中..."
    if curl -sf -H "Host: test.example.com" http://localhost/ >/dev/null 2>&1; then
        echo "✅ Nginxが応答しました"
    else
        echo "⚠️  Nginxの確認に失敗しました（設定によっては正常）"
    fi
    
    echo ""
}
```

### 3. エラーハンドリング機能

#### 3.1 既存コンテナの確認
```bash
# 既存コンテナの確認
check_existing_containers() {
    echo "📋 既存コンテナの確認"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local running_containers=$(docker-compose ps -q 2>/dev/null)
    
    if [ -n "$running_containers" ]; then
        echo "⚠️  既存のコンテナが実行中です:"
        docker-compose ps
        echo ""
        read -p "既存のコンテナを停止して再インストールしますか？ (y/N): " answer
        
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            echo "🔄 既存のコンテナを停止中..."
            docker-compose down
            echo "✅ 既存のコンテナを停止しました"
        else
            echo "ℹ️  インストールを中断しました"
            exit 0
        fi
    else
        echo "✅ 既存のコンテナはありません"
    fi
    echo ""
}
```

#### 3.2 エラー時のロールバック
```bash
# エラー時のクリーンアップ
cleanup_on_error() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ❌ インストールに失敗しました"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "エラー発生時のクリーンアップオプション:"
    echo "1. コンテナを停止して削除（docker-compose down）"
    echo "2. ログを確認してから手動で対処"
    echo "3. 何もしない"
    echo ""
    read -p "選択してください (1/2/3): " cleanup_option
    
    case $cleanup_option in
        1)
            echo "🔄 コンテナを停止中..."
            docker-compose down
            echo "✅ クリーンアップ完了"
            ;;
        2)
            echo "📋 ログを表示します:"
            docker-compose logs --tail=50
            ;;
        3)
            echo "ℹ️  クリーンアップをスキップしました"
            ;;
        *)
            echo "ℹ️  無効な選択です。何もしません"
            ;;
    esac
}

# エラートラップの設定
trap 'cleanup_on_error' ERR
```

### 4. インタラクティブモード

#### 4.1 インストールモードの選択
```bash
# インストールモードの選択
select_installation_mode() {
    echo "📋 インストールモードの選択"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. クイックスタート（開発環境、デフォルト設定）"
    echo "2. カスタムインストール（環境変数を設定）"
    echo "3. SaaS管理UI連携（my.openappsec.io使用）"
    echo ""
    read -p "選択してください (1/2/3) [デフォルト: 1]: " mode
    
    case ${mode:-1} in
        1)
            echo "✅ クイックスタートモードを選択しました"
            INSTALL_MODE="quick"
            ;;
        2)
            echo "✅ カスタムインストールモードを選択しました"
            INSTALL_MODE="custom"
            ;;
        3)
            echo "✅ SaaS管理UI連携モードを選択しました"
            INSTALL_MODE="saas"
            ;;
        *)
            echo "❌ 無効な選択です"
            exit 1
            ;;
    esac
    echo ""
}
```

### 5. 完成したインストールフロー

```bash
#!/bin/bash
# OpenAppSecインストールスクリプト
# 開発者が簡単にOpenAppSec環境をセットアップできるようにする

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

# エラー時のクリーンアップ
trap 'cleanup_on_error' ERR

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenAppSec インストールスクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. 依存関係の確認
check_dependencies

# 2. ディレクトリ構造の確認
check_directory_structure

# 3. 既存コンテナの確認
check_existing_containers

# 4. インストールモードの選択
select_installation_mode

# 5. 環境変数の設定
setup_environment

# 6. 必要なディレクトリの作成
create_required_directories

# 7. Docker Composeでのサービス起動
start_services

# 8. サービスの起動確認
verify_all_services

# 9. エンドポイントの確認
verify_endpoints

# 10. インストール完了メッセージ
show_completion_message
```

---

## 受け入れ条件

### 必須条件
- [x] インストールスクリプトが正常に動作する
- [x] 依存関係の確認が正常に動作する
- [x] 設定ファイルの検証が正常に動作する
- [x] Docker Composeでサービスが正常に起動する

### 追加条件
- [x] `.env`ファイルの作成・確認機能
- [x] ログディレクトリの自動作成
- [x] サービスのヘルスチェック機能
- [x] エラー時のロールバック機能
- [x] インタラクティブなインストールモード選択
- [x] 既存コンテナの確認・停止機能

---

## テスト計画

### 1. 正常系テスト
- [ ] クリーンな環境でのインストール
- [ ] `.env`ファイルが自動作成される
- [ ] 全サービスが正常に起動する
- [ ] ヘルスチェックが成功する

### 2. 異常系テスト
- [ ] Dockerがインストールされていない場合のエラー表示
- [ ] docker-composeがインストールされていない場合のエラー表示
- [ ] 既存コンテナが実行中の場合の処理
- [ ] サービス起動失敗時のエラーハンドリング

### 3. エッジケーステスト
- [ ] `.env`ファイルが既に存在する場合
- [ ] ログディレクトリが既に存在する場合
- [ ] ポート80/443が既に使用中の場合

---

## 実装スケジュール

### Phase 1: コア機能の実装
1. 環境変数設定機能
2. 必須ディレクトリ作成機能
3. 既存コンテナ確認機能

### Phase 2: 検証機能の実装
4. サービス起動確認機能
5. ヘルスチェック機能
6. エンドポイント検証機能

### Phase 3: エラーハンドリング
7. エラー時のロールバック機能
8. 詳細なエラーメッセージ
9. ログ表示機能

### Phase 4: UX改善
10. インタラクティブモード
11. プログレスインジケータ
12. 完了メッセージの改善

---

## セキュリティ考慮事項

1. **環境変数の扱い**
   - `.env`ファイルのパーミッション確認（600推奨）
   - 機密情報のログ出力抑制

2. **Docker操作**
   - `docker-compose`コマンドの安全な実行
   - ユーザー権限の確認

3. **ファイル操作**
   - シンボリックリンク攻撃の防止
   - パスインジェクションの防止

---

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [Docker Compose公式ドキュメント](https://docs.docker.com/compose/)
- `docker/README.md`
- `docs/design/MWD-38-task-review.md`
