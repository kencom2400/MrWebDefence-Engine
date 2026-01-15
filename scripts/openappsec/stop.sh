#!/bin/bash

# サービス停止スクリプト（エイリアス）
# service.sh stop のショートカット

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/service.sh" stop "$@"
