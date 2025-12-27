#!/bin/bash

# Jira Issue作成スクリプト
# このスクリプトは、JiraにIssueを作成します。
# GitHub Issue作成スクリプト（create-issue-graphql.sh）と同様のインターフェースを提供します。

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
  Jira Issue作成スクリプト
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

使用方法:

  対話型モード:
    $0

  バッチモード:
    $0 --title "タイトル" --issue-type TYPE [オプション]

オプション:
  --title TEXT           Issue タイトル（必須）
  --body TEXT            Issue 本文
  --body-file FILE       本文をファイルから読み込み
  --issue-type TYPE      チケット種別: Epic, Bug, Story, Task, Sub-task（必須）
  --status STATUS        ステータス: Backlog, ToDo, In Progress, Done
  --project-key KEY      プロジェクトキー（オプション、設定ファイルから取得可能）
  --help                 このヘルプを表示

例:
  # 対話型
  $0

  # バッチモード
  $0 --title "[bug] E2Eテストエラー" \\
     --body "## 概要\\n\\nE2Eテストが失敗します" \\
     --issue-type Bug \\
     --status ToDo

  # ファイルから本文を読み込み
  $0 --title "[feature] 新機能" \\
     --body-file ./issue-content.md \\
     --issue-type Story \\
     --status Backlog

チケット種別: Epic, Bug, Story, Task, Sub-task
ステータス: Backlog, ToDo, In Progress, Done

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# 引数解析
PROJECT_KEY=""
ISSUE_TYPE=""
TITLE=""
BODY=""
BODY_FILE=""
STATUS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project-key)
            PROJECT_KEY="$2"
            shift 2
            ;;
        --issue-type)
            ISSUE_TYPE="$2"
            shift 2
            ;;
        --title)
            TITLE="$2"
            shift 2
            ;;
        --body)
            BODY="$2"
            shift 2
            ;;
        --body-file)
            if [ ! -f "$2" ]; then
                echo "❌ エラー: ファイルが見つかりません: $2" >&2
                exit 1
            fi
            BODY_FILE="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ エラー: 不明なオプション: $1" >&2
            echo "" >&2
            show_usage
            exit 1
            ;;
    esac
done

