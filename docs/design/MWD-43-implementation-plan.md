# Task 5.6: ヘルスチェック機能実装 実装設計書

## 概要

本ドキュメントは、Task 5.6: ヘルスチェック機能実装の実装設計を定義します。
WAFエンジンの状態を監視し、正常性を確認するためのヘルスチェック機能を実装します。

## 参照設計書

- **詳細設計**: `docs/design/MWD-38-openappsec-integration.md`
- **タスクレビュー**: `docs/design/MWD-38-task-review.md`
- **OpenAppSec設定リファレンス**: `docs/design/OPENAPPSEC-CONFIGURATION-REFERENCE.md`
- **要件定義**: `MrWebDefence-Design/docs/REQUIREMENT.md`（参照）
- **仕様書**: `MrWebDefence-Design/docs/SPECIFICATION.md`（参照）
- **詳細設計**: `MrWebDefence-Design/docs/DESIGN.md`（参照）

## JIRA Issue情報

- **Issueキー**: MWD-43
- **タイトル**: Task 5.6: ヘルスチェック機能実装
- **親タスク**: MWD-5 (Epic 5: WAFエンジン基盤実装)
- **優先度**: Medium
- **ステータス**: In Progress

### Issue説明

**なぜやるか**
WAFエンジンの状態を監視し、正常性を確認する機能が必要。

**何をやるか（概要）**
- ヘルスチェックエンドポイント実装（GET /engine/v1/health）
- Nginx状態チェック
- OpenAppSec Agent状態チェック
- ConfigAgent状態チェック
- Redis状態チェック
- Fluentd状態チェック
- 各コンポーネントの詳細状態取得
- 統合ヘルスチェック結果の返却

**受け入れ条件**
- [ ] ヘルスチェックエンドポイントが正常に動作する
- [ ] 各コンポーネントの状態が正確に取得できる
- [ ] 統合ヘルスチェック結果が適切に返却される
- [ ] 異常検知時に適切なステータスコードが返される

## 実装方針

### 1. 既存実装の活用

既存の`scripts/openappsec/health-check.sh`スクリプトを基盤として活用し、以下を拡張します：
- APIエンドポイントの追加
- より詳細な状態情報の取得
- JSON形式のレスポンス
- 追加コンポーネント（Redis、Fluentd）のチェック

### 2. 段階的実装

1. **Phase 1**: 既存スクリプトの改善（Redisチェック追加）
2. **Phase 2**: ヘルスチェックAPIエンドポイントの実装
3. **Phase 3**: テストと動作確認

### 3. 設計原則

- **軽量**: ヘルスチェックは頻繁に呼ばれるため、パフォーマンスを重視
- **明確な状態**: 各コンポーネントの状態を明確に示す
- **拡張可能**: 将来的に新しいコンポーネントを追加しやすい設計
- **標準準拠**: HTTPステータスコードとJSON形式で標準的なヘルスチェックAPIを提供

## 既存実装状況の確認

### ✅ 実装済みの機能（`scripts/openappsec/health-check.sh`）

#### 1. コンポーネント状態チェック
- ✅ Nginx状態チェック（コンテナ起動状態）
- ✅ Nginx設定ファイル構文チェック
- ✅ OpenAppSec Agent状態チェック（コンテナ起動状態）
- ✅ OpenAppSec設定ファイル存在確認
- ✅ ConfigAgent状態チェック（コンテナ起動状態）
- ✅ JSON形式出力オプション（`--json`）
- ✅ 人間が読みやすい形式の出力

#### 2. 出力形式
```json
{
  "status": "healthy|unhealthy",
  "components": {
    "nginx": "healthy|unhealthy|unknown",
    "nginx_config": "valid|invalid|unknown",
    "openappsec_agent": "healthy|unhealthy|unknown",
    "openappsec_config": "exists|missing|unknown",
    "config_agent": "healthy|unhealthy|unknown"
  },
  "errors": [
    {"component": "nginx", "message": "エラーメッセージ"}
  ]
}
```

### ⚠️ 追加が必要な機能

1. **Redisヘルスチェック**
   - コンテナ起動状態の確認
   - Redis接続確認（PING）
   - メモリ使用量の取得（オプション）

2. **Fluentdヘルスチェック**
   - コンテナ起動状態の確認
   - ログ収集状態の確認（オプション）

