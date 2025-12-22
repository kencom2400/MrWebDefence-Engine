#!/bin/bash

# GitHub ProjectsでIssueのステータスを任意の値に変更する汎用スクリプト

set -e

# 使い方
if [ $# -ne 2 ]; then
  echo "使い方: $0 <issue番号> <ステータス>"
  echo "例: $0 24 '🚧 In Progress'"
  echo "例: $0 24 '✅ Done'"
  echo "例: $0 24 '📝 To Do'"
  echo ""
  echo "利用可能なステータス:"
  echo "  - 📝 To Do"
  echo "  - 🚧 In Progress"
  echo "  - ✅ Done"
  echo "  - 📦 Backlog"
  exit 1
fi

ISSUE_NUMBER=$1
STATUS=$2
# PROJECT_NUMBER, OWNER, PROJECT_ID は config.sh で readonly として定義されているため、再代入しない

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../config.sh" ]; then
  source "${SCRIPT_DIR}/../config.sh"
fi

# GitHub API limit（設定ファイルで定義されていない場合のデフォルト値）
# 注: config.shでreadonlyとして定義されている場合は、その値を使用
if [ -z "${GH_API_LIMIT:-}" ]; then
  GH_API_LIMIT=9999
fi

# リトライ処理の設定（設定ファイルで定義されていない場合のデフォルト値）
# 注: config.shでreadonlyとして定義されている場合は、その値を使用
if [ -z "${MAX_RETRIES:-}" ]; then
  MAX_RETRIES=5
fi
if [ -z "${RETRY_INTERVAL:-}" ]; then
  RETRY_INTERVAL=3
fi

# アイテム情報を取得する関数
get_item_info() {
  gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit "$GH_API_LIMIT" | \
    jq --arg num "$ISSUE_NUMBER" '.items[] | select(.content.number == ($num | tonumber)) | {id: .id, title: .title, status: .status}'
}

echo "🔍 Issue #${ISSUE_NUMBER} の情報を取得中..."

# PROJECT_ID は config.sh で readonly として定義されているため、そのまま使用
if [ -z "${PROJECT_ID:-}" ]; then
  echo "❌ エラー: PROJECT_ID が設定されていません。config.sh を確認してください。"
  exit 1
fi

echo "   プロジェクトID: $PROJECT_ID"

# アイテムIDとステータスを取得
ITEM_INFO=$(get_item_info)

if [ -z "$ITEM_INFO" ]; then
  echo "⚠️  Issue #${ISSUE_NUMBER} がプロジェクトに見つかりませんでした"
  echo "📌 プロジェクトに自動追加します..."
  
  # IssueのURLを取得
  ISSUE_URL=$(gh issue view "$ISSUE_NUMBER" --json url --jq '.url')
  
  if [ -z "$ISSUE_URL" ]; then
    echo "❌ エラー: Issue #${ISSUE_NUMBER} が存在しません"
    exit 1
  fi
  
  # Issueをプロジェクトに追加
  gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$ISSUE_URL"
  
  echo "✅ Issue #${ISSUE_NUMBER} をプロジェクトに追加しました"
  echo "⏳ GitHub APIの反映を待機し、再度アイテム情報を取得します..."
  
  # API反映を待つためリトライ処理を追加
  for ((i=1; i<=MAX_RETRIES; i++)); do
    ITEM_INFO=$(get_item_info)
    if [ -n "$ITEM_INFO" ]; then
      break
    fi
    if [ "$i" -lt "$MAX_RETRIES" ]; then
      echo "  リトライ ($i/$MAX_RETRIES)..."
      sleep "$RETRY_INTERVAL"
    fi
  done
  
  if [ -z "$ITEM_INFO" ]; then
    echo "❌ エラー: Issueの追加後もアイテム情報を取得できませんでした"
    exit 1
  fi
fi

ITEM_ID=$(echo "$ITEM_INFO" | jq -r '.id')
CURRENT_STATUS=$(echo "$ITEM_INFO" | jq -r '.status')
TITLE=$(echo "$ITEM_INFO" | jq -r '.title')

echo "   アイテムID: $ITEM_ID"
echo "   タイトル: $TITLE"
echo "   現在のステータス: $CURRENT_STATUS"

# すでに指定されたステータスの場合はスキップ
if [ "$CURRENT_STATUS" = "$STATUS" ]; then
  echo "✅ すでに '${STATUS}' ステータスです"
  exit 0
fi

# StatusフィールドのIDとオプションIDを取得
echo ""
echo "📝 ステータスフィールド情報を取得中..."
FIELD_INFO=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json | \
  jq '.fields[] | select(.name == "Status")')

if [ -z "$FIELD_INFO" ]; then
  echo "❌ エラー: プロジェクトに 'Status' フィールドが見つかりませんでした。"
  exit 1
fi

FIELD_ID=$(echo "$FIELD_INFO" | jq -r '.id')
STATUS_OPTION_ID=$(echo "$FIELD_INFO" | jq -r --arg status "$STATUS" '.options[] | select(.name == $status) | .id')

if [ -z "$STATUS_OPTION_ID" ]; then
  echo "❌ エラー: ステータス '${STATUS}' が見つかりませんでした"
  echo ""
  echo "利用可能なステータス:"
  echo "$FIELD_INFO" | jq -r '.options[] | "  - \(.name)"'
  exit 1
fi

echo "   フィールドID: $FIELD_ID"
echo "   ステータスオプションID: $STATUS_OPTION_ID"

# ステータスを変更
echo ""
echo "🔄 ステータスを '${STATUS}' に変更中..."
gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$FIELD_ID" \
  --single-select-option-id "$STATUS_OPTION_ID"

echo ""
echo "✅ Issue #${ISSUE_NUMBER} のステータスを '${STATUS}' に変更しました！"
echo ""
# リポジトリ名を設定ファイルから取得（未設定の場合はデフォルト値）
REPO_NAME_FOR_URL="${REPO_NAME:-account-book}"
echo "確認: https://github.com/${OWNER}/${REPO_NAME_FOR_URL}/issues/${ISSUE_NUMBER}"

