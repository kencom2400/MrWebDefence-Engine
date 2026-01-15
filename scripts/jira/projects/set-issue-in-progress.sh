#!/bin/bash

# JiraでIssueのステータスを"In Progress"に変更するスクリプト
# 注: このスクリプトは transition-issue.sh のラッパーです

set -euo pipefail

# 使い方
if [ $# -ne 1 ]; then
  echo "使い方: $0 <issue_key>"
  echo "例: $0 MWD-123"
  exit 1
fi

ISSUE_KEY=$1

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# transition-issue.sh を呼び出す
"${SCRIPT_DIR}/transition-issue.sh" "$ISSUE_KEY" "In Progress"

