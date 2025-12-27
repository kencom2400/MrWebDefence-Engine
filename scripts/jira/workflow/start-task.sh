#!/bin/bash

# @start-task コマンドの実装（Jira版）
# 
# 使い方:
#   start-task.sh [ISSUE_KEY]
#
# 引数なし: Jiraから「To Do」ステータスの最優先Issueを自動選択
# 引数あり: 指定したIssueキーで作業を開始

# 設定ファイルの読み込み（set -eの前に実行）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${JIRA_SCRIPT_DIR}/config.sh" ]; then
  source "${JIRA_SCRIPT_DIR}/config.sh" 2>/dev/null || true
fi

# エラーハンドリング
trap 'echo "❌ エラー: スクリプトが異常終了しました (行: $LINENO)" >&2; exit 1' ERR

set -e

# 共通関数の読み込み
if [ -f "${JIRA_SCRIPT_DIR}/common.sh" ]; then
  source "${JIRA_SCRIPT_DIR}/common.sh"
else
  echo "❌ エラー: ${JIRA_SCRIPT_DIR}/common.sh が見つかりません" >&2
  exit 1
fi

# 使い方表示
show_usage() {
  cat << EOF
使い方: $0 [ISSUE_KEY]

引数なし: Jiraから「To Do」ステータスの最優先Issueを自動選択
引数あり: 指定したIssueキーで作業を開始

例:
  $0              # 最優先Issueを自動選択
  $0 MWD-123      # Issue MWD-123を開始

オプション:
  -h, --help     このヘルプを表示
EOF
}

# ヘルプオプション
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_usage
  exit 0
fi

# Issue情報を取得する関数
get_issue_info() {
  local ISSUE_KEY=$1
  
  jira_api_call "GET" "issue/${ISSUE_KEY}" 2>/dev/null
}

# Issueの存在確認とステータス取得
check_issue_exists() {
  local ISSUE_KEY=$1
  
  echo "🔍 Issue ${ISSUE_KEY} を確認中..." >&2
  
  ISSUE_INFO=$(get_issue_info "$ISSUE_KEY")
  local EXIT_CODE=$?
  
  if [ $EXIT_CODE -ne 0 ] || [ -z "$ISSUE_INFO" ] || ! echo "$ISSUE_INFO" | jq -e . > /dev/null 2>&1; then
    echo "❌ エラー: Issue ${ISSUE_KEY} が見つかりません" >&2
    exit 1
  fi
  
  echo "$ISSUE_INFO"
}

# Issueのステータス確認
check_issue_state() {
  local ISSUE_INFO=$1
  local ISSUE_KEY=$2
  
  STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')
  STATUS_CATEGORY=$(echo "$ISSUE_INFO" | jq -r '.fields.status.statusCategory.key')
  
  if [ "$STATUS_CATEGORY" = "done" ]; then
    echo "❌ エラー: Issue ${ISSUE_KEY} は既に完了しています"
    echo "   ステータス: ${STATUS}"
    exit 1
  fi
}

# アサイン状況の確認
check_assignee() {
  local ISSUE_INFO=$1
  local ISSUE_KEY=$2
  
  ASSIGNEE=$(echo "$ISSUE_INFO" | jq -r '.fields.assignee.accountId // empty')
  
  if [ -n "$ASSIGNEE" ]; then
    ASSIGNEE_NAME=$(echo "$ISSUE_INFO" | jq -r '.fields.assignee.displayName // .fields.assignee.name // "不明"')
    CURRENT_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')
    
    # 現在のユーザーを取得（Jira APIから）
    CURRENT_USER_INFO=$(jira_api_call "GET" "myself" 2>/dev/null)
    if [ $? -eq 0 ]; then
      CURRENT_USER_ID=$(echo "$CURRENT_USER_INFO" | jq -r '.accountId')
      
      if [ "$ASSIGNEE" = "$CURRENT_USER_ID" ]; then
        # 既に自分にアサインされている場合は自動で続行（確認プロンプトなし）
        echo "ℹ️  Issue ${ISSUE_KEY} は既にあなたにアサインされています"
      else
        echo "❌ エラー: Issue ${ISSUE_KEY} は既に ${ASSIGNEE_NAME} にアサインされています"
        echo "   ステータス: ${CURRENT_STATUS}"
        echo ""
        echo "※ 先にアサインを解除するか、別のIssueを選択してください"
        exit 1
      fi
    else
      # ユーザー情報取得に失敗した場合は警告のみ
      echo "⚠️  警告: 現在のユーザー情報を取得できませんでした"
    fi
  fi
}

