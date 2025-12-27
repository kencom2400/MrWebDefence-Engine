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
ISSUE_INFO=$(jira_api_call "GET" "issue/${ISSUE_KEY}?fields=summary,status,issuetype,description,created,updated,parent" 2>&1)

API_CALL_EXIT=$?
if [ $API_CALL_EXIT -eq 0 ] && echo "$ISSUE_INFO" | jq -e . >/dev/null 2>&1; then
  # set -eの影響を避けるため、一時的に無効化
  set +e
  ISSUE_TITLE=$(echo "$ISSUE_INFO" | jq -r '.fields.summary' 2>/dev/null || echo "")
  ISSUE_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name' 2>/dev/null || echo "")
  ISSUE_TYPE=$(echo "$ISSUE_INFO" | jq -r '.fields.issuetype.name' 2>/dev/null || echo "")
  ISSUE_DESCRIPTION=$(echo "$ISSUE_INFO" | jq -r '.fields.description.content[]? | .content[]? | .text // empty' 2>/dev/null | tr '\n' ' ' || echo "")
  CREATED=$(echo "$ISSUE_INFO" | jq -r '.fields.created' 2>/dev/null || echo "")
  UPDATED=$(echo "$ISSUE_INFO" | jq -r '.fields.updated' 2>/dev/null || echo "")
  
  # parentフィールドの取得（APIレスポンスに含まれている場合）
  PARENT_KEY=$(echo "$ISSUE_INFO" | jq -r '.fields.parent.key // empty' 2>/dev/null || echo "")
  
  # 親タスク情報の取得
  PARENT_SUMMARY=""
  PARENT_TYPE=""
  if [ -n "$PARENT_KEY" ]; then
    PARENT_SUMMARY=$(echo "$ISSUE_INFO" | jq -r '.fields.parent.fields.summary // empty' 2>/dev/null || echo "")
    PARENT_TYPE=$(echo "$ISSUE_INFO" | jq -r '.fields.parent.fields.issuetype.name // empty' 2>/dev/null || echo "")
  fi
  
  echo "✅ Issueキー: $ISSUE_KEY"
  echo "✅ タイトル: $ISSUE_TITLE"
  echo "✅ Issue種別: $ISSUE_TYPE"
  echo "✅ ステータス: $ISSUE_STATUS"
  
  # 親タスク情報を表示（set +eの範囲内で実行）
  if [ -n "$PARENT_KEY" ]; then
    echo "✅ 親タスク: $PARENT_KEY"
    if [ -n "$PARENT_SUMMARY" ]; then
      echo "   タイトル: $PARENT_SUMMARY"
    fi
    if [ -n "$PARENT_TYPE" ]; then
      echo "   Issue種別: $PARENT_TYPE"
    fi
  fi
  
  # set -eを再有効化（親タスク情報の表示後）
  set -e
  
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

