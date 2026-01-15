#!/usr/bin/env python3
"""
モックAPIサーバー（Python版）
ConfigAgentの動作確認用の簡単なHTTPサーバー
"""

import json
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

PORT = int(os.environ.get('MOCK_API_PORT', '8080'))
CONFIG_FILE = os.environ.get('MOCK_API_CONFIG_FILE', '/tmp/mock-api-config.json')

# デフォルト設定データ
DEFAULT_CONFIG = {
    "version": "1.0.0",
    "default_mode": "detect-learn",
    "default_custom_response": 403,
    "fqdns": [
        {
            "fqdn": "test.example.com",
            "is_active": True,
            "waf_mode": "detect-learn",
            "custom_response": 403,
            "backend_host": "httpbin.org",
            "backend_port": 80,
            "backend_path": "/get"
        },
        {
            "fqdn": "example1.com",
            "is_active": True,
            "waf_mode": "detect-learn",
            "custom_response": 403,
            "backend_host": "httpbin.org",
            "backend_port": 80,
            "backend_path": "/json"
        },
        {
            "fqdn": "example2.com",
            "is_active": True,
            "waf_mode": "detect-learn",
            "custom_response": 403,
            "backend_host": "httpbin.org",
            "backend_port": 80,
            "backend_path": "/xml"
        },
        {
            "fqdn": "example3.com",
            "is_active": True,
            "waf_mode": "detect-learn",
            "custom_response": 403,
            "backend_host": "httpbin.org",
            "backend_port": 80,
            "backend_path": "/get"
        }
    ]
}


class MockAPIHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Authorizationヘッダーの確認
        auth_header = self.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            self.send_response(401)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "error": "Unauthorized: API token required"
            }).encode('utf-8'))
            return
        
        if path == '/engine/v1/config':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            # 設定ファイルを読み込む
            if os.path.exists(CONFIG_FILE):
                with open(CONFIG_FILE, 'r') as f:
                    config_data = json.load(f)
            else:
                config_data = DEFAULT_CONFIG
                # デフォルト設定をファイルに保存
                with open(CONFIG_FILE, 'w') as f:
                    json.dump(config_data, f, indent=2)
            
            self.wfile.write(json.dumps(config_data).encode('utf-8'))
        
        elif path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy"}).encode('utf-8'))
        
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}).encode('utf-8'))
    
    def log_message(self, format, *args):
        # ログ出力を抑制（オプション）
        pass


def main():
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  モックAPIサーバーを起動中...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print(f"ポート: {PORT}")
    print(f"設定ファイル: {CONFIG_FILE}")
    print("")
    print("エンドポイント:")
    print("  GET /engine/v1/config - 設定データを取得")
    print("  GET /health - ヘルスチェック")
    print("")
    print("停止するには Ctrl+C を押してください")
    print("")
    
    # 設定ファイルが存在しない場合は作成
    if not os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'w') as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
        print(f"✅ デフォルト設定ファイルを作成しました: {CONFIG_FILE}")
        print("")
    
    server = HTTPServer(('0.0.0.0', PORT), MockAPIHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nサーバーを停止します...")
        server.shutdown()


if __name__ == '__main__':
    main()
