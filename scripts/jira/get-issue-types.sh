#!/bin/bash

# Issue種別取得スクリプト
# このスクリプトは、指定されたプロジェクトのIssue種別を取得します。

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
echo "Issue種別取得"
echo "=================================================================================="
echo ""
echo "プロジェクトキー: $PROJECT_KEY"
echo ""

echo "🔄 Issue種別を取得中..."
ISSUE_TYPES_DATA=$(jira_api_call "GET" "issue/createmeta?projectKeys=${PROJECT_KEY}&expand=projects.issuetypes")

if [ $? -eq 0 ] && echo "$ISSUE_TYPES_DATA" | jq -e . >/dev/null 2>&1; then
  ISSUE_TYPES=$(echo "$ISSUE_TYPES_DATA" | jq -r '.projects[0].issuetypes[] | "\(.id)|\(.name)|\(.description // "説明なし")"')
  ISSUE_TYPE_COUNT=$(echo "$ISSUE_TYPES_DATA" | jq -r '.projects[0].issuetypes | length')
  
  echo "✅ 取得したIssue種別数: $ISSUE_TYPE_COUNT"
  echo ""
  echo "Issue種別一覧:"
  echo "----------------------------------------------------------------------------------"
  echo "$ISSUE_TYPES" | while IFS='|' read -r id name description; do
    printf "  ID: %-10s  名前: %-30s  説明: %s\n" "$id" "$name" "$description"
  done
  
  if [ "$OUTPUT_JSON" = "--json" ]; then
    echo ""
    echo "JSON形式:"
    echo "$ISSUE_TYPES_DATA" | jq .
  fi
else
  echo "❌ エラー: Issue種別の取得に失敗しました" >&2
  handle_jira_error "$ISSUE_TYPES_DATA"
  exit 1
fi

echo ""
echo "=================================================================================="