3. **APIエンドポイントの実装**
   - `GET /engine/v1/health`エンドポイント
   - HTTPステータスコードの適切な返却
   - CORS対応（必要に応じて）

4. **詳細情報の追加**
   - バージョン情報
   - アップタイム情報
   - 各コンポーネントの詳細ステータス

## 実装詳細

### 1. ディレクトリ構造

```
scripts/openappsec/
├── health-check.sh              # ヘルスチェックスクリプト（既存、拡張）
└── ...

docker/
├── health-api/                  # ヘルスチェックAPIサーバー（新規）
│   ├── Dockerfile
│   └── health-api-server.py     # Python製の軽量APIサーバー
└── docker-compose.yml           # health-apiサービス追加
```

### 2. health-check.shの拡張

#### 2.1 Redisチェック機能の追加

**実装内容**:
```bash
# Redisヘルスチェック
check_redis() {
    if docker-compose ps redis 2>/dev/null | grep -q "Up"; then
        health_status["redis"]="healthy"
        
        # Redis接続確認（PING）
        # パスワード認証に対応
        local redis_auth_arg=""
        if [ -n "$REDIS_PASSWORD" ]; then
            redis_auth_arg="-a $REDIS_PASSWORD"
        fi

        if docker-compose exec -T redis redis-cli ${redis_auth_arg} ping >/dev/null 2>&1; then
            health_status["redis_connection"]="ok"
        else
            health_status["redis_connection"]="failed"
            error_messages["redis_connection"]="Redisへの接続に失敗しました"
        fi
    else
        health_status["redis"]="unhealthy"
        error_messages["redis"]="Redisコンテナが起動していません"
    fi
}
```

#### 2.2 Fluentdチェック機能の追加

**実装内容**:
```bash
# Fluentdヘルスチェック
check_fluentd() {
    if docker-compose ps fluentd 2>/dev/null | grep -q "Up"; then
        health_status["fluentd"]="healthy"
    else
        health_status["fluentd"]="unhealthy"
        error_messages["fluentd"]="Fluentdコンテナが起動していません（オプション）"
    fi
}
```

#### 2.3 詳細情報の追加

**実装内容**:
```bash
# システム情報の取得
get_system_info() {
    local nginx_version
    
    nginx_version=$(docker-compose exec -T nginx nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+' || echo "unknown")
    
    # jqを使って安全にJSONを生成（特殊文字のエスケープに対応）
    jq -n \
      --arg nginx_version "$nginx_version" \
      --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg hostname "$(hostname)" \
      '{nginx_version: $nginx_version, timestamp: $timestamp, hostname: $hostname}'
}
```

### 3. ヘルスチェックAPIサーバーの実装

#### 3.1 health-api-server.py

**実装内容**:
```python
#!/usr/bin/env python3
"""
ヘルスチェックAPIサーバー
WAFエンジンの各コンポーネントの状態を返すHTTP APIサーバー
"""

import json
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import os
import logging

# ロギング設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('health-api')

PORT = int(os.environ.get('HEALTH_API_PORT', '8888'))
HEALTH_CHECK_SCRIPT = '/app/scripts/health-check.sh'

class HealthAPIHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/engine/v1/health':
            self.handle_health_check()
        elif path == '/health':
            # 簡易版ヘルスチェック（200 OKのみ）
            # Kubernetes liveness probe用
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode('utf-8'))
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "error": "Not Found",
                "message": f"Path {path} not found"
            }).encode('utf-8'))
    
    def handle_health_check(self):
        try:
            # health-check.shスクリプトを実行
            # タイムアウトは環境変数で設定可能（デフォルト10秒）
            timeout = int(os.environ.get('HEALTH_CHECK_TIMEOUT', '10'))
            # 作業ディレクトリも環境変数で設定可能（柔軟性向上）
            cwd = os.environ.get('HEALTH_CHECK_CWD', '/app/docker')
            result = subprocess.run(
                [HEALTH_CHECK_SCRIPT, '--json'],
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=cwd
            )
            
            if result.returncode == 0:
                # 正常: 200 OK
                health_data = json.loads(result.stdout)
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(health_data, indent=2).encode('utf-8'))
            else:
                # 異常: 503 Service Unavailable
                try:
                    health_data = json.loads(result.stdout)
                except json.JSONDecodeError:
                    health_data = {
                        "status": "unhealthy",
                        "message": "Health check script failed",
                        "stderr": result.stderr
                    }
                
                self.send_response(503)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(health_data, indent=2).encode('utf-8'))
        
        except subprocess.TimeoutExpired:
            logger.error("Health check timeout")
            self.send_response(503)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "unhealthy",
                "message": "Health check timeout"
            }).encode('utf-8'))
        
        except Exception as e:
            logger.exception("Unexpected error during health check")
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "error",
                "message": str(e)
            }).encode('utf-8'))
    
    def log_message(self, format, *args):
        # アクセスログをloggingモジュールで出力
        logger.info(f"{self.address_string()} - {format % args}")

def run_server():
    server = HTTPServer(('0.0.0.0', PORT), HealthAPIHandler)
    logger.info(f"✅ ヘルスチェックAPIサーバーを起動しました: http://0.0.0.0:{PORT}")
    logger.info(f"  GET /engine/v1/health - 詳細なヘルスチェック")
    logger.info(f"  GET /health - 簡易ヘルスチェック")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("\n🛑 サーバーを停止しています...")
        server.shutdown()

if __name__ == '__main__':
    run_server()
```

