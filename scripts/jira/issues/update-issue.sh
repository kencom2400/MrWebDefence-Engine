#!/bin/bash

# Jira Issue更新スクリプト
# このスクリプトは、既存のJira Issueを更新します。

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
  Jira Issue更新スクリプト
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

使用方法:

  バッチモード:
    $0 --issue-key KEY [オプション]

オプション:
  --issue-key KEY        Issueキー（必須、例: MWD-38）
  --title TEXT           Issue タイトル（summary）を更新
  --body TEXT            Issue 本文（description）を更新
  --body-file FILE       本文をファイルから読み込み
  --status STATUS        ステータスを更新: Backlog, ToDo, In Progress, Done
  --help                 このヘルプを表示

例:
  # タイトルのみ更新
  $0 --issue-key MWD-38 --title "新しいタイトル"

  # 説明を更新（ファイルから）
  $0 --issue-key MWD-38 --body-file ./description.md

  # 説明を更新（直接入力）
  $0 --issue-key MWD-38 --body "## 概要\\n\\n更新された説明"

  # ステータスを更新
  $0 --issue-key MWD-38 --status "In Progress"

  # 複数のフィールドを同時に更新
  $0 --issue-key MWD-38 \\
     --title "更新されたタイトル" \\
     --body-file ./description.md \\
     --status "Done"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# マークダウンテキストをADF形式に変換する関数
# 簡易版：段落と見出しをサポート
markdown_to_adf() {
    local text="$1"
    
    # 空の場合は空のADFドキュメントを返す
    if [ -z "$text" ]; then
        jq -n '{
            type: "doc",
            version: 1,
            content: []
        }'
        return
    fi
    
    # 行ごとに処理
    local content_array="[]"
    local current_paragraph=""
    
    while IFS= read -r line || [ -n "$line" ]; do
        # 見出しの検出（## で始まる行）
        if [[ "$line" =~ ^##[[:space:]]+(.*)$ ]]; then
            # 前の段落があれば追加
            if [ -n "$current_paragraph" ]; then
                content_array=$(echo "$content_array" | jq --arg para "$current_paragraph" '. + [{
                    type: "paragraph",
                    content: [{
                        type: "text",
                        text: $para
                    }]
                }]')
                current_paragraph=""
            fi
            # 見出しを追加
            local heading_text="${BASH_REMATCH[1]}"
            content_array=$(echo "$content_array" | jq --arg text "$heading_text" '. + [{
                type: "heading",
                attrs: { level: 2 },
                content: [{
                    type: "text",
                    text: $text,
                    marks: [{ type: "strong" }]
                }]
            }]')
        elif [[ "$line" =~ ^###[[:space:]]+(.*)$ ]]; then
            # 前の段落があれば追加
            if [ -n "$current_paragraph" ]; then
                content_array=$(echo "$content_array" | jq --arg para "$current_paragraph" '. + [{
                    type: "paragraph",
                    content: [{
                        type: "text",
                        text: $para
                    }]
                }]')
                current_paragraph=""
            fi
            # 見出しを追加
            local heading_text="${BASH_REMATCH[1]}"
            content_array=$(echo "$content_array" | jq --arg text "$heading_text" '. + [{
                type: "heading",
                attrs: { level: 3 },
                content: [{
                    type: "text",
                    text: $text,
                    marks: [{ type: "strong" }]
                }]
            }]')
        elif [[ "$line" =~ ^-\[[[:space:]]*\][[:space:]]+(.*)$ ]]; then
            # チェックボックス（未チェック）
            if [ -n "$current_paragraph" ]; then
                content_array=$(echo "$content_array" | jq --arg para "$current_paragraph" '. + [{
                    type: "paragraph",
                    content: [{
                        type: "text",
                        text: $para
                    }]
                }]')
                current_paragraph=""
            fi
            local checkbox_text="${BASH_REMATCH[1]}"
            content_array=$(echo "$content_array" | jq --arg text "$checkbox_text" '. + [{
                type: "paragraph",
                content: [{
                    type: "text",
                    text: ("- [ ] " + $text)
                }]
            }]')
        elif [[ "$line" =~ ^-\[x\][[:space:]]+(.*)$ ]]; then
            # チェックボックス（チェック済み）
            if [ -n "$current_paragraph" ]; then
                content_array=$(echo "$content_array" | jq --arg para "$current_paragraph" '. + [{
                    type: "paragraph",
                    content: [{
                        type: "text",
                        text: $para
                    }]
                }]')
                current_paragraph=""
            fi
            local checkbox_text="${BASH_REMATCH[1]}"
            content_array=$(echo "$content_array" | jq --arg text "$checkbox_text" '. + [{
                type: "paragraph",
                content: [{
                    type: "text",
                    text: ("- [x] " + $text)
                }]
            }]')
        elif [ -z "$line" ]; then
            # 空行：段落を終了
            if [ -n "$current_paragraph" ]; then
                content_array=$(echo "$content_array" | jq --arg para "$current_paragraph" '. + [{
                    type: "paragraph",
                    content: [{
                        type: "text",
                        text: $para
                    }]
                }]')
                current_paragraph=""
            fi
        else
            # 通常のテキスト行
            if [ -n "$current_paragraph" ]; then
                current_paragraph="${current_paragraph} ${line}"
            else
                current_paragraph="$line"
            fi
        fi
    done <<< "$text"
    
    # 最後の段落があれば追加
    if [ -n "$current_paragraph" ]; then
        content_array=$(echo "$content_array" | jq --arg para "$current_paragraph" '. + [{
            type: "paragraph",
            content: [{
                type: "text",
                text: $para
            }]
        }]')
    fi
    
    # ADFドキュメントを生成
    echo "$content_array" | jq '{
        type: "doc",
        version: 1,
        content: .
    }'
}

