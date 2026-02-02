#!/usr/bin/env python3
"""
ヘルスチェックAPIサーバー
WAFエンジンの各コンポーネントの状態を返すHTTP APIサーバー
"""

import json
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
import os
import logging
import hmac
import sys

# ロギング設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('health-api')

PORT = int(os.environ.get('HEALTH_API_PORT', '8888'))
HEALTH_CHECK_SCRIPT = '/app/scripts/health-check.sh'

# セキュリティ: API認証トークン（環境変数から取得）
# Fail-Closed原則: トークンが設定されていない場合は起動しない
API_TOKEN = os.environ.get('HEALTH_API_TOKEN', '')
ALLOW_UNAUTHENTICATED = os.environ.get('ALLOW_UNAUTHENTICATED', 'false').lower() == 'true'

if not API_TOKEN:
    if ALLOW_UNAUTHENTICATED:
        logger.warning("⚠️  HEALTH_API_TOKEN が設定されていません。開発環境専用モードで起動します。")
        logger.warning("⚠️  本番環境では ALLOW_UNAUTHENTICATED=false にして必ずトークンを設定してください。")
    else:
        logger.error("❌ エラー: HEALTH_API_TOKEN が設定されていません。")
        logger.error("開発環境で認証なしで起動する場合は ALLOW_UNAUTHENTICATED=true を設定してください。")
        sys.exit(1)

class HealthAPIHandler(BaseHTTPRequestHandler):
    def _check_authentication(self):
        """API認証をチェック（タイミング攻撃対策付き）"""
        if not API_TOKEN:
            # トークンが設定されていない場合は認証をスキップ（開発環境用）
            # ALLOW_UNAUTHENTICATED=true の場合のみここに到達
            return True
        
        # Authorization ヘッダーをチェック
        auth_header = self.headers.get('Authorization', '')
        if auth_header.startswith('Bearer '):
            token = auth_header[7:]  # 'Bearer ' を除去
            # タイミング攻撃対策: hmac.compare_digest() を使用
            if hmac.compare_digest(token, API_TOKEN):
                return True
        
        return False
    
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/engine/v1/health':
            # セキュリティ: 認証チェック
            if not self._check_authentication():
                self.send_response(401)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": "Unauthorized",
                    "message": "Invalid or missing authentication token"
                }).encode('utf-8'))
                return
            
            self.handle_health_check()
        elif path == '/health':
            # 簡易版ヘルスチェック（200 OKのみ）
            # Kubernetes liveness probe用（認証不要）
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode('utf-8'))
        else:
            # セキュリティ: パス情報を漏洩させない
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "error": "Not Found"
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
                    # セキュリティ: 内部エラー詳細を漏洩させない
                    logger.error(f"Health check script failed: {result.stderr}")
                    health_data = {
                        "status": "unhealthy",
                        "message": "Health check script failed"
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
            # セキュリティ: 内部例外詳細を漏洩させない
            logger.exception("Unexpected error during health check")
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "error",
                "message": "Internal server error"
            }).encode('utf-8'))
    
    def log_message(self, format, *args):
        # アクセスログをloggingモジュールで出力
        logger.info(f"{self.address_string()} - {format % args}")

def run_server():
    # セキュリティ: マルチスレッド対応でDoS攻撃を防止
    server = ThreadingHTTPServer(('0.0.0.0', PORT), HealthAPIHandler)
    logger.info(f"✅ ヘルスチェックAPIサーバーを起動しました: http://0.0.0.0:{PORT}")
    logger.info(f"  GET /engine/v1/health - 詳細なヘルスチェック（認証必要）")
    logger.info(f"  GET /health - 簡易ヘルスチェック（認証不要）")
    
    if API_TOKEN:
        logger.info(f"  🔒 API認証: 有効")
    elif ALLOW_UNAUTHENTICATED:
        logger.warning(f"  ⚠️  API認証: 無効（開発環境専用モード）")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("\n🛑 サーバーを停止しています...")
        server.shutdown()

if __name__ == '__main__':
    run_server()