#### 3.2 Dockerfile（health-api用）

**実装内容**:
```dockerfile
FROM python:3-alpine

WORKDIR /app

# 必要なパッケージをインストール
RUN apk add --no-cache \
    bash \
    docker-cli \
    docker-compose \
    curl \
    jq

# ヘルスチェックAPIサーバーをコピー
COPY health-api-server.py /app/health-api-server.py
RUN chmod +x /app/health-api-server.py

# ヘルスチェックスクリプトは実行時にマウント
# /app/scriptsにマウントされることを想定

EXPOSE 8888

CMD ["python3", "/app/health-api-server.py"]
```

#### 3.3 docker-compose.ymlへの追加

**実装内容**:
```yaml
  health-api:
    # ヘルスチェックAPIサーバー
    build:
      context: ./health-api
      dockerfile: Dockerfile
    container_name: mwd-health-api
    volumes:
      # ヘルスチェックスクリプト
      - ../scripts/openappsec/health-check.sh:/app/scripts/health-check.sh:ro
      # Dockerソケット（コンテナ状態確認用）
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # docker-composeファイル（health-check.shで使用）
      - ./docker-compose.yml:/app/docker/docker-compose.yml:ro
    environment:
      - HEALTH_API_PORT=8888
      - HEALTH_CHECK_TIMEOUT=10  # ヘルスチェックタイムアウト（秒、デフォルト10秒）
      - HEALTH_CHECK_CWD=/app/docker  # health-check.sh実行時の作業ディレクトリ
      - REDIS_PASSWORD=${REDIS_PASSWORD:-}  # Redis認証パスワード（health-check.shで使用）
    ports:
      - "8888:8888"
    networks:
      - mwd-network
    depends_on:
      - nginx
      - openappsec-agent
      - config-agent
      - redis
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 4. エンドポイント仕様

#### 4.1 詳細ヘルスチェック: `GET /engine/v1/health`

**リクエスト**:
```http
GET /engine/v1/health HTTP/1.1
Host: localhost:8888
Accept: application/json
```

**レスポンス（正常）**: HTTP 200 OK
```json
{
  "status": "healthy",
  "timestamp": "2026-02-02T10:30:00Z",
  "components": {
    "nginx": "healthy",
    "nginx_config": "valid",
    "openappsec_agent": "healthy",
    "openappsec_config": "exists",
    "config_agent": "healthy",
    "redis": "healthy",
    "redis_connection": "ok",
    "fluentd": "healthy"
  },
  "errors": [],
  "system_info": {
    "nginx_version": "1.24.0",
    "hostname": "mwd-engine-01"
  }
}
```

**レスポンス（異常）**: HTTP 503 Service Unavailable
```json
{
  "status": "unhealthy",
  "timestamp": "2026-02-02T10:30:00Z",
  "components": {
    "nginx": "unhealthy",
    "nginx_config": "unknown",
    "openappsec_agent": "healthy",
    "openappsec_config": "exists",
    "config_agent": "healthy",
    "redis": "healthy",
    "redis_connection": "ok",
    "fluentd": "healthy"
  },
  "errors": [
    {
      "component": "nginx",
      "message": "Nginxコンテナが起動していません"
    }
  ],
  "system_info": {
    "nginx_version": "unknown",
    "hostname": "mwd-engine-01"
  }
}
```

#### 4.2 簡易ヘルスチェック: `GET /health`

**リクエスト**:
```http
GET /health HTTP/1.1
Host: localhost:8888
Accept: application/json
```

**レスポンス**: HTTP 200 OK
```json
{
  "status": "ok"
}
```

### 5. ステータス判定ロジック

#### 5.1 全体ステータス

全体ステータスは、必須コンポーネントの状態に基づいて判定します：

- **healthy**: すべての必須コンポーネントが正常
- **unhealthy**: 1つ以上の必須コンポーネントが異常

**必須コンポーネント**:
- Nginx（`nginx` および `nginx_config`）
- OpenAppSec Agent（`openappsec_agent` および `openappsec_config`）

**オプションコンポーネント**:
- ConfigAgent（`config_agent`）
- Redis（`redis` および `redis_connection`）
- Fluentd（`fluentd`）

#### 5.2 HTTPステータスコード

- **200 OK**: 全体ステータスが`healthy`
- **503 Service Unavailable**: 全体ステータスが`unhealthy`
- **500 Internal Server Error**: ヘルスチェック処理自体がエラー

## 実装フェーズ

### Phase 1: health-check.shの拡張（0.5日）

#### 1.1 Redisチェック機能の追加

**実装内容**:
- [x] `check_redis()`関数の実装
- [x] Redis接続確認（PING）の実装
- [x] エラーメッセージの追加

**実装場所**:
- `scripts/openappsec/health-check.sh`

**テスト手順**:
```bash
# Redisコンテナが起動している状態でテスト
./scripts/openappsec/health-check.sh --json | jq '.components.redis'

