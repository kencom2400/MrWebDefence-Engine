#!/bin/bash

# サービス状態表示スクリプト（エイリアス）
# service.sh status のショートカット

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/service.sh" status "$@"
