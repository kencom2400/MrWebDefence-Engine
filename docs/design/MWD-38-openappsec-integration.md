# Task 5.1: OpenAppSec統合 設計書

## 概要

OpenAppSecをベースとしてWAF（Web Application Firewall）機能を提供するための統合設計。

## 目的

- OpenAppSecのインストール・設定
- Nginxとの統合（共有メモリ使用）
- WAF機能の提供

## アーキテクチャ概要

### システム構成

```
┌─────────────────────────────────────────────────────────┐
│                    Client Request                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Nginx (with Attachment Module)            │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ngx_cp_attachment_module.so                     │  │
│  │  - HTTP(S)トラフィックをキャプチャ                │  │
│  │  - OpenAppSec Agentと通信                         │  │
│  │  - 共有メモリを使用                                │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ 共有メモリ / IPC
                       ▼
┌─────────────────────────────────────────────────────────┐
│              OpenAppSec Agent Container                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  - WAFロジック実行                                │  │
│  │  - MLモデルによる脅威検出                          │  │
│  │  - ブロック/許可判定                               │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Backend Application                        │
└─────────────────────────────────────────────────────────┘
```

### コンポーネント

1. **Nginx Attachment Module**
   - OpenAppSec提供のNGINXモジュール
   - HTTP(S)トラフィックをインターセプト
   - Agentと通信して判定結果を受信

2. **OpenAppSec Agent**
   - WAFエンジン
   - 機械学習モデルによる脅威検出
   - ブロック/許可の判定

3. **共有メモリ（Shared Memory）**
   - NginxとAgent間の高速通信
   - セッション情報、リクエストメタデータの共有
   - パフォーマンス最適化

## 実装詳細

### 1. ディレクトリ構造

```
MrWebDefence-Engine/
├── docker/
│   ├── docker-compose.yml          # OpenAppSec統合構成
│   ├── nginx/
│   │   ├── nginx.conf              # Nginx設定（Attachment Module読み込み）
│   │   └── conf.d/
│   │       └── default.conf         # バーチャルホスト設定
│   └── openappsec/
│       └── agent-config.yaml        # OpenAppSec Agent設定
├── scripts/
│   └── openappsec/
│       ├── install.sh               # OpenAppSecインストールスクリプト
│       ├── configure.sh             # 設定スクリプト
│       └── health-check.sh          # ヘルスチェックスクリプト
└── docs/
    └── design/
        └── MWD-38-openappsec-integration.md  # 本設計書
```

### 2. Docker Compose構成

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:latest
    container_name: mwd-nginx
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./docker/nginx/conf.d:/etc/nginx/conf.d:ro
      - nginx-shm:/var/cache/nginx/shared
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - openappsec-agent
    networks:
      - mwd-network
    restart: unless-stopped

  openappsec-agent:
    image: openappsec/agent:latest
    container_name: mwd-openappsec-agent
    volumes:
      - ./docker/openappsec/agent-config.yaml:/etc/openappsec/agent-config.yaml:ro
      - nginx-shm:/var/cache/nginx/shared
    environment:
      - OPENAPPSEC_LOG_LEVEL=info
    networks:
      - mwd-network
    restart: unless-stopped

volumes:
  nginx-shm:
    driver: local

networks:
  mwd-network:
    driver: bridge
