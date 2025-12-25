#!/bin/bash

# ステータス遷移実行スクリプト
# このスクリプトは、指定されたIssueのステータスを遷移します。

set -e

# 共通関数の読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# 引数確認
if [ $# -lt 2 ]; then
  echo "使い方: $0 <issue_key> <transition_name>" >&2
  echo "例: $0 TEST-1 \"To Do\"" >&2
  echo "例: $0 TEST-1 \"In Progress\"" >&2
  exit 1
fi

ISSUE_KEY="$1"
TRANSITION_NAME="$2"

echo "=================================================================================="
echo "ステータス遷移実行"
echo "=================================================================================="
echo ""
echo "Issueキー: $ISSUE_KEY"
echo "遷移名: $TRANSITION_NAME"
echo ""

# まず、遷移可能なステータスを取得
echo "🔄 遷移可能なステータスを取得中..."
TRANSITIONS_DATA=$(jira_api_call "GET" "issue/${ISSUE_KEY}/transitions")

if [ $? -ne 0 ] || ! echo "$TRANSITIONS_DATA" | jq -e . >/dev/null 2>&1; then
  echo "❌ エラー: ステータス遷移情報の取得に失敗しました" >&2
  handle_jira_error "$TRANSITIONS_DATA"
  exit 1
fi

# ステータス名をマッピング（英語名 → 日本語名）
MAPPED_STATUS_NAME=$(map_status_name "$TRANSITION_NAME" "$ISSUE_KEY")

# 遷移IDを取得（マッピング後の名前で検索）
TRANSITION_ID=$(echo "$TRANSITIONS_DATA" | jq -r --arg name "$MAPPED_STATUS_NAME" '.transitions[] | select(.name == $name) | .id')

# マッピング後の名前で見つからない場合、元の名前で再試行
if [ -z "$TRANSITION_ID" ] || [ "$TRANSITION_ID" = "null" ]; then
  TRANSITION_ID=$(echo "$TRANSITIONS_DATA" | jq -r --arg name "$TRANSITION_NAME" '.transitions[] | select(.name == $name) | .id')
fi

if [ -z "$TRANSITION_ID" ] || [ "$TRANSITION_ID" = "null" ]; then
  echo "❌ エラー: 遷移名 '$TRANSITION_NAME' が見つかりませんでした" >&2
  echo "" >&2
  echo "利用可能な遷移名:" >&2
  echo "$TRANSITIONS_DATA" | jq -r '.transitions[] | "  - \(.name)"' >&2
  exit 1
fi

# ステータス遷移を実行
TRANSITION_DATA=$(jq -n \
  --arg transition_id "$TRANSITION_ID" \
  '{
    transition: {
      id: $transition_id
    }
  }')

echo "🔄 ステータスを遷移中..."
RESPONSE=$(jira_api_call "POST" "issue/${ISSUE_KEY}/transitions" "$TRANSITION_DATA")

if [ $? -eq 0 ]; then
  echo "✅ ステータス遷移成功"
  echo ""
  
  # 更新後のIssue情報を取得
  echo "📋 更新後のIssue情報を取得中..."
  ISSUE_INFO=$(jira_api_call "GET" "issue/${ISSUE_KEY}")
  if [ $? -eq 0 ]; then
    CURRENT_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')
    echo "✅ 現在のステータス: $CURRENT_STATUS"
  fi
else
  echo "❌ エラー: ステータス遷移に失敗しました" >&2
  handle_jira_error "$RESPONSE"
  exit 1
fi

echo ""
echo "=================================================================================="

