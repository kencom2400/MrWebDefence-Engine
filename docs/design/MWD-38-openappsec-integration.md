# Task 5.1: OpenAppSec統合 設計書

## 概要

OpenAppSecをベースとしてWAF（Web Application Firewall）機能を提供するための統合設計。

## 目的

- OpenAppSecのインストール・設定
- Nginxとの統合（共有メモリ使用）
- WAF機能の提供
- **1つのNginxで複数のFQDNを扱う**
- **FQDNごとに異なるWAF設定を適用する**

## アーキテクチャ概要

### システム構成

```
┌─────────────────────────────────────────────────────────┐
│              Client Requests (Multiple FQDNs)           │
│  - example1.com                                          │
│  - example2.com                                          │
│  - example3.com                                           │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Nginx (with Attachment Module)            │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ngx_cp_attachment_module.so                     │  │
│  │  - 複数FQDNのバーチャルホスト設定                 │  │
│  │  - FQDNごとのHTTP(S)トラフィックをキャプチャ      │  │
│  │  - OpenAppSec Agentと通信（FQDN情報付き）         │  │
│  │  - 共有メモリを使用                                │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Server Blocks (FQDN別設定)                      │  │
│  │  - example1.com → WAF設定A                       │  │
│  │  - example2.com → WAF設定B                       │  │
│  │  - example3.com → WAF設定C                       │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ 共有メモリ / IPC (FQDN情報付き)
                       ▼
┌─────────────────────────────────────────────────────────┐
│              OpenAppSec Agent Container                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  - FQDN別WAF設定の管理                            │  │
│  │  - FQDNごとのWAFロジック実行                      │  │
│  │  - MLモデルによる脅威検出（FQDN別）                │  │
│  │  - ブロック/許可判定（FQDN別設定適用）             │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│         Backend Applications (FQDN別)                     │
│  - example1.com → Backend A                             │
│  - example2.com → Backend B                              │
│  - example3.com → Backend C                              │
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
│   │       ├── example1.com.conf   # FQDN別バーチャルホスト設定
│   │       ├── example2.com.conf   # FQDN別バーチャルホスト設定
│   │       └── example3.com.conf   # FQDN別バーチャルホスト設定
│   └── openappsec/
│       └── local_policy.yaml        # OpenAppSecポリシー設定（FQDN別設定含む）
├── scripts/
│   └── openappsec/
│       ├── install.sh               # OpenAppSecインストールスクリプト
│       ├── configure.sh             # 設定スクリプト
│       ├── add-fqdn.sh              # FQDN追加スクリプト
│       ├── remove-fqdn.sh           # FQDN削除スクリプト
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
      - ./docker/openappsec/local_policy.yaml:/etc/openappsec/local_policy.yaml:ro
      - nginx-shm:/var/cache/nginx/shared
    environment:
      - OPENAPPSEC_LOG_LEVEL=info
      - OPENAPPSEC_POLICY_FILE=/etc/openappsec/local_policy.yaml
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

#### conf.d/example1.com.conf

```nginx
server {
    listen 80;
    server_name example1.com www.example1.com;

    # OpenAppSecによるリクエストインターセプト
    # FQDNはserver_nameから自動認識される
    location / {
        # OpenAppSecによる検査を有効化
        # FQDN別設定はlocal_policy.yamlのspecificRulesで定義
        
        # バックエンドへのプロキシ
        proxy_pass http://backend1:3000;
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

#### conf.d/example2.com.conf

```nginx
server {
    listen 80;
    server_name example2.com www.example2.com;

    # OpenAppSecによるリクエストインターセプト
    location / {
        # OpenAppSecによる検査を有効化
        # FQDN別設定はlocal_policy.yamlのspecificRulesで定義
        
        # バックエンドへのプロキシ
        proxy_pass http://backend2:3000;
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

#### conf.d/example3.com.conf

```nginx
server {
    listen 80;
    server_name example3.com www.example3.com;

    # OpenAppSecによるリクエストインターセプト
    location / {
        # OpenAppSecによる検査を有効化
        # FQDN別設定はlocal_policy.yamlのspecificRulesで定義
        
        # バックエンドへのプロキシ
        proxy_pass http://backend3:3000;
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

OpenAppSecは`local_policy.yaml`という1つの設定ファイルで、デフォルトポリシーとFQDN別の特定ルール（`specificRules`）を定義します。

#### local_policy.yaml（OpenAppSecポリシー設定）

```yaml
apiVersion: v1beta2

# デフォルトポリシー（すべてのFQDNに適用、specificRulesで上書き可能）
policies:
  default:
    mode: detect-learn  # デフォルトは検出+学習モード
    threatPreventionPractices:
      - webapp-default-practice
    accessControlPractices:
      - rate-limit-default
    triggers:
      - default-log-trigger
    customResponse: default-block-response
    sourceIdentifiers: default-source-identifiers
    trustedSources: default-trusted-sources
    exceptions:
      - default-exception

  # FQDN別の特定ルール（defaultを上書き）
  specificRules:
    # example1.com用の設定
    - host: "example1.com"
      name: example1-rule
      mode: prevent-learn  # このFQDNはブロック+学習モード
      threatPreventionPractices:
        - webapp-strict-practice  # 厳格な保護
      accessControlPractices:
        - rate-limit-strict  # 厳格なレート制限
      triggers:
        - example1-log-trigger
      customResponse: example1-block-response
      sourceIdentifiers: example1-source-identifiers
      trustedSources: example1-trusted-sources
      exceptions:
        - example1-exception

    # example2.com用の設定
    - host: "example2.com"
      name: example2-rule
      mode: detect-learn  # このFQDNは検出+学習モード（ブロックしない）
      threatPreventionPractices:
        - webapp-default-practice
      accessControlPractices:
        - rate-limit-relaxed  # 緩いレート制限
      triggers:
        - example2-log-trigger
      # customResponse等は省略可能（defaultを継承）

    # example3.com用の設定
    - host: "example3.com"
      name: example3-rule
      mode: prevent-learn  # このFQDNはブロック+学習モード
      threatPreventionPractices:
        - webapp-very-strict-practice  # 非常に厳格な保護
      accessControlPractices:
        - rate-limit-very-strict  # 非常に厳格なレート制限
      triggers:
        - example3-log-trigger
      customResponse: example3-block-response
```

**注意**: 
- `host`フィールドでFQDNを指定します（`server_name`と一致させる必要があります）
- `www.example1.com`も含める場合は、別の`specificRules`エントリを追加するか、同じエントリに複数のFQDNを指定する方法を検討します
- パスを含めることも可能（例: `"example1.com/admin"`）

#### practices定義（参考）

実際の運用では、`threatPreventionPractices`や`accessControlPractices`で参照されるプラクティス定義も必要です。これらは別ファイルまたは同じファイル内で定義できます。

```yaml
# プラクティス定義の例（参考）
practices:
  webapp-default-practice:
    # デフォルトのWAF保護ルール
    enabled: true
    
  webapp-strict-practice:
    # 厳格なWAF保護ルール
    enabled: true
    sql_injection_protection: strict
    xss_protection: strict
    
  rate-limit-default:
    max_requests_per_minute: 100
    
  rate-limit-strict:
    max_requests_per_minute: 50
    
  rate-limit-relaxed:
    max_requests_per_minute: 200
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
    
    if [ ! -f "docker/openappsec/local_policy.yaml" ]; then
        echo "❌ エラー: docker/openappsec/local_policy.yaml が見つかりません"
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

# グローバル設定の変更
configure_global_waf_mode() {
    echo "📋 グローバルWAFモードを設定します"
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
    
    # local_policy.yamlのdefaultセクションを更新
    # 注意: YAMLの構造を保持する必要があるため、より高度な処理が必要
    echo "⚠️  注意: local_policy.yamlの編集は手動で行ってください"
    echo "    default.mode を $MODE に変更してください"
}

# FQDN別設定の変更
configure_fqdn_waf() {
    echo ""
    echo "📋 FQDN別WAF設定を変更します"
    read -p "FQDNを入力: " FQDN
    
    if [ -z "$FQDN" ]; then
        echo "❌ FQDNが指定されていません"
        exit 1
    fi
    
    POLICY_FILE="docker/openappsec/local_policy.yaml"
    
    if [ ! -f "$POLICY_FILE" ]; then
        echo "❌ エラー: ${POLICY_FILE} が見つかりません"
        exit 1
    fi
    
    # local_policy.yamlに該当FQDNのspecificRulesが存在するか確認
    if ! grep -q "host:.*${FQDN}" "$POLICY_FILE"; then
        echo "❌ エラー: ${FQDN} の設定がlocal_policy.yamlに見つかりません"
        echo "   先に add-fqdn.sh でFQDNを追加してください"
        exit 1
    fi
    
    echo ""
    echo "WAFモードを設定します"
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
    
    # local_policy.yamlの該当FQDNのspecificRulesを更新
    # 注意: YAMLの構造を保持する必要があるため、より高度な処理が必要
    echo "⚠️  注意: local_policy.yamlの編集は手動で行ってください"
    echo "    ${FQDN} のspecificRules.mode を $MODE に変更してください"
}

# メイン処理
main() {
    echo "設定を変更する対象を選択してください"
    echo "  1) グローバル設定"
    echo "  2) FQDN別設定"
    read -p "選択 (1 or 2): " target
    
    case $target in
        1)
            configure_global_waf_mode
            ;;
        2)
            configure_fqdn_waf
            ;;
        *)
            echo "❌ 無効な選択です"
            exit 1
            ;;
    esac
    
    echo ""
    echo "🔄 設定を反映するためにコンテナを再起動しますか？ (y/n)"
    read -p "> " restart
    
    if [ "$restart" = "y" ]; then
        docker-compose -f docker/docker-compose.yml restart openappsec-agent nginx
        echo "✅ コンテナを再起動しました"
    fi
}

main "$@"
```

### 6-1. FQDN追加スクリプト

#### scripts/openappsec/add-fqdn.sh

```bash
#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FQDN追加スクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# FQDNの入力
read -p "追加するFQDN: " FQDN

if [ -z "$FQDN" ]; then
    echo "❌ エラー: FQDNが指定されていません"
    exit 1
fi

# FQDNのバリデーション（簡易版）
if ! [[ "$FQDN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ エラー: 無効なFQDN形式です"
    exit 1
fi

# バックエンド情報の入力
read -p "バックエンドホスト名 (例: backend1): " BACKEND_HOST
read -p "バックエンドポート (デフォルト: 3000): " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-3000}

# WAF設定の選択
echo ""
echo "WAFモードを選択してください"
echo "  1) detection (検出のみ)"
echo "  2) prevention (検出+ブロック)"
read -p "選択 (1 or 2): " waf_choice

case $waf_choice in
    1)
        WAF_MODE="detection"
        ;;
    2)
        WAF_MODE="prevention"
        ;;
    *)
        echo "❌ 無効な選択です"
        exit 1
        ;;
esac

# Nginx設定ファイルの作成
NGINX_CONF="docker/nginx/conf.d/${FQDN}.conf"
cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name ${FQDN} www.${FQDN};

    # OpenAppSecによるリクエストインターセプト
    location / {
        # OpenAppSecによる検査を有効化（FQDN別設定を適用）
        openappsec_inspect on;
        openappsec_fqdn ${FQDN};
        
        # バックエンドへのプロキシ
        proxy_pass http://${BACKEND_HOST}:${BACKEND_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # ヘルスチェックエンドポイント（OpenAppSecをバイパス）
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

echo "✅ Nginx設定ファイルを作成しました: ${NGINX_CONF}"

# local_policy.yamlにFQDN設定を追加
POLICY_FILE="docker/openappsec/local_policy.yaml"

if [ ! -f "$POLICY_FILE" ]; then
    echo "❌ エラー: ${POLICY_FILE} が見つかりません"
    echo "   先にlocal_policy.yamlを作成してください"
    exit 1
fi

# local_policy.yamlにspecificRulesエントリを追加
# 注意: この処理は簡易版です。実際の運用ではYAMLパーサーを使用することを推奨
cat >> "$POLICY_FILE" << EOF

    # ${FQDN}用の設定（自動生成）
    - host: "${FQDN}"
      name: ${FQDN//\./-}-rule
      mode: ${WAF_MODE}-learn
      threatPreventionPractices:
        - webapp-default-practice
      accessControlPractices:
        - rate-limit-default
      triggers:
        - default-log-trigger
EOF

echo "✅ local_policy.yamlに${FQDN}の設定を追加しました"
echo "⚠️  注意: YAMLの構文を確認し、必要に応じて手動で調整してください"

echo ""
echo "🔄 設定を反映するためにコンテナを再起動しますか？ (y/n)"
read -p "> " restart

if [ "$restart" = "y" ]; then
    docker-compose -f docker/docker-compose.yml restart openappsec-agent nginx
    echo "✅ コンテナを再起動しました"
fi

echo ""
echo "✅ FQDN ${FQDN} の追加が完了しました"
```

### 6-2. FQDN削除スクリプト

#### scripts/openappsec/remove-fqdn.sh

```bash
#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FQDN削除スクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# FQDNの入力
read -p "削除するFQDN: " FQDN

if [ -z "$FQDN" ]; then
    echo "❌ エラー: FQDNが指定されていません"
    exit 1
fi

# 確認
echo ""
echo "⚠️  以下のファイルが削除/変更されます:"
echo "  - docker/nginx/conf.d/${FQDN}.conf"
echo "  - docker/openappsec/local_policy.yaml (${FQDN}の設定を削除)"
echo ""
read -p "本当に削除しますか？ (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ 削除をキャンセルしました"
    exit 0
fi

# ファイルの削除
NGINX_CONF="docker/nginx/conf.d/${FQDN}.conf"
POLICY_FILE="docker/openappsec/local_policy.yaml"

if [ -f "$NGINX_CONF" ]; then
    rm "$NGINX_CONF"
    echo "✅ Nginx設定ファイルを削除しました: ${NGINX_CONF}"
else
    echo "⚠️  警告: ${NGINX_CONF} が見つかりません"
fi

# local_policy.yamlから該当FQDNの設定を削除
if [ -f "$POLICY_FILE" ]; then
    # 簡易的な削除（実際の運用ではYAMLパーサーを使用することを推奨）
    echo "⚠️  注意: local_policy.yamlから${FQDN}の設定を手動で削除してください"
    echo "    host: \"${FQDN}\" を含むspecificRulesエントリを削除してください"
else
    echo "⚠️  警告: ${POLICY_FILE} が見つかりません"
fi

echo ""
echo "🔄 設定を反映するためにコンテナを再起動しますか？ (y/n)"
read -p "> " restart

if [ "$restart" = "y" ]; then
    docker-compose -f docker/docker-compose.yml restart openappsec-agent nginx
    echo "✅ コンテナを再起動しました"
fi

echo ""
echo "✅ FQDN ${FQDN} の削除が完了しました"
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
   - FQDN別設定ファイルのテンプレートを作成

4. **OpenAppSec Agent設定の作成**
   - `docker/openappsec/local_policy.yaml` を作成
   - `default`ポリシーと`specificRules`でFQDN別設定を定義

### Phase 2: スクリプト実装

1. **インストールスクリプト**
   - `scripts/openappsec/install.sh` を実装

2. **設定スクリプト**
   - `scripts/openappsec/configure.sh` を実装（グローバル/FQDN別対応）

3. **FQDN管理スクリプト**
   - `scripts/openappsec/add-fqdn.sh` を実装
   - `scripts/openappsec/remove-fqdn.sh` を実装

4. **ヘルスチェックスクリプト**
   - `scripts/openappsec/health-check.sh` を実装（FQDN別チェック対応）

### Phase 3: テスト・検証

1. **ローカル環境でのテスト**
   - Docker Composeで起動
   - 複数FQDNの追加テスト
   - 各FQDNのヘルスチェックの実行
   - ログの確認（FQDN別ログの確認）

2. **統合テスト**
   - 実際のHTTPリクエストでの動作確認（複数FQDN）
   - FQDN別WAF設定の検証
   - FQDN別のブロック/許可動作の確認
   - パフォーマンステスト（複数FQDN同時アクセス）

## 考慮事項

### パフォーマンス

- **共有メモリサイズ**: 初期は10MB、FQDN数に応じて調整（1FQDNあたり約2-3MBを目安）
- **Worker Process数**: Nginxのworker_processesを適切に設定
- **キャッシュサイズ**: Agentのキャッシュサイズを調整可能に
- **FQDN別キャッシュ**: 各FQDNの設定をキャッシュして高速化

### セキュリティ

- **モード選択**: 初期は`detection`モードで動作確認後、`prevention`に移行
- **FQDN別セキュリティポリシー**: 各FQDNの特性に応じたセキュリティレベルを設定
- **ログ管理**: セキュリティログの適切な管理（FQDN別ログも可能）
- **設定の保護**: 設定ファイルの権限管理

### 運用

- **FQDN管理**: `add-fqdn.sh`と`remove-fqdn.sh`を使用してFQDNを管理
- **設定変更**: `configure.sh`でグローバル設定またはFQDN別設定を変更
- **ログローテーション**: NginxとAgentのログローテーション設定（FQDN別ログも考慮）
- **モニタリング**: ヘルスチェックとアラートの設定（FQDN別モニタリングも可能）
- **アップデート**: OpenAppSecの定期的なアップデート

### 複数FQDN対応の注意点

- **設定ファイルの管理**: FQDNごとに設定ファイルを分離して管理
- **Nginx設定の再読み込み**: 新しいFQDNを追加した場合は`nginx -s reload`で反映
- **Agent設定の再読み込み**: FQDN設定を変更した場合はAgentの再起動が必要
- **ログの分離**: FQDN別にログを分離する場合は、ログ設定を調整
- **パフォーマンス**: FQDN数が増えると共有メモリの使用量が増加するため、適切にサイズを調整

## トラブルシューティング

### よくある問題

1. **Attachment Moduleが読み込まれない**
   - モジュールパスの確認
   - Nginxバージョンとの互換性確認

2. **共有メモリのエラー**
   - ボリュームのマウント確認
   - パーミッションの確認
   - FQDN数が増えた場合は共有メモリサイズの増加を検討

3. **Agentとの通信エラー**
   - ネットワーク設定の確認
   - ログの確認

4. **特定のFQDNでWAFが動作しない**
   - `local_policy.yaml`の`specificRules`に該当FQDNの設定が存在するか確認
   - Nginx設定ファイル（`conf.d/{fqdn}.conf`）の`server_name`が正しいか確認
   - AgentログでFQDNが正しく認識されているか確認
   - `local_policy.yaml`のYAML構文エラーを確認

5. **FQDN別設定が反映されない**
   - `local_policy.yaml`の`specificRules`に該当FQDNのエントリが存在するか確認
   - `host`フィールドの値が`server_name`と一致しているか確認
   - YAML構文エラーを確認（インデント、コロン、引用符など）
   - Agentコンテナの再起動を実行

6. **複数FQDNでパフォーマンスが低下**
   - 共有メモリサイズの増加を検討
   - Worker Process数の調整
   - Agentのキャッシュサイズの調整
   - 不要なFQDN設定の削除

## 参考資料

- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [NGINX Shared Memory Zones](https://nginx.org/en/docs/http/ngx_http_core_module.html#variables)
- [OpenAppSec NGINX統合ガイド](https://docs.openappsec.io/deployment-and-upgrade/load-the-attachment-in-proxy-configuration)

## 次のステップ

1. 設計レビュー
2. 実装開始（Phase 1から順次）
3. テスト・検証
4. 本番環境への展開