# Issueキーで開始
start_task_by_key() {
  local ISSUE_KEY=$1
  
  # Issue情報を取得
  ISSUE_INFO=$(check_issue_exists "$ISSUE_KEY")
  
  # ステータス確認
  check_issue_state "$ISSUE_INFO" "$ISSUE_KEY"
  
  # アサイン状況確認
  check_assignee "$ISSUE_INFO" "$ISSUE_KEY"
  
  # Issueタイトル取得
  TITLE=$(echo "$ISSUE_INFO" | jq -r '.fields.summary')
  
  echo ""
  echo "📋 開始するIssue:"
  echo "   ${ISSUE_KEY}: ${TITLE}"
  echo ""
  
  # 自分にアサイン（まだアサインされていない場合）
  ASSIGNEE=$(echo "$ISSUE_INFO" | jq -r '.fields.assignee.accountId // empty')
  if [ -z "$ASSIGNEE" ]; then
    echo "👤 アサイン中..."
    CURRENT_USER_INFO=$(jira_api_call "GET" "myself" 2>/dev/null)
    if [ $? -eq 0 ]; then
      CURRENT_USER_ID=$(echo "$CURRENT_USER_INFO" | jq -r '.accountId')
      ASSIGN_DATA=$(jq -n --arg account_id "$CURRENT_USER_ID" '{fields: {assignee: {accountId: $account_id}}}')
      jira_api_call "PUT" "issue/${ISSUE_KEY}" "$ASSIGN_DATA" > /dev/null 2>&1
    else
      echo "⚠️  警告: アサインに失敗しました（続行します）"
    fi
  fi
  
  # mainブランチを最新化
  echo "🔄 mainブランチを最新化中..."
  git checkout main > /dev/null 2>&1 || true
  git pull origin main > /dev/null 2>&1 || true
  
  # ブランチ名を生成（kebab-case）
  # 英数字以外の文字はすべてハイフンに置き換え、先頭と末尾のハイフンを削除
  BRANCH_NAME="feature/${ISSUE_KEY}-$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g' | cut -c1-60)"
  
  # ブランチが既に存在する場合はチェックアウト、存在しない場合は作成
  if git show-ref --verify --quiet refs/heads/"$BRANCH_NAME" 2>/dev/null; then
    echo "🌿 既存のブランチに切り替え中: ${BRANCH_NAME}"
    git checkout "$BRANCH_NAME" > /dev/null 2>&1 || true
  else
    echo "🌿 ブランチを作成中: ${BRANCH_NAME}"
    git checkout -b "$BRANCH_NAME" > /dev/null 2>&1 || true
  fi
  
  # ステータスを In Progress に変更
  echo "🚧 ステータスを 'In Progress' に変更中..."
  "${SCRIPT_DIR}/../projects/set-issue-in-progress.sh" "$ISSUE_KEY" > /dev/null 2>&1 || {
    echo "⚠️  警告: ステータス変更に失敗しました（続行します）"
  }
  
  echo ""
  echo "✅ Issue ${ISSUE_KEY} を開始しました"
  echo "   タイトル: ${TITLE}"
  echo "   ステータス: In Progress"
  echo "   ブランチ: ${BRANCH_NAME}"
  echo ""
  echo "Issue URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
  echo ""
}