# 引数解析
ISSUE_KEY=""
TITLE=""
BODY=""
BODY_FILE=""
STATUS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --issue-key)
            ISSUE_KEY="$2"
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

# 必須項目チェック
if [ -z "$ISSUE_KEY" ]; then
    echo "❌ エラー: Issueキーが指定されていません" >&2
    echo "" >&2
    show_usage
    exit 1
fi

# 更新するフィールドがない場合
if [ -z "$TITLE" ] && [ -z "$BODY" ] && [ -z "$BODY_FILE" ] && [ -z "$STATUS" ]; then
    echo "❌ エラー: 更新するフィールドが指定されていません" >&2
    echo "" >&2
    show_usage
    exit 1
fi

# 本文の取得
if [ -n "$BODY_FILE" ]; then
    BODY=$(cat "$BODY_FILE")
fi

# Issue情報を取得して現在の状態を確認
echo "🔄 Issue情報を取得中..."
ISSUE_INFO=$(jira_api_call "GET" "issue/${ISSUE_KEY}?fields=summary,description,status")
if [ $? -ne 0 ] || ! echo "$ISSUE_INFO" | jq -e . >/dev/null 2>&1; then
    echo "❌ エラー: Issue '${ISSUE_KEY}' の情報取得に失敗しました" >&2
    handle_jira_error "$ISSUE_INFO"
    exit 1
fi

CURRENT_TITLE=$(echo "$ISSUE_INFO" | jq -r '.fields.summary')
CURRENT_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')

echo "✅ Issueキー: $ISSUE_KEY"
echo "✅ 現在のタイトル: $CURRENT_TITLE"
echo "✅ 現在のステータス: $CURRENT_STATUS"
echo ""

# 更新用のJSONデータを構築
UPDATE_FIELDS="{}"

# タイトルの更新
if [ -n "$TITLE" ]; then
    UPDATE_FIELDS=$(echo "$UPDATE_FIELDS" | jq --arg title "$TITLE" '. + {summary: $title}')
    echo "📝 タイトルを更新: \"$TITLE\""
fi

# 説明の更新
if [ -n "$BODY" ]; then
    echo "📝 説明を更新中..."
    ADF_DESCRIPTION=$(markdown_to_adf "$BODY")
    UPDATE_FIELDS=$(echo "$UPDATE_FIELDS" | jq --argjson description "$ADF_DESCRIPTION" '. + {description: $description}')
    echo "✅ 説明を更新しました"
fi

# 更新するフィールドがない場合は終了
if [ "$UPDATE_FIELDS" = "{}" ] && [ -z "$STATUS" ]; then
    echo "⚠️  更新するフィールドがありません"
    exit 0
fi

# Issue更新
if [ "$UPDATE_FIELDS" != "{}" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔄 Issue更新中..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    UPDATE_DATA=$(jq -n --argjson fields "$UPDATE_FIELDS" '{
        fields: $fields
    }')
    
    RESPONSE=$(jira_api_call "PUT" "issue/${ISSUE_KEY}" "$UPDATE_DATA")
    
    if [ $? -eq 0 ]; then
        echo "✅ Issue更新成功"
    else
        echo "❌ エラー: Issue更新に失敗しました" >&2
        handle_jira_error "$RESPONSE"
        exit 1
    fi
fi

# ステータスの更新
if [ -n "$STATUS" ]; then
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

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Issue更新完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Issueキー: $ISSUE_KEY"
echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
echo ""
