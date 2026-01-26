#!/bin/bash

# Jira Issueコメント追加スクリプト
# このスクリプトは、既存のJira Issueにコメントを追加します。

set -euo pipefail

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${JIRA_SCRIPT_DIR}/common.sh" ]; then
  source "${JIRA_SCRIPT_DIR}/common.sh"
fi

# 一時ファイルのパス
TEMP_FILE=""

# クリーンアップ関数
cleanup() {
  if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
    rm -f "$TEMP_FILE"
  fi
}

# 終了時にクリーンアップを実行
trap cleanup EXIT

# 使用方法を表示
show_usage() {
    cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Jira Issueコメント追加スクリプト
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

使用方法:

  バッチモード:
    $0 --issue-key KEY [オプション]

オプション:
  --issue-key KEY        Issueキー（必須、例: MWD-38）
  --body TEXT           コメント本文（直接入力）
  --body-file FILE      コメント本文をファイルから読み込み
  --help                このヘルプを表示

例:
  # コメントを直接入力
  $0 --issue-key MWD-38 --body "## 作業完了\\n\\n実装が完了しました"

  # ファイルからコメントを読み込み
  $0 --issue-key MWD-38 --body-file ./comment.md

  # 標準入力からコメントを読み込み
  echo "## 作業完了" | $0 --issue-key MWD-38 --body-file -

  # ヒアドキュメントで使用
  $0 --issue-key MWD-38 --body-file - << 'EOF'
  ## 🎉 作業完了報告

  Issue MWD-38の作業が完了しました。

  ## 📊 実施した作業
  - 実装完了
  - テスト完了
  EOF

注意:
  - Issueキーは必須です
  - コメント本文は --body または --body-file のいずれかで指定してください
  - --body-file に "-" を指定すると標準入力から読み込みます
  - バッククォート（\`）などの特殊文字も安全に処理されます

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# マークダウンテキストをADF形式に変換する関数
# update-issue.shと同じ関数を使用
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
            # 注意: 現在の実装では、チェックボックスはテキストとしてのみ表示されます
            # インタラクティブなチェックボックスとして機能させるには、ADF形式で
            # taskList と taskItem ノードを使用する必要があります
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
            # 注意: 現在の実装では、チェックボックスはテキストとしてのみ表示されます
            # インタラクティブなチェックボックスとして機能させるには、ADF形式で
            # taskList と taskItem ノードを使用する必要があります
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
BODY=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --issue-key)
            ISSUE_KEY="$2"
            shift 2
            ;;
        --body)
            BODY="$2"
            shift 2
            ;;
        --body-file)
            BODY_FILE="$2"
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

# コメント本文の取得
if [ -n "$BODY_FILE" ]; then
    if [ "$BODY_FILE" = "-" ]; then
        # 標準入力から読み込み
        TEMP_FILE=$(mktemp)
        cat > "$TEMP_FILE"
        BODY=$(cat "$TEMP_FILE")
    elif [ ! -f "$BODY_FILE" ]; then
        echo "❌ エラー: ファイルが見つかりません: $BODY_FILE" >&2
        exit 1
    else
        BODY=$(cat "$BODY_FILE")
    fi
elif [ -z "$BODY" ]; then
    echo "❌ エラー: コメント本文が指定されていません" >&2
    echo "   --body または --body-file オプションを使用してください" >&2
    echo "" >&2
    show_usage
    exit 1
fi

# コメント本文が空でないことを確認
if [ -z "$BODY" ]; then
    echo "❌ エラー: コメント本文が空です" >&2
    exit 1
fi

# Issue存在確認
echo "🔄 Issue情報を取得中..."
ISSUE_INFO=$(jira_api_call "GET" "issue/${ISSUE_KEY}?fields=summary,status")
if [ $? -ne 0 ] || ! echo "$ISSUE_INFO" | jq -e . >/dev/null 2>&1; then
    echo "❌ エラー: Issue '${ISSUE_KEY}' の情報取得に失敗しました" >&2
    handle_jira_error "$ISSUE_INFO"
    exit 1
fi

CURRENT_TITLE=$(echo "$ISSUE_INFO" | jq -r '.fields.summary')
CURRENT_STATUS=$(echo "$ISSUE_INFO" | jq -r '.fields.status.name')

echo "✅ Issueキー: $ISSUE_KEY"
echo "✅ タイトル: $CURRENT_TITLE"
echo "✅ ステータス: $CURRENT_STATUS"
echo ""

# マークダウンをADF形式に変換
echo "📝 コメントを追加中..."
ADF_COMMENT=$(markdown_to_adf "$BODY")

# コメント追加用のJSONデータを構築
COMMENT_DATA=$(jq -n --argjson body "$ADF_COMMENT" '{
    body: $body
}')

# コメントを追加
RESPONSE=$(jira_api_call "POST" "issue/${ISSUE_KEY}/comment" "$COMMENT_DATA")

if [ $? -eq 0 ] && echo "$RESPONSE" | jq -e . >/dev/null 2>&1; then
    COMMENT_ID=$(echo "$RESPONSE" | jq -r '.id')
    echo "✅ コメントを追加しました"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ コメント追加完了"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Issueキー: $ISSUE_KEY"
    echo "コメントID: $COMMENT_ID"
    echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
    echo ""
else
    echo "❌ エラー: コメント追加に失敗しました" >&2
    handle_jira_error "$RESPONSE"
    exit 1
fi
