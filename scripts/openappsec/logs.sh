#!/bin/bash

# ログ表示スクリプト（エイリアス）
# service.sh logs のショートカット

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -fオプションが指定されている場合はlogs-followを使用
if [ "${1:-}" = "-f" ] || [ "${1:-}" = "--follow" ]; then
    shift
    "${SCRIPT_DIR}/service.sh" logs-follow "$@"
else
    "${SCRIPT_DIR}/service.sh" logs "$@"
fi
