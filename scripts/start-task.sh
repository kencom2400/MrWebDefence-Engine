#!/bin/bash

# @start-task コマンドのラッパースクリプト
# Issueトラッカー（GitHub/JIRA）を自動判定して適切なスクリプトを実行
#
# 使い方:
#   start-task.sh [ISSUE_IDENTIFIER]
#
# 引数なし: 最優先Issueを自動選択
# 引数あり: 指定したIssueで作業を開始
#   - GitHub: Issue番号（例: #198 または 198）
#   - JIRA: Issueキー（例: MWD-123）

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# JIRA設定の確認
JIRA_CONFIG_PATH="${SCRIPT_DIR}/jira/config.local.sh"
USE_JIRA=false

if [ -f "$JIRA_CONFIG_PATH" ]; then
  # JIRA設定ファイルを読み込み
  source "$JIRA_CONFIG_PATH" 2>/dev/null || true
  
  # 認証情報が設定されているか確認
  if [ -n "$JIRA_EMAIL" ] && [ -n "$JIRA_API_TOKEN" ]; then
    USE_JIRA=true
  fi
fi

# Issueトラッカーの判定とスクリプト実行
if [ "$USE_JIRA" = true ]; then
  echo "🔍 JIRA設定を検出しました。JIRAを使用します。"
  exec "${SCRIPT_DIR}/jira/workflow/start-task.sh" "$@"
else
  echo "🔍 GitHub設定を使用します。"
  exec "${SCRIPT_DIR}/github/workflow/start-task.sh" "$@"
fi