```

### 3. Nginx設定

#### nginx.conf

```nginx
# OpenAppSec Attachment Moduleの読み込み
load_module /usr/lib/nginx/modules/ngx_cp_attachment_module.so;

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 共有メモリゾーンの設定
    # OpenAppSec用の共有メモリ
    openappsec_shared_memory_zone zone=openappsec_shm:10m;

    # ログ設定
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 基本設定
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # OpenAppSec設定
    openappsec_agent_url http://openappsec-agent:8080;
    openappsec_enabled on;

    # 設定ファイルの読み込み
    include /etc/nginx/conf.d/*.conf;
}
```

#### conf.d/default.conf

```nginx
server {
    listen 80;
    server_name _;

    # OpenAppSecによるリクエストインターセプト
    location / {
        # OpenAppSecによる検査を有効化
        openappsec_inspect on;
        
        # バックエンドへのプロキシ
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # ヘルスチェックエンドポイント（OpenAppSecをバイパス）
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 4. OpenAppSec Agent設定

#### agent-config.yaml

```yaml
agent:
  name: mwd-openappsec-agent
  version: "1.0.0"
  
  # 通信設定
  communication:
    type: shared_memory
    shared_memory_zone: openappsec_shm
    socket_path: /var/cache/nginx/shared/openappsec.sock

  # WAF設定
  waf:
    enabled: true
    mode: prevention  # detection または prevention
    learning_mode: false  # 初期はfalse、学習後はtrue

  # MLモデル設定
  ml:
    model_path: /etc/openappsec/models
    update_interval: 3600  # 1時間ごと

  # ログ設定
  logging:
    level: info
    format: json
    output: stdout

  # パフォーマンス設定
  performance:
    max_concurrent_requests: 1000
    request_timeout: 5s
    cache_size: 100MB
```

### 5. インストールスクリプト

#### scripts/openappsec/install.sh

```bash
#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenAppSec インストールスクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 依存関係の確認
check_dependencies() {
    echo "📋 依存関係を確認中..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ エラー: Dockerがインストールされていません"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ エラー: docker-composeがインストールされていません"
        exit 1
    fi
    
    echo "✅ 依存関係の確認完了"
}

# OpenAppSecモジュールの確認
check_module() {
    echo "📋 OpenAppSec Attachment Moduleを確認中..."
    
    MODULE_PATH="/usr/lib/nginx/modules/ngx_cp_attachment_module.so"
    
    if [ ! -f "$MODULE_PATH" ]; then
        echo "⚠️  警告: Attachment Moduleが見つかりません"
        echo "    Dockerイメージに含まれていることを確認してください"
    else
        echo "✅ Attachment Moduleが見つかりました: $MODULE_PATH"
    fi
}

# 設定ファイルの検証
validate_config() {
    echo "📋 設定ファイルを検証中..."
    
    if [ ! -f "docker/nginx/nginx.conf" ]; then
        echo "❌ エラー: docker/nginx/nginx.conf が見つかりません"
        exit 1
    fi
    
    if [ ! -f "docker/openappsec/agent-config.yaml" ]; then
        echo "❌ エラー: docker/openappsec/agent-config.yaml が見つかりません"
        exit 1
    fi
    
    echo "✅ 設定ファイルの検証完了"
}

# メイン処理
main() {
    check_dependencies
    check_module
    validate_config
    
    echo ""
    echo "🚀 Docker Composeでサービスを起動中..."
    docker-compose -f docker/docker-compose.yml up -d
    
    echo ""
    echo "✅ OpenAppSecのインストールが完了しました"
    echo ""
    echo "次のステップ:"
    echo "  1. docker-compose logs -f でログを確認"
    echo "  2. curl http://localhost/health でヘルスチェック"
    echo "  3. docker-compose ps でコンテナの状態を確認"
}

main "$@"
```

### 6. 設定スクリプト

#### scripts/openappsec/configure.sh

```bash
#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenAppSec 設定スクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 設定項目
configure_waf_mode() {
    echo "📋 WAFモードを設定します"
    echo "  1) detection (検出のみ)"
    echo "  2) prevention (検出+ブロック)"
    read -p "選択 (1 or 2): " choice
    
    case $choice in
        1)
            MODE="detection"
            ;;
        2)
            MODE="prevention"
            ;;
        *)
            echo "❌ 無効な選択です"
            exit 1
            ;;
    esac
    
    # agent-config.yamlを更新
    sed -i "s/mode:.*/mode: $MODE/" docker/openappsec/agent-config.yaml
    echo "✅ WAFモードを $MODE に設定しました"
}

# メイン処理
main() {
    configure_waf_mode
    
    echo ""
    echo "🔄 設定を反映するためにコンテナを再起動しますか？ (y/n)"
    read -p "> " restart
    
    if [ "$restart" = "y" ]; then
        docker-compose -f docker/docker-compose.yml restart openappsec-agent
        echo "✅ コンテナを再起動しました"
    fi
}

main "$@"
```

### 7. ヘルスチェックスクリプト

#### scripts/openappsec/health-check.sh

```bash
#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OpenAppSec ヘルスチェック"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Nginxのヘルスチェック
check_nginx() {
    echo "📋 Nginxの状態を確認中..."
    
    if docker-compose -f docker/docker-compose.yml ps nginx | grep -q "Up"; then
        echo "✅ Nginx: 実行中"
        
        # ヘルスチェックエンドポイント
        if curl -s -f http://localhost/health > /dev/null; then
            echo "✅ Nginx ヘルスチェック: OK"
        else
            echo "❌ Nginx ヘルスチェック: 失敗"
            return 1
        fi
    else
        echo "❌ Nginx: 停止中"
        return 1
    fi
}

