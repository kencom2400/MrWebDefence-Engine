#!/bin/bash

# @start-task コマンドの実装
# 
# 使い方:
#   start-task.sh [#ISSUE_NUMBER]
#
# 引数なし: GitHub Projectsから「📝 To Do」または「To Do」ステータスの最優先Issueを自動選択
# 引数あり: 指定したIssue番号で作業を開始

set -e

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

# 使い方表示
show_usage() {
  cat << EOF
使い方: $0 [#ISSUE_NUMBER]

引数なし: GitHub Projectsから「📝 To Do」または「To Do」ステータスの最優先Issueを自動選択
引数あり: 指定したIssue番号で作業を開始

例:
  $0              # 最優先Issueを自動選択
  $0 #198         # Issue #198を開始
  $0 198          # Issue #198を開始（#なしでもOK）

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
  local ISSUE_NUM=$1
  
  gh issue view "$ISSUE_NUM" \
    --json number,title,state,assignees,projectItems,labels 2>/dev/null
}

# Issueの存在確認とステータス取得
check_issue_exists() {
  local ISSUE_NUM=$1
  
  echo "🔍 Issue #${ISSUE_NUM} を確認中..." >&2
  
  ISSUE_INFO=$(get_issue_info "$ISSUE_NUM")
  local EXIT_CODE=$?
  
  if [ $EXIT_CODE -ne 0 ] || [ -z "$ISSUE_INFO" ] || ! echo "$ISSUE_INFO" | jq -e . > /dev/null 2>&1; then
    echo "❌ エラー: Issue #${ISSUE_NUM} が見つかりません" >&2
    exit 1
  fi
  
  echo "$ISSUE_INFO"
}

# Issueのステータス確認
check_issue_state() {
  local ISSUE_INFO=$1
  local ISSUE_NUM=$2
  
  STATE=$(echo "$ISSUE_INFO" | jq -r '.state')
  
  if [ "$STATE" = "CLOSED" ]; then
    echo "❌ エラー: Issue #${ISSUE_NUM} は既にクローズされています"
    echo "   ステータス: ✅ Done"
    exit 1
  fi
}

# アサイン状況の確認
check_assignee() {
  local ISSUE_INFO=$1
  local ISSUE_NUM=$2
  
  ASSIGNEES_COUNT=$(echo "$ISSUE_INFO" | jq -r '.assignees | length')
  
  if [ "$ASSIGNEES_COUNT" -gt 0 ]; then
    CURRENT_ASSIGNEE=$(echo "$ISSUE_INFO" | jq -r '.assignees[0].login')
    
    # GitHub CLI で現在のユーザー名を取得
    CURRENT_USER=$(gh api user --jq '.login')
    
    if [ "$CURRENT_ASSIGNEE" = "$CURRENT_USER" ]; then
      # 既に自分にアサインされている場合は自動で続行（確認プロンプトなし）
      echo "ℹ️  Issue #${ISSUE_NUM} は既にあなたにアサインされています"
    else
      echo "❌ エラー: Issue #${ISSUE_NUM} は既に @${CURRENT_ASSIGNEE} にアサインされています"
      echo "   ステータス: $(echo "$ISSUE_INFO" | jq -r '.projectItems[0].status.name // "不明"')"
      echo ""
      echo "※ 先にアサインを解除するか、別のIssueを選択してください"
      exit 1
    fi
  fi
}

# Issue番号で開始
start_task_by_id() {
  local ISSUE_NUM=$1
  
  # Issue情報を取得
  ISSUE_INFO=$(check_issue_exists "$ISSUE_NUM")
  
  # ステータス確認
  check_issue_state "$ISSUE_INFO" "$ISSUE_NUM"
  
  # アサイン状況確認
  check_assignee "$ISSUE_INFO" "$ISSUE_NUM"
  
  # Issueタイトル取得
  TITLE=$(echo "$ISSUE_INFO" | jq -r '.title')
  
  echo ""
  echo "📋 開始するIssue:"
  echo "   #${ISSUE_NUM}: ${TITLE}"
  echo ""
  
  # 自分にアサイン（まだアサインされていない場合）
  ASSIGNEES_COUNT=$(echo "$ISSUE_INFO" | jq -r '.assignees | length')
  if [ "$ASSIGNEES_COUNT" -eq 0 ]; then
    echo "👤 アサイン中..."
    gh issue edit "$ISSUE_NUM" --add-assignee "@me"
  fi
  
  # mainブランチを最新化
  echo "🔄 mainブランチを最新化中..."
  git checkout main > /dev/null 2>&1
  git pull origin main > /dev/null 2>&1
  
  # ブランチ名を生成（kebab-case）
  # 英数字以外の文字はすべてハイフンに置き換え、先頭と末尾のハイフンを削除
  BRANCH_NAME="feature/issue-${ISSUE_NUM}-$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g' | cut -c1-60)"
  
  # ブランチが既に存在する場合はチェックアウト、存在しない場合は作成
  if git show-ref --verify --quiet refs/heads/"$BRANCH_NAME"; then
    echo "🌿 既存のブランチに切り替え中: ${BRANCH_NAME}"
    git checkout "$BRANCH_NAME" > /dev/null 2>&1
  else
    echo "🌿 ブランチを作成中: ${BRANCH_NAME}"
    git checkout -b "$BRANCH_NAME" > /dev/null 2>&1
  fi
  
  # ステータスを In Progress に変更
  echo "🚧 ステータスを '🚧 In Progress' に変更中..."
  "${SCRIPT_DIR}/set-issue-in-progress.sh" "$ISSUE_NUM" > /dev/null 2>&1
  
  echo ""
  echo "✅ Issue #${ISSUE_NUM} を開始しました"
  echo "   タイトル: ${TITLE}"
  echo "   ステータス: 🚧 In Progress"
  echo "   ブランチ: ${BRANCH_NAME}"
  echo ""
  echo "Issue URL: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues/${ISSUE_NUM}"
  echo ""
}

# 最優先Issueを自動選択
select_priority_issue() {
  echo "🔍 GitHub Projectsから最優先Issueを取得中..."
  echo ""
  
  # 「📝 To Do」または「To Do」ステータスで自分にアサインされているIssueを取得
  TODO_ISSUES=$(gh issue list \
    --state open \
    --assignee @me \
    --json number,title,labels,projectItems \
    --limit 100)
  
  if [ -z "$TODO_ISSUES" ] || [ "$TODO_ISSUES" = "[]" ]; then
    echo "❌ 自分にアサインされた「📝 To Do」または「To Do」ステータスのIssueが見つかりません"
    exit 1
  fi
  
  # 「📝 To Do」または「To Do」ステータスのIssueをフィルタリングし、優先度でソート
  PRIORITY_ISSUE=$(echo "$TODO_ISSUES" | jq '
    [
      .[] |
      select(.projectItems[0].status.name == "📝 To Do" or .projectItems[0].status.name == "To Do") |
      {
        number: .number,
        title: .title,
        priority: (
          if any(.labels[]; .name == "priority: critical") then 4
          elif any(.labels[]; .name == "priority: high") then 3
          elif any(.labels[]; .name == "priority: medium") then 2
          elif any(.labels[]; .name == "priority: low") then 1
          else 0
          end
        )
      }
    ] |
    sort_by(-.priority, .number) |
    .[0]
  ')
  
  # nullチェック（jqの結果を直接チェック）
  if [ -z "$PRIORITY_ISSUE" ] || [ "$PRIORITY_ISSUE" = "null" ] || ! echo "$PRIORITY_ISSUE" | jq -e '.number' > /dev/null 2>&1; then
    echo "❌ 「📝 To Do」または「To Do」ステータスのIssueが見つかりません"
    echo ""
    echo "📝 現在のオープンIssue（自分にアサイン）:"
    echo "$TODO_ISSUES" | jq -r '.[] | "  - #\(.number): \(.title) [\(.projectItems[0].status.name // "プロジェクト未登録")]"'
    exit 1
  fi
  
  ISSUE_NUM=$(echo "$PRIORITY_ISSUE" | jq -r '.number')
  TITLE=$(echo "$PRIORITY_ISSUE" | jq -r '.title')
  PRIORITY=$(echo "$PRIORITY_ISSUE" | jq -r '.priority')
  
  PRIORITY_LABEL=""
  case $PRIORITY in
    4) PRIORITY_LABEL="critical" ;;
    3) PRIORITY_LABEL="high" ;;
    2) PRIORITY_LABEL="medium" ;;
    1) PRIORITY_LABEL="low" ;;
    0) PRIORITY_LABEL="（未設定）" ;;
  esac
  
  echo "📌 最優先Issue: #${ISSUE_NUM}"
  echo "   タイトル: ${TITLE}"
  echo "   優先度: ${PRIORITY_LABEL}"
  echo ""
  
  # 選択したIssueで開始
  start_task_by_id "$ISSUE_NUM"
}

# メイン処理
main() {
  if [ $# -eq 0 ]; then
    # 引数なし: 最優先Issueを自動選択
    select_priority_issue
  else
    # 引数あり: Issue番号を指定
    ISSUE_ARG=$1
    
    # '#' を除去
    ISSUE_NUM="${ISSUE_ARG#\#}"
    
    # 数値チェック
    if ! [[ "$ISSUE_NUM" =~ ^[0-9]+$ ]]; then
      echo "❌ エラー: 無効な形式です"
      echo "   正しい形式: start-task.sh #198"
      echo "   または: start-task.sh 198"
      exit 1
    fi
    
    start_task_by_id "$ISSUE_NUM"
  fi
}

# スクリプト実行
main "$@"