# 対話型モード
if [ -z "$PROJECT_KEY" ] || [ -z "$ISSUE_TYPE" ] || [ -z "$TITLE" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📝 対話型Issue作成スクリプト"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # プロジェクトキーの入力（設定ファイルから取得可能）
    if [ -z "$PROJECT_KEY" ]; then
        if [ -n "$JIRA_PROJECT_KEY" ]; then
            echo "設定ファイルからプロジェクトキーを取得: $JIRA_PROJECT_KEY"
            read -p "プロジェクトキー (Enterで設定値を使用): " PROJECT_KEY_INPUT
            PROJECT_KEY="${PROJECT_KEY_INPUT:-$JIRA_PROJECT_KEY}"
        else
            read -p "プロジェクトキー: " PROJECT_KEY
        fi
    fi
    
    # Issue種別の選択
    if [ -z "$ISSUE_TYPE" ]; then
        echo ""
        echo "Issue種別: Epic, Bug, Story, Task, Sub-task"
        read -p "Issue種別: " ISSUE_TYPE
    fi
    
    # タイトルの入力
    if [ -z "$TITLE" ]; then
        echo ""
        read -p "タイトル: " TITLE
    fi
    
    # 本文の入力
    if [ -z "$BODY" ] && [ -z "$BODY_FILE" ]; then
        echo ""
        read -p "本文ファイルのパス (直接入力の場合は空Enter): " BODY_FILE_INPUT
        
        if [ -n "$BODY_FILE_INPUT" ]; then
            if [ ! -f "$BODY_FILE_INPUT" ]; then
                echo "❌ エラー: ファイルが見つかりません: $BODY_FILE_INPUT" >&2
                exit 1
            fi
            BODY_FILE="$BODY_FILE_INPUT"
        else
            echo "本文を入力してください (Ctrl+D で終了):"
            BODY=$(cat)
        fi
    fi
    
    # ステータスの選択
    if [ -z "$STATUS" ]; then
        echo ""
        echo "ステータス: Backlog, ToDo, In Progress, Done"
        read -p "ステータス (空Enter=ToDo): " STATUS_INPUT
        STATUS="${STATUS_INPUT:-ToDo}"
    fi
    
    echo ""
fi

# 必須項目チェック
if [ -z "$PROJECT_KEY" ]; then
    echo "❌ エラー: プロジェクトキーが指定されていません" >&2
    echo "" >&2
    show_usage
    exit 1
fi

if [ -z "$ISSUE_TYPE" ]; then
    echo "❌ エラー: Issue種別が指定されていません" >&2
    echo "" >&2
    show_usage
    exit 1
fi

if [ -z "$TITLE" ]; then
    echo "❌ エラー: タイトルが指定されていません" >&2
    echo "" >&2
    show_usage
    exit 1
fi

# 本文の取得
if [ -n "$BODY_FILE" ]; then
    BODY=$(cat "$BODY_FILE")
elif [ -z "$BODY" ]; then
    BODY="（本文未設定）"
fi

# Issue種別IDをAPIから動的に取得
# JiraのIssue Type IDはプロジェクトごとに異なる可能性があるため、APIから取得する
echo "🔄 Issue種別IDを取得中..."
ISSUE_TYPE_ID=$(get_issue_type_id_from_api "$PROJECT_KEY" "$ISSUE_TYPE" 2>&1) || {
  echo "❌ エラー: Issue種別IDの取得に失敗しました" >&2
  echo "プロジェクト '$PROJECT_KEY' で利用可能なIssue種別を確認してください。" >&2
  echo "" >&2
  echo "利用可能なIssue種別を取得中..." >&2
  "${JIRA_SCRIPT_DIR}/issues/get-issue-types.sh" "$PROJECT_KEY" >&2
  exit 1
}

if [ -z "$ISSUE_TYPE_ID" ]; then
  echo "❌ エラー: 不明なIssue種別: $ISSUE_TYPE" >&2
  echo "プロジェクト '$PROJECT_KEY' で利用可能なIssue種別を確認してください。" >&2
  echo "" >&2
  echo "利用可能なIssue種別を取得中..." >&2
  "${JIRA_SCRIPT_DIR}/issues/get-issue-types.sh" "$PROJECT_KEY" >&2
  exit 1
fi

echo "✅ Issue種別ID: $ISSUE_TYPE_ID ($ISSUE_TYPE)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Issue作成中..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "プロジェクトキー: $PROJECT_KEY"
echo "Issue種別: $ISSUE_TYPE"
echo "タイトル: $TITLE"
if [ -n "$STATUS" ]; then
  echo "ステータス: $STATUS"
fi
echo ""

# Issue作成用のJSONデータ
# JiraのdescriptionフィールドはAtlassian Document Format (ADF)を使用
ISSUE_DATA=$(jq -n \
  --arg project_key "$PROJECT_KEY" \
  --arg issue_type_id "$ISSUE_TYPE_ID" \
  --arg title "$TITLE" \
  --arg body "$BODY" \
  '{
    fields: {
      project: {
        key: $project_key
      },
      issuetype: {
        id: $issue_type_id
      },
      summary: $title,
      description: {
        type: "doc",
        version: 1,
        content: [
          {
            type: "paragraph",
            content: [
              {
                type: "text",
                text: $body
              }
            ]
          }
        ]
      }
    }
  }')

echo "🔄 Issueを作成中..."
RESPONSE=$(jira_api_call "POST" "issue" "$ISSUE_DATA")

if [ $? -eq 0 ] && echo "$RESPONSE" | jq -e . >/dev/null 2>&1; then
  ISSUE_KEY=$(echo "$RESPONSE" | jq -r '.key')
  ISSUE_ID=$(echo "$RESPONSE" | jq -r '.id')
  ISSUE_URL="${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
  
  echo "✅ Issue作成成功"
  echo ""
  echo "Issueキー: $ISSUE_KEY"
  echo "Issue ID: $ISSUE_ID"
  echo "URL: $ISSUE_URL"
  echo ""
  
  # Issue情報を取得してステータスを表示
  echo "📋 Issue情報を取得中..."
  ISSUE_INFO=$(jira_api_call "GET" "issue/${ISSUE_KEY}")
  if [ $? -eq 0 ]; then
    CURRENT_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')
    echo "✅ 現在のステータス: $CURRENT_STATUS"
    
    # ステータスが指定されている場合、遷移を試みる
    if [ -n "$STATUS" ] && [ "$STATUS" != "$CURRENT_STATUS" ]; then
      echo ""
      echo "🔄 ステータスを '$STATUS' に遷移中..."
      # ステータス名をマッピング（英語名 → 日本語名）
      MAPPED_STATUS=$(map_status_name "$STATUS" "$ISSUE_KEY")
      "${JIRA_SCRIPT_DIR}/projects/transition-issue.sh" "$ISSUE_KEY" "$MAPPED_STATUS" >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "✅ ステータスを '$MAPPED_STATUS' に変更しました"
      else
        echo "⚠️  ステータス遷移に失敗しました（現在のステータス: $CURRENT_STATUS）"
      fi
    fi
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ Issue作成完了"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Issueキー: $ISSUE_KEY"
  echo "タイトル: $TITLE"
  echo "URL: $ISSUE_URL"
  echo ""
else
  echo "❌ エラー: Issue作成に失敗しました" >&2
  handle_jira_error "$RESPONSE"
  exit 1
fi

