#!/bin/bash

# 汎用Issue作成スクリプト
# 使用方法: ./create-issue.sh <data-file>

set -e

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../config.sh" ]; then
  source "${SCRIPT_DIR}/../config.sh"
fi

# プロジェクト設定（config.shから取得）
# config.shでreadonlyとして定義されているため、ここで再定義しない

# 使用方法を表示
show_usage() {
    echo "使用方法: $0 <data-file>"
    echo ""
    echo "例:"
    echo "  $0 issue-data/mysql-migration.yml"
    echo "  $0 issue-data/drafts/my-feature-draft.json"
    echo ""
    echo "対応形式: .yml, .yaml, .json"
}

# 引数チェック
if [ $# -eq 0 ]; then
    echo "❌ エラー: データファイルを指定してください"
    echo ""
    show_usage
    exit 1
fi

DATA_FILE=$1

# ファイル存在チェック
if [ ! -f "$DATA_FILE" ]; then
    echo "❌ エラー: ファイルが見つかりません: $DATA_FILE"
    exit 1
fi

echo "════════════════════════════════════════════════════════════════"
echo "   📋 Issue作成"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "データファイル: $DATA_FILE"
echo ""

# ファイル拡張子を取得
EXT="${DATA_FILE##*.}"

# ファイル形式に応じてデータを読み込み
case "$EXT" in
    yml|yaml)
        # yqコマンドの確認
        if ! command -v yq &> /dev/null; then
            echo "❌ エラー: yqコマンドが見つかりません"
            echo ""
            echo "インストール方法:"
            echo "  macOS: brew install yq"
            echo "  Linux: snap install yq"
            echo ""
            echo "または、JSONファイルを使用してください（yqなしで動作）"
            exit 1
        fi
        
        # YAMLファイルからデータを読み込み
        TITLE=$(yq eval '.title' "$DATA_FILE")
        LABELS=$(yq eval '.labels | join(",")' "$DATA_FILE")
        BODY=$(yq eval '.body' "$DATA_FILE")
        ;;
    json)
        # jqコマンドの確認
        if ! command -v jq &> /dev/null; then
            echo "❌ エラー: jqコマンドが見つかりません"
            echo ""
            echo "jqは通常プリインストールされていますが、必要に応じて:"
            echo "  macOS: brew install jq"
            echo "  Linux: apt-get install jq"
            exit 1
        fi
        
        # JSONファイルからデータを読み込み
        TITLE=$(jq -r '.title' "$DATA_FILE")
        LABELS=$(jq -r '.labels | join(",")' "$DATA_FILE")
        BODY=$(jq -r '.body' "$DATA_FILE")
        ;;
    *)
        echo "❌ エラー: サポートされていないファイル形式: .$EXT"
        echo ""
        echo "対応形式: .yml, .yaml, .json"
        exit 1
        ;;
esac

# データの検証
if [ -z "$TITLE" ] || [ "$TITLE" = "null" ]; then
    echo "❌ エラー: titleが設定されていません"
    exit 1
fi

if [ -z "$BODY" ] || [ "$BODY" = "null" ]; then
    echo "❌ エラー: bodyが設定されていません"
    exit 1
fi

# Issueを作成
echo "📝 Issue作成中..."
echo "   タイトル: $TITLE"
echo "   ラベル: $LABELS"
echo ""

# 引数を配列で組み立て
CREATE_ARGS=("--title" "$TITLE" "--body" "$BODY")
if [ -n "$LABELS" ] && [ "$LABELS" != "null" ]; then
    CREATE_ARGS+=("--label" "$LABELS")
fi

# Issue作成とURLのキャプチャ
ISSUE_URL=$(gh issue create "${CREATE_ARGS[@]}")

if [ $? -eq 0 ] && [ -n "$ISSUE_URL" ]; then
    # URLからIssue番号を安全に取得
    ISSUE_NUM=$(basename "$ISSUE_URL")
    echo ""
    echo "✅ Issue #${ISSUE_NUM} 作成成功"
    echo ""
    
    # Projectに追加
    echo "📊 プロジェクトボード (Owner: $PROJECT_OWNER, Number: $PROJECT_NUMBER) に追加中..."
    gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --url "$ISSUE_URL" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ プロジェクトボードに追加完了"
        
        # ステータスをBacklogに設定
        echo "📋 ステータスをBacklogに設定中..."
        
        # プロジェクトアイテムIDを取得
        PROJECT_ITEM_ID=$(gh api graphql -f query="
        query {
          repository(owner: \"$PROJECT_OWNER\", name: \"$REPO_NAME\") {
            issue(number: $ISSUE_NUM) {
              projectItems(first: 10) {
                nodes {
                  id
                  project {
                    number
                  }
                }
              }
            }
          }
        }" 2>&1 | jq -r ".data.repository.issue.projectItems.nodes[] | select(.project.number == $PROJECT_NUMBER) | .id")
        
        if [ -z "$PROJECT_ITEM_ID" ]; then
            echo "⚠️  プロジェクトアイテムIDの取得に失敗しました"
            echo "   デバッグ情報: Issue #${ISSUE_NUM}, Project #${PROJECT_NUMBER}"
        else
            # ステータスフィールドを更新（Backlog）
            STATUS_UPDATE_RESULT=$(gh api graphql -f query="
            mutation {
              updateProjectV2ItemFieldValue(input: {
                projectId: \"$PROJECT_ID\"
                itemId: \"$PROJECT_ITEM_ID\"
                fieldId: \"$STATUS_FIELD_ID\"
                value: {
                  singleSelectOptionId: \"$BACKLOG_OPTION_ID\"
                }
              }) {
                projectV2Item {
                  id
                }
              }
            }" 2>&1)
            
            if [ $? -eq 0 ]; then
                echo "✅ ステータスをBacklogに設定完了"
            else
                echo "⚠️  ステータス設定に失敗しました（手動で設定してください）"
                echo "   デバッグ情報:"
                echo "   - PROJECT_ID: $PROJECT_ID"
                echo "   - ITEM_ID: $PROJECT_ITEM_ID"
                echo "   - STATUS_FIELD_ID: $STATUS_FIELD_ID"
                echo "   - BACKLOG_OPTION_ID: $BACKLOG_OPTION_ID"
                echo "   エラー内容: $STATUS_UPDATE_RESULT"
            fi
        fi
    else
        echo "⚠️  プロジェクトボードへの追加に失敗しました"
        echo "   手動で追加してください: $ISSUE_URL"
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "   ✅ 完了"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Issue URL: $ISSUE_URL"
else
    echo ""
    echo "❌ Issue作成に失敗しました"
    exit 1
fi

