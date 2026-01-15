#!/bin/bash

# サービス再起動スクリプト（エイリアス）
# service.sh restart のショートカット

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/service.sh" restart "$@"