# OpenAppSec Agentのヘルスチェック
check_agent() {
    echo "📋 OpenAppSec Agentの状態を確認中..."
    
    if docker-compose -f docker/docker-compose.yml ps openappsec-agent | grep -q "Up"; then
        echo "✅ OpenAppSec Agent: 実行中"
        
        # ログからエラーを確認
        if docker-compose -f docker/docker-compose.yml logs --tail=50 openappsec-agent | grep -q "ERROR"; then
            echo "⚠️  警告: Agentログにエラーが見つかりました"
            docker-compose -f docker/docker-compose.yml logs --tail=10 openappsec-agent | grep ERROR
        else
            echo "✅ OpenAppSec Agent: 正常"
        fi
    else
        echo "❌ OpenAppSec Agent: 停止中"
        return 1
    fi
}

# 共有メモリの確認
check_shared_memory() {
    echo "📋 共有メモリの状態を確認中..."
    
    # Docker volumeの確認
    if docker volume inspect mwd-nginx-shm > /dev/null 2>&1; then
        echo "✅ 共有メモリボリューム: 存在"
    else
        echo "⚠️  警告: 共有メモリボリュームが見つかりません"
    fi
}

# メイン処理
main() {
    check_nginx
    NGINX_STATUS=$?
    
    check_agent
    AGENT_STATUS=$?
    
    check_shared_memory
    
    echo ""
    if [ $NGINX_STATUS -eq 0 ] && [ $AGENT_STATUS -eq 0 ]; then
        echo "✅ すべてのコンポーネントが正常に動作しています"
        exit 0
    else
        echo "❌ 一部のコンポーネントに問題があります"
        exit 1
    fi
}

main "$@"
```

## 実装手順

### Phase 1: 基盤構築

1. **ディレクトリ構造の作成**
   ```bash
   mkdir -p docker/nginx/conf.d
   mkdir -p docker/openappsec
   mkdir -p scripts/openappsec
   ```

2. **Docker Composeファイルの作成**
   - `docker/docker-compose.yml` を作成

3. **Nginx設定ファイルの作成**
   - `docker/nginx/nginx.conf` を作成
   - `docker/nginx/conf.d/default.conf` を作成

4. **OpenAppSec Agent設定の作成**
   - `docker/openappsec/agent-config.yaml` を作成

### Phase 2: スクリプト実装

1. **インストールスクリプト**
   - `scripts/openappsec/install.sh` を実装

2. **設定スクリプト**
   - `scripts/openappsec/configure.sh` を実装

3. **ヘルスチェックスクリプト**
   - `scripts/openappsec/health-check.sh` を実装

### Phase 3: テスト・検証

1. **ローカル環境でのテスト**
   - Docker Composeで起動
   - ヘルスチェックの実行
   - ログの確認

2. **統合テスト**
   - 実際のHTTPリクエストでの動作確認
   - WAF機能の検証

## 考慮事項

### パフォーマンス

- **共有メモリサイズ**: 初期は10MB、必要に応じて調整
- **Worker Process数**: Nginxのworker_processesを適切に設定
- **キャッシュサイズ**: Agentのキャッシュサイズを調整可能に

### セキュリティ

- **モード選択**: 初期は`detection`モードで動作確認後、`prevention`に移行
- **ログ管理**: セキュリティログの適切な管理
- **設定の保護**: 設定ファイルの権限管理

### 運用

- **ログローテーション**: NginxとAgentのログローテーション設定
- **モニタリング**: ヘルスチェックとアラートの設定
- **アップデート**: OpenAppSecの定期的なアップデート

## トラブルシューティング

### よくある問題

1. **Attachment Moduleが読み込まれない**
   - モジュールパスの確認
   - Nginxバージョンとの互換性確認

2. **共有メモリのエラー**
   - ボリュームのマウント確認
   - パーミッションの確認

3. **Agentとの通信エラー**
   - ネットワーク設定の確認
   - ログの確認

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [NGINX Shared Memory Zones](https://nginx.org/en/docs/http/ngx_http_core_module.html#variables)
- [OpenAppSec NGINX統合ガイド](https://docs.openappsec.io/deployment-and-upgrade/load-the-attachment-in-proxy-configuration)

## 次のステップ

1. 設計レビュー
2. 実装開始（Phase 1から順次）
3. テスト・検証
4. 本番環境への展開
