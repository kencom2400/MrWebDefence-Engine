#!/bin/bash

# Jira Issue削除スクリプト
# このスクリプトは、JiraのIssueを削除します。

set -e

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${JIRA_SCRIPT_DIR}/common.sh" ]; then
  source "${JIRA_SCRIPT_DIR}/common.sh"
fi

# 使用方法を表示
show_usage() {
    cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Jira Issue削除スクリプト
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

使用方法:

  $0 <issue_key> [--force]

引数:
  issue_key           削除するIssueキー（例: MWD-1）
  --force             確認なしで削除（オプション）
  --help              このヘルプを表示

例:
  # 対話型（確認あり）
  $0 MWD-1

  # 強制削除（確認なし）
  $0 MWD-1 --force

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# 引数解析
ISSUE_KEY=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*)
            echo "❌ エラー: 不明なオプション: $1" >&2
            echo "" >&2
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$ISSUE_KEY" ]; then
                ISSUE_KEY="$1"
            else
                echo "❌ エラー: 複数のIssueキーが指定されています: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# 必須項目チェック
if [ -z "$ISSUE_KEY" ]; then
    echo "❌ エラー: Issueキーが指定されていません" >&2
    echo "" >&2
    show_usage
    exit 1
fi

# Issue情報を取得して確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🗑️  Issue削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Issueキー: $ISSUE_KEY"
echo ""

echo "🔄 Issue情報を取得中..."
ISSUE_INFO=$(jira_api_call "GET" "issue/${ISSUE_KEY}")

if [ $? -ne 0 ] || ! echo "$ISSUE_INFO" | jq -e . >/dev/null 2>&1; then
  echo "❌ エラー: Issue情報の取得に失敗しました" >&2
  handle_jira_error "$ISSUE_INFO"
  exit 1
fi

ISSUE_TITLE=$(echo "$ISSUE_INFO" | jq -r '.fields.summary')
ISSUE_TYPE=$(echo "$ISSUE_INFO" | jq -r '.fields.issuetype.name')
ISSUE_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')

echo "✅ Issueキー: $ISSUE_KEY"
echo "✅ タイトル: $ISSUE_TITLE"
echo "✅ Issue種別: $ISSUE_TYPE"
echo "✅ ステータス: $ISSUE_STATUS"
echo ""

# 確認（--forceが指定されていない場合）
if [ "$FORCE" = false ]; then
    echo "⚠️  このIssueを削除しますか？"
    read -p "削除する場合は 'yes' を入力してください: " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "❌ 削除がキャンセルされました"
        exit 0
    fi
    echo ""
fi

# Issueを削除
echo "🔄 Issueを削除中..."
AUTH_HEADER=$(get_auth_header)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  -H "Authorization: Basic ${AUTH_HEADER}" \
  -H "Accept: application/json" \
  "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}?deleteSubtasks=false")

if [ "$HTTP_CODE" = "204" ]; then
    echo "✅ Issue削除成功"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Issue削除完了"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "削除されたIssue: $ISSUE_KEY"
    echo "タイトル: $ISSUE_TITLE"
    echo ""
else
    echo "❌ エラー: Issue削除に失敗しました (HTTP ${HTTP_CODE})" >&2
    
    # エラー詳細を取得
    ERROR_RESPONSE=$(curl -s -X DELETE \
      -H "Authorization: Basic ${AUTH_HEADER}" \
      -H "Accept: application/json" \
      "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}?deleteSubtasks=false" 2>&1)
    
    handle_jira_error "$ERROR_RESPONSE"
    exit 1
fi

