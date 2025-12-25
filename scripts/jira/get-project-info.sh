#!/bin/bash

# プロジェクト情報取得スクリプト
# このスクリプトは、指定されたプロジェクトの情報を取得します。

set -e

# 共通関数の読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# 引数確認
if [ $# -lt 1 ]; then
  echo "使い方: $0 <project_key> [--json]" >&2
  echo "例: $0 TEST" >&2
  echo "例: $0 TEST --json" >&2
  exit 1
fi

PROJECT_KEY="$1"
OUTPUT_JSON="${2:-}"

echo "=================================================================================="
echo "プロジェクト情報取得"
echo "=================================================================================="
echo ""
echo "プロジェクトキー: $PROJECT_KEY"
echo ""

echo "🔄 プロジェクト情報を取得中..."
PROJECT_INFO=$(jira_api_call "GET" "project/${PROJECT_KEY}")

if [ $? -eq 0 ] && echo "$PROJECT_INFO" | jq -e . >/dev/null 2>&1; then
  PROJECT_NAME=$(echo "$PROJECT_INFO" | jq -r '.name')
  PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r '.id')
  PROJECT_KEY_RESULT=$(echo "$PROJECT_INFO" | jq -r '.key')
  
  echo "✅ プロジェクト名: $PROJECT_NAME"
  echo "✅ プロジェクトキー: $PROJECT_KEY_RESULT"
  echo "✅ プロジェクトID: $PROJECT_ID"
  
  if [ "$OUTPUT_JSON" = "--json" ]; then
    echo ""
    echo "JSON形式:"
    echo "$PROJECT_INFO" | jq .
  fi
else
  echo "❌ エラー: プロジェクト情報の取得に失敗しました" >&2
  handle_jira_error "$PROJECT_INFO"
  exit 1
fi

echo ""
echo "=================================================================================="

