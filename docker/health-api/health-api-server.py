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
