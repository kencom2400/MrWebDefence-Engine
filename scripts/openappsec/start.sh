#!/bin/bash

# サービス起動スクリプト（エイリアス）
# service.sh start のショートカット

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/service.sh" start "$@"
