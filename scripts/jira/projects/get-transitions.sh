#!/bin/bash

# ステータス遷移取得スクリプト
# このスクリプトは、指定されたIssueの遷移可能なステータスを取得します。

set -e

# 共通関数の読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../common.sh" ]; then
  source "${SCRIPT_DIR}/../common.sh"
fi

# 引数確認
if [ $# -lt 1 ]; then
  echo "使い方: $0 <issue_key>" >&2
  echo "例: $0 TEST-1" >&2
  exit 1
fi

ISSUE_KEY="$1"

echo "=================================================================================="
echo "ステータス遷移取得"
echo "=================================================================================="
echo ""
echo "Issueキー: $ISSUE_KEY"
echo ""

echo "🔄 ステータス遷移情報を取得中..."
TRANSITIONS_DATA=$(jira_api_call "GET" "issue/${ISSUE_KEY}/transitions")

if [ $? -eq 0 ] && echo "$TRANSITIONS_DATA" | jq -e . >/dev/null 2>&1; then
  TRANSITION_COUNT=$(echo "$TRANSITIONS_DATA" | jq -r '.transitions | length')
  echo "✅ 遷移可能なステータス数: $TRANSITION_COUNT"
  echo ""
  
  if [ "$TRANSITION_COUNT" -gt 0 ]; then
    echo "遷移可能なステータス一覧:"
    echo "----------------------------------------------------------------------------------"
    echo "$TRANSITIONS_DATA" | jq -r '.transitions[] | "\(.id) | \(.name) | \(.to.name)"' | \
      awk -F'|' '{printf "  ID: %-10s  遷移名: %-30s  遷移先: %s\n", $1, $2, $3}'
    echo ""
    
    # JSON形式でも出力（オプション）
    if [ "${2:-}" = "--json" ]; then
      echo "JSON形式:"
      echo "$TRANSITIONS_DATA" | jq .
    fi
  else
    echo "⚠️  遷移可能なステータスがありません"
  fi
else
  echo "❌ エラー: ステータス遷移情報の取得に失敗しました" >&2
  handle_jira_error "$TRANSITIONS_DATA"
  exit 1
fi

echo "=================================================================================="