# 期待される出力: "healthy"
```

#### 1.2 Fluentdチェック機能の追加

**実装内容**:
- [x] `check_fluentd()`関数の実装
- [x] エラーメッセージの追加

**実装場所**:
- `scripts/openappsec/health-check.sh`

**テスト手順**:
```bash
# Fluentdコンテナが起動している状態でテスト
./scripts/openappsec/health-check.sh --json | jq '.components.fluentd'

# 期待される出力: "healthy"
```

#### 1.3 システム情報の追加

**実装内容**:
- [x] `get_system_info()`関数の実装
- [x] バージョン情報の取得
- [x] タイムスタンプの追加

**実装場所**:
- `scripts/openappsec/health-check.sh`

---

### Phase 2: ヘルスチェックAPIサーバーの実装（1日）

#### 2.1 health-api-server.pyの実装

**実装内容**:
- [ ] PythonによるHTTPサーバーの実装
- [ ] `/engine/v1/health`エンドポイントの実装
- [ ] `/health`簡易エンドポイントの実装
- [ ] health-check.shスクリプトの呼び出し
- [ ] エラーハンドリング

**実装場所**:
- `docker/health-api/health-api-server.py`（新規作成）

**成果物**:
- `health-api-server.py`

#### 2.2 Dockerfileの作成

**実装内容**:
- [ ] Dockerイメージの定義
- [ ] 必要なパッケージのインストール
- [ ] エントリーポイントの設定

**実装場所**:
- `docker/health-api/Dockerfile`（新規作成）

**成果物**:
- `Dockerfile`

#### 2.3 docker-compose.ymlへの追加

**実装内容**:
- [ ] health-apiサービスの定義
- [ ] ボリュームマウントの設定
- [ ] ポート公開の設定
- [ ] 依存関係の設定

**実装場所**:
- `docker/docker-compose.yml`

**成果物**:
- 更新された`docker-compose.yml`

---

### Phase 3: テストと動作確認（0.5日）

#### 3.1 単体テスト

**テスト項目**:
- [ ] health-check.shが正しくRedisをチェックする
- [ ] health-check.shが正しくFluentdをチェックする
- [ ] health-check.shがJSON形式で出力する
- [ ] システム情報が正しく取得される

**テスト手順**:
```bash
# すべてのコンテナを起動
cd docker
docker-compose up -d

# ヘルスチェックスクリプトを実行
../scripts/openappsec/health-check.sh --json

# 期待される出力: すべてのコンポーネントが"healthy"
```

#### 3.2 統合テスト

**テスト項目**:
- [ ] `/engine/v1/health`エンドポイントが正常に動作する
- [ ] `/health`エンドポイントが正常に動作する
- [ ] すべてのコンポーネントが正常な場合、HTTP 200が返される
- [ ] 異常なコンポーネントがある場合、HTTP 503が返される

**テスト手順**:
```bash
# health-apiコンテナを起動
docker-compose up -d health-api

