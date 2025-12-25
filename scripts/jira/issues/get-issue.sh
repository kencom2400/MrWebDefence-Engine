#!/bin/bash

# Issue情報取得スクリプト
# このスクリプトは、指定されたIssueの詳細情報を取得します。

set -e

# 共通関数の読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../common.sh" ]; then
  source "${SCRIPT_DIR}/../common.sh"
fi

# 引数確認
if [ $# -lt 1 ]; then
  echo "使い方: $0 <issue_key> [--json]" >&2
  echo "例: $0 TEST-1" >&2
  echo "例: $0 TEST-1 --json" >&2
  exit 1
fi

ISSUE_KEY="$1"
OUTPUT_JSON="${2:-}"

echo "=================================================================================="
echo "Issue情報取得"
echo "=================================================================================="
echo ""
echo "Issueキー: $ISSUE_KEY"
echo ""

echo "🔄 Issue情報を取得中..."
ISSUE_INFO=$(jira_api_call "GET" "issue/${ISSUE_KEY}")

if [ $? -eq 0 ] && echo "$ISSUE_INFO" | jq -e . >/dev/null 2>&1; then
  ISSUE_TITLE=$(echo "$ISSUE_INFO" | jq -r '.fields.summary')
  ISSUE_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')
  ISSUE_TYPE=$(echo "$ISSUE_INFO" | jq -r '.fields.issuetype.name')
  ISSUE_DESCRIPTION=$(echo "$ISSUE_INFO" | jq -r '.fields.description.content[]? | .content[]? | .text // empty' | tr '\n' ' ')
  CREATED=$(echo "$ISSUE_INFO" | jq -r '.fields.created')
  UPDATED=$(echo "$ISSUE_INFO" | jq -r '.fields.updated')
  
  echo "✅ Issueキー: $ISSUE_KEY"
  echo "✅ タイトル: $ISSUE_TITLE"
  echo "✅ Issue種別: $ISSUE_TYPE"
  echo "✅ ステータス: $ISSUE_STATUS"
  if [ -n "$ISSUE_DESCRIPTION" ]; then
    echo "✅ 説明: ${ISSUE_DESCRIPTION:0:100}..."
  fi
  echo "✅ 作成日時: $CREATED"
  echo "✅ 更新日時: $UPDATED"
  
  if [ "$OUTPUT_JSON" = "--json" ]; then
    echo ""
    echo "JSON形式:"
    echo "$ISSUE_INFO" | jq .
  fi
else
  echo "❌ エラー: Issue情報の取得に失敗しました" >&2
  handle_jira_error "$ISSUE_INFO"
  exit 1
fi

echo ""
echo "=================================================================================="