# 最優先Issueを自動選択
select_priority_issue() {
  local PROJECT_KEY="${JIRA_PROJECT_KEY:-${TEST_PROJECT_KEY:-}}"
  
  if [ -z "$PROJECT_KEY" ]; then
    echo "❌ エラー: プロジェクトキーが設定されていません" >&2
    echo "   環境変数 JIRA_PROJECT_KEY または TEST_PROJECT_KEY を設定してください" >&2
    exit 1
  fi
  
  echo "🔍 Jiraから最優先Issueを取得中..."
  echo ""
  
  # 現在のユーザーを取得
  set +e
  CURRENT_USER_INFO=$(jira_api_call "GET" "myself" 2>&1)
  local api_exit_code=$?
  set -e
  
  if [ $api_exit_code -ne 0 ] || [ -z "$CURRENT_USER_INFO" ] || ! echo "$CURRENT_USER_INFO" | jq -e . > /dev/null 2>&1; then
    echo "❌ エラー: ユーザー情報の取得に失敗しました" >&2
    if [ -n "$CURRENT_USER_INFO" ]; then
      echo "   詳細: ${CURRENT_USER_INFO}" >&2
    fi
    exit 1
  fi
  CURRENT_USER_ID=$(echo "$CURRENT_USER_INFO" | jq -r '.accountId')
  
  # 「To Do」ステータスで自分にアサインされているIssueを取得
  # JQL: project = PROJECT_KEY AND status = "To Do" AND assignee = currentUser() ORDER BY priority DESC, created ASC
  JQL="project = ${PROJECT_KEY} AND status = \"To Do\" AND assignee = currentUser() ORDER BY priority DESC, created ASC"
  JQL_DATA=$(jq -n \
    --arg jql "$JQL" \
    '{
      jql: $jql,
      maxResults: 50,
      fields: ["summary", "status", "priority", "assignee"]
    }')
  
  set +e
  TODO_ISSUES=$(jira_api_call "POST" "search/jql" "$JQL_DATA" 2>&1)
  local search_exit_code=$?
  set -e
  
  if [ $search_exit_code -ne 0 ] || [ -z "$TODO_ISSUES" ] || ! echo "$TODO_ISSUES" | jq -e '.issues | length > 0' > /dev/null 2>&1; then
    echo "❌ 自分にアサインされた「To Do」ステータスのIssueが見つかりません"
    if [ -n "$TODO_ISSUES" ]; then
      echo "   詳細: $(echo "$TODO_ISSUES" | head -c 200)" >&2
    fi
    exit 1
  fi
  
  # 優先度でソート（priority: critical > high > medium > low > 未設定）
  PRIORITY_ISSUE=$(echo "$TODO_ISSUES" | jq '
    .issues |
    map({
      key: .key,
      title: .fields.summary,
      priority: (
        if .fields.priority.name == "Critical" then 4
        elif .fields.priority.name == "High" then 3
        elif .fields.priority.name == "Medium" then 2
        elif .fields.priority.name == "Low" then 1
        else 0
        end
      )
    }) |
    sort_by(-.priority, .key) |
    .[0]
  ')
  
  # nullチェック
  if [ -z "$PRIORITY_ISSUE" ] || [ "$PRIORITY_ISSUE" = "null" ] || ! echo "$PRIORITY_ISSUE" | jq -e '.key' > /dev/null 2>&1; then
    echo "❌ 「To Do」ステータスのIssueが見つかりません"
    exit 1
  fi
  
  ISSUE_KEY=$(echo "$PRIORITY_ISSUE" | jq -r '.key')
  TITLE=$(echo "$PRIORITY_ISSUE" | jq -r '.title')
  PRIORITY=$(echo "$PRIORITY_ISSUE" | jq -r '.priority')
  
  PRIORITY_LABEL=""
  case $PRIORITY in
    4) PRIORITY_LABEL="Critical" ;;
    3) PRIORITY_LABEL="High" ;;
    2) PRIORITY_LABEL="Medium" ;;
    1) PRIORITY_LABEL="Low" ;;
    0) PRIORITY_LABEL="（未設定）" ;;
  esac
  
  echo "📌 最優先Issue: ${ISSUE_KEY}"
  echo "   タイトル: ${TITLE}"
  echo "   優先度: ${PRIORITY_LABEL}"
  echo ""
  
  # 選択したIssueで開始
  start_task_by_key "$ISSUE_KEY"
}

# メイン処理
main() {
  if [ $# -eq 0 ]; then
    # 引数なし: 最優先Issueを自動選択
    select_priority_issue
  else
    # 引数あり: Issueキーを指定
    ISSUE_KEY=$1
    
    # Issueキーの形式チェック（PROJECT-NUMBER形式）
    if ! [[ "$ISSUE_KEY" =~ ^[A-Z]+-[0-9]+$ ]]; then
      echo "❌ エラー: 無効なIssueキー形式です"
      echo "   正しい形式: MWD-123"
      exit 1
    fi
    
    start_task_by_key "$ISSUE_KEY"
  fi
}

# スクリプト実行
main "$@"