# 詳細ヘルスチェック
curl -s http://localhost:8888/engine/v1/health | jq

# 簡易ヘルスチェック
curl -s http://localhost:8888/health | jq

# 異常系のテスト（Nginxを停止）
docker-compose stop nginx
curl -s http://localhost:8888/engine/v1/health | jq
# 期待される出力: status が "unhealthy"、HTTPステータスコードが 503
```

#### 3.3 エラーケースのテスト

**テスト項目**:
- [ ] Nginxが停止している場合
- [ ] OpenAppSec Agentが停止している場合
- [ ] Redisが停止している場合
- [ ] 複数のコンポーネントが停止している場合

**テスト手順**:
```bash
# 各コンポーネントを個別に停止してテスト
docker-compose stop nginx
curl -s http://localhost:8888/engine/v1/health | jq '.components.nginx'

docker-compose stop openappsec-agent
curl -s http://localhost:8888/engine/v1/health | jq '.components.openappsec_agent'

docker-compose stop redis
curl -s http://localhost:8888/engine/v1/health | jq '.components.redis'
```

---

### Phase 4: ドキュメント更新と最終確認（0.5日）

#### 4.1 ドキュメント更新

**更新内容**:
- [ ] `README-TASK-5-6.md`の作成
- [ ] API仕様の記載
- [ ] 使用方法の説明
- [ ] トラブルシューティングガイド

#### 4.2 最終確認

**確認項目**:
- [ ] すべての機能が正常に動作する
- [ ] エラーハンドリングが適切に実装されている
- [ ] ドキュメントが最新の状態である
- [ ] 受け入れ条件を満たしている

---

## 受け入れ条件

### 必須条件

- [ ] `health-check.sh`にRedisチェック機能が追加されている
- [ ] `health-check.sh`にFluentdチェック機能が追加されている
- [ ] `GET /engine/v1/health`エンドポイントが実装されている
- [ ] すべてのコンポーネントが正常な場合、HTTP 200が返される
- [ ] 異常なコンポーネントがある場合、HTTP 503が返される
- [ ] 各コンポーネントの詳細状態が取得できる
- [ ] エラーメッセージが適切に返される

### オプション条件

- [ ] システム情報（バージョン、ホスト名等）が取得できる
- [ ] CORS対応
- [ ] 認証機能（APIトークン）
- [ ] メトリクス収集（Prometheus形式）

## エラーハンドリング

### 1. health-check.shのエラーハンドリング

- **Dockerコンテナが存在しない場合**: `unknown`ステータスを返す
- **docker-composeコマンドが失敗した場合**: エラーログを出力し、`unknown`ステータスを返す
- **タイムアウト**: 10秒でタイムアウト（health-api-server.pyから呼び出される場合）

### 2. health-api-server.pyのエラーハンドリング

- **health-check.shの実行失敗**: HTTP 503を返す
- **タイムアウト**: HTTP 503を返す（デフォルト10秒、環境変数`HEALTH_CHECK_TIMEOUT`で変更可能）
- **JSONパースエラー**: HTTP 500を返す
- **予期しないエラー**: HTTP 500を返す

**タイムアウト設定について**:
- デフォルト値: 10秒（ロードバランサーの一般的なタイムアウトに適合）
- 環境変数`HEALTH_CHECK_TIMEOUT`で秒単位で設定可能
- ロードバランサーのタイムアウト設定より短く設定することを推奨
- 例: ロードバランサーが5秒タイムアウトの場合、`HEALTH_CHECK_TIMEOUT=3`に設定

## セキュリティ考慮事項

### 1. Dockerソケットのマウント

health-apiコンテナはDockerソケットをマウントします。これにはセキュリティリスクがあるため、以下を考慮します：

- **読み取り専用マウント**: `:ro`フラグを使用
- **最小権限の原則**: コンテナ状態の取得のみに使用
- **本番環境での対策**: 必要に応じて、Dockerソケットプロキシの使用を検討

### 2. ヘルスチェックエンドポイントの公開

- **ポート制限**: 内部ネットワークのみでアクセス可能にする（本番環境）
- **認証**: 必要に応じてAPIトークン認証を追加（オプション）
- **レート制限**: 過剰なリクエストを防ぐ（オプション）

## パフォーマンス考慮事項

### 1. ヘルスチェック処理の最適化

- **並列処理**: 各コンポーネントのチェックを並列実行（将来の拡張）
- **キャッシュ**: 頻繁なリクエストに対して結果をキャッシュ（オプション）
- **タイムアウト**: 10秒でタイムアウト（環境変数で変更可能）

### 2. 軽量な実装

- **PythonのHTTPサーバー**: 標準ライブラリのみを使用
- **最小限の依存関係**: 追加パッケージを最小限に抑える

## リスクと対策

### リスク1: Dockerソケットマウントのセキュリティリスク

**影響**: health-apiコンテナがDockerホストへの権限を持つ

**対策**:
- 読み取り専用マウント（`:ro`）
- 本番環境ではDockerソケットプロキシの使用を検討
- コンテナの実行権限を最小限に抑える

### リスク2: ヘルスチェック処理のタイムアウト

**影響**: ヘルスチェックAPIが応答しない

**対策**:
- デフォルト10秒でタイムアウト（環境変数`HEALTH_CHECK_TIMEOUT`で変更可能）
- タイムアウト時にHTTP 503を返す
- ログに詳細なエラーメッセージを出力

### リスク3: 一部コンポーネントの状態取得失敗

**影響**: ヘルスチェック結果が不正確

**対策**:
- 各コンポーネントのチェックを独立して実行
- エラーが発生してもヘルスチェック全体を継続
- `unknown`ステータスで状態を示す

## 次のステップ

1. **Phase 1の実装**: health-check.shの拡張（Redisチェック追加）
2. **Phase 2の実装**: ヘルスチェックAPIサーバーの実装
3. **Phase 3の実装**: テストと動作確認
4. **Phase 4の実装**: ドキュメント更新と最終確認
5. **受け入れテスト**: すべての受け入れ条件を満たしていることを確認

## 将来の改善計画

### 1. Pythonで完結する実装への移行

現在の設計では、既存の`health-check.sh`スクリプトを拡張し、PythonのヘルスチェックAPIサーバーから呼び出す方式を採用しています。これは既存実装を活用する上で合理的なアプローチですが、長期的には以下の改善を検討します：

**現在のアーキテクチャの課題**:
- シェルスクリプト実行のオーバーヘッド（サブプロセス起動）
- エラーハンドリングがシェルスクリプトとPythonに分散
- メンテナンス性の低下（2つの言語で実装）

**改善案: Pythonで完結する実装**:

```python
import docker
import redis

