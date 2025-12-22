#!/bin/bash

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../config.sh" ]; then
  source "${SCRIPT_DIR}/../config.sh"
fi

# GitHub API limit（設定ファイルで定義されていない場合のデフォルト値）
GH_API_LIMIT="${GH_API_LIMIT:-9999}"

# API Rate Limit対策の待機時間（設定ファイルで定義されていない場合のデフォルト値）
API_RATE_LIMIT_WAIT="${API_RATE_LIMIT_WAIT:-1}"


# PRとToDo Issueを紐づけるスクリプト
# PR側に関連Issueを追記する

set -e

# リポジトリ情報（config.shから取得）
# config.shでreadonlyとして定義されているため、ここで再定義しない

echo "════════════════════════════════════════════════════════════════"
echo "   🔗 PRとToDo Issueの紐づけ"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. ToDo状態のIssueを取得
echo "📝 ToDo状態のIssueを取得中..."
TODO_ISSUES=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit "$GH_API_LIMIT" | \
  jq -r '.items[] | select(.status == "📝 To Do") | .content.number')

if [ -z "$TODO_ISSUES" ]; then
  echo "⚠️  ToDo状態のIssueが見つかりませんでした"
  exit 0
fi

echo "✅ ToDo状態のIssue: $(echo "$TODO_ISSUES" | wc -w) 個"
echo ""

# 2. すべてのPRを取得（Open + Merged + Closed）
echo "📋 すべてのPRを取得中..."
ALL_PRS=$(gh pr list --repo "$OWNER/$REPO_NAME" --state all --limit "$GH_API_LIMIT" --json number,title,state,headRefName,body)
echo "✅ PR数: $(echo "$ALL_PRS" | jq '. | length') 個"
echo ""

# 3. 各ToDo IssueについてマッチするPRを探す
echo "────────────────────────────────────────────────────────────────"
echo "🔍 IssueとPRのマッチング開始"
echo "────────────────────────────────────────────────────────────────"
echo ""

TOTAL_LINKED=0
TOTAL_SKIPPED=0
TOTAL_NOT_FOUND=0

for issue_num in $TODO_ISSUES; do
  echo "[Issue #$issue_num]"
  
  # Issueの詳細を取得
  ISSUE_DATA=$(gh issue view "$issue_num" --repo "$OWNER/$REPO_NAME" --json number,title,body)
  ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
  ISSUE_BODY=$(echo "$ISSUE_DATA" | jq -r '.body // ""')
  
  echo "  タイトル: $ISSUE_TITLE"
  
  # マッチング条件:
  # 1. ブランチ名に issue-{number} が含まれる
  # 2. PRのタイトルまたは本文に #{number} が含まれる
  # 3. PRのタイトルまたは本文に (#number) が含まれる
  
  MATCHED_PRS=$(echo "$ALL_PRS" | jq -r --arg issue "$issue_num" \
    '.[] | select(
      (.headRefName | test("issue-" + $issue + "(-|$)")) or
      (.title | test("#" + $issue + "(-|\\s|\\)|$)")) or
      (.title | test("\\(#" + $issue + "\\)")) or
      (.body // "" | test("#" + $issue + "(-|\\s|\\)|$)")) or
      (.body // "" | test("\\(#" + $issue + "\\)"))
    ) | .number' | sort -u)
  
  if [ -z "$MATCHED_PRS" ]; then
    echo "  ❌ 関連するPRが見つかりませんでした"
    echo ""
    TOTAL_NOT_FOUND=$((TOTAL_NOT_FOUND + 1))
    continue
  fi
  
  echo "  ✅ マッチしたPR: $(echo "$MATCHED_PRS" | wc -w) 個"
  
  # 各マッチしたPRについて、関連Issueを追記
  for pr_num in $MATCHED_PRS; do
    echo "    → PR #$pr_num を確認中..."
    
    # PRの本文を取得
    PR_BODY=$(gh pr view "$pr_num" --repo "$OWNER/$REPO_NAME" --json body --jq '.body // ""')
    
    # すでにIssue参照が含まれているかチェック
    if echo "$PR_BODY" | grep -qE "(Closes|Fixes|Resolves|Related to|Ref|Issue|#).*#?${issue_num}(\s|\)|$)"; then
      echo "      ℹ️  すでにIssue #${issue_num} が参照されています"
      TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
      continue
    fi
    
    # PRの本文に関連Issueを追記
    echo "      📝 PR #${pr_num} にIssue #${issue_num} を追記中..."
    
    # 新しい本文を作成
    if [ -z "$PR_BODY" ] || [ "$PR_BODY" = "null" ]; then
      NEW_BODY="Related to #${issue_num}"
    else
      # 既存の本文の末尾に追記
      NEW_BODY="${PR_BODY}

---
Related to #${issue_num}"
    fi
    
    # PRの本文を更新
    gh pr edit "$pr_num" --repo "$OWNER/$REPO_NAME" --body "$NEW_BODY" 2>&1
    
    if [ $? -eq 0 ]; then
      echo "      ✅ PR #${pr_num} を更新しました"
      TOTAL_LINKED=$((TOTAL_LINKED + 1))
    else
      echo "      ❌ PR #${pr_num} の更新に失敗しました"
    fi
    
    # API rate limit対策
    sleep "$API_RATE_LIMIT_WAIT"
  done
  
  echo ""
done

# 結果サマリー
echo "════════════════════════════════════════════════════════════════"
echo "   📊 実行結果"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "対象ToDo Issue数: $(echo "$TODO_ISSUES" | wc -w) 個"
echo ""
echo "✅ PRに追記: $TOTAL_LINKED 個"
echo "ℹ️  既に参照済み: $TOTAL_SKIPPED 個"
echo "❌ PR未発見: $TOTAL_NOT_FOUND 個"
echo ""
echo "════════════════════════════════════════════════════════════════"