def check_container_health(container_name):
    """Dockerコンテナの状態を直接確認"""
    client = docker.from_env()
    try:
        container = client.containers.get(container_name)
        return container.status == 'running'
    except docker.errors.NotFound:
        return False

def check_redis_connection(host='redis', port=6379):
    """Redis接続を直接確認"""
    try:
        r = redis.Redis(host=host, port=port, socket_timeout=2)
        return r.ping()
    except (redis.ConnectionError, redis.TimeoutError):
        return False
```

**メリット**:
- パフォーマンス向上（サブプロセス起動のオーバーヘッドがない）
- エラーハンドリングが一貫（すべてPython内で完結）
- メンテナンス性向上（単一言語で実装）
- より詳細な情報取得が可能（docker-pyやredis-pyの機能を活用）

**実装タイミング**:
- 現在のPhase 1〜4の実装完了後
- パフォーマンスやメンテナンス性の問題が顕在化した場合
- または、余裕があれば段階的に移行

**依存ライブラリ**:
- `docker-py`: Dockerコンテナの状態確認
- `redis-py`: Redis接続確認

### 2. その他の改善項目

- **キャッシュ機能**: 頻繁なヘルスチェックリクエストに対して結果をキャッシュ（例: 5秒間）
- **メトリクス収集**: Prometheus形式のメトリクスエンドポイント追加
- **アラート機能**: 異常検知時に外部システムへ通知
- **並列チェック**: 各コンポーネントのチェックを並列実行してパフォーマンス向上

## 参考資料

- [既存health-check.sh](../../scripts/openappsec/health-check.sh)
- [モックAPIサーバー](../../config-agent/mock-api-server.py)
- [OpenAppSec公式ドキュメント](https://docs.openappsec.io/)
- [Docker Compose設定](../../docker/docker-compose.yml)
