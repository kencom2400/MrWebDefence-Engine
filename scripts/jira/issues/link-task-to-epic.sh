#!/bin/bash

# Jira TaskをEpicに紐づけるスクリプト
# このスクリプトは、指定されたTaskをEpicに紐づけます。

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
  Jira TaskをEpicに紐づけるスクリプト
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

使用方法:

  $0 <task_key> <epic_key>

引数:
  task_key           紐づけるTaskのキー（例: MWD-18）
  epic_key           紐づけ先のEpicのキー（例: MWD-1）
  --help             このヘルプを表示

例:
  # Task MWD-18をEpic MWD-1に紐づける
  $0 MWD-18 MWD-1

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# 引数解析
TASK_KEY=""
EPIC_KEY=""

while [[ $# -gt 0 ]]; do
    case $1 in
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
            if [ -z "$TASK_KEY" ]; then
                TASK_KEY="$1"
            elif [ -z "$EPIC_KEY" ]; then
                EPIC_KEY="$1"
            else
                echo "❌ エラー: 引数が多すぎます: $1" >&2
                echo "" >&2
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# 必須項目チェック
if [ -z "$TASK_KEY" ] || [ -z "$EPIC_KEY" ]; then
    echo "❌ エラー: TaskキーとEpicキーが指定されていません" >&2
    echo "" >&2
    show_usage
    exit 1
fi

# Epic LinkフィールドのIDを取得する関数
get_epic_link_field_id() {
    local project_key="$1"
    local task_key="$2"
    
    # 方法1: /rest/api/3/fieldからEpic Linkフィールドを探す
    local fields_data=$(jira_api_call "GET" "field" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$fields_data" | jq -e . >/dev/null 2>&1; then
        local epic_field=$(echo "$fields_data" | jq -r '.[] | select(.name == "Epic Link" or .name == "Epic Name") | .id' | head -n 1)
        
        if [ -n "$epic_field" ] && [ "$epic_field" != "null" ]; then
            echo "$epic_field"
            return 0
        fi
    fi
    
    # 方法2: editmetaからEpic Linkフィールドを探す
    local editmeta=$(jira_api_call "GET" "issue/${task_key}/editmeta" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$editmeta" | jq -e . >/dev/null 2>&1; then
        # Epic Linkという名前のフィールドを探す
        local epic_field=$(echo "$editmeta" | jq -r '.fields | to_entries[] | select(.value.name | test("Epic Link|Epic"; "i")) | .key' | head -n 1)
        
        if [ -n "$epic_field" ] && [ "$epic_field" != "null" ]; then
            echo "$epic_field"
            return 0
        fi
    fi
    
    # 方法3: createmetaからEpic Linkフィールドを探す
    local createmeta=$(jira_api_call "GET" "issue/createmeta?projectKeys=${project_key}&expand=projects.issuetypes.fields" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$createmeta" | jq -e . >/dev/null 2>&1; then
        # Task種別のフィールドからEpic Linkを探す
        local epic_field=$(echo "$createmeta" | jq -r '.projects[0].issuetypes[] | select(.name == "タスク" or .name == "Task") | .fields | to_entries[] | select(.value.name | test("Epic Link|Epic"; "i")) | .key' | head -n 1)
        
        if [ -n "$epic_field" ] && [ "$epic_field" != "null" ]; then
            echo "$epic_field"
            return 0
        fi
    fi
    
    # 方法4: 一般的なEpic LinkフィールドIDを試す
    local common_field_ids=("customfield_10014" "customfield_10011" "customfield_10016" "customfield_10015")
    
    # パフォーマンス改善: 複数のフィールドを1回のAPI呼び出しで取得
    local fields_list=$(IFS=','; echo "${common_field_ids[*]}")
    local test_response=$(jira_api_call "GET" "issue/${task_key}?fields=${fields_list}" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$test_response" | jq -e . >/dev/null 2>&1; then
        for field_id in "${common_field_ids[@]}"; do
            # ダブルクォートを使用して変数を展開
            if echo "$test_response" | jq -e ".fields.\"${field_id}\"" >/dev/null 2>&1; then
                echo "$field_id"
                return 0
            fi
        done
    fi
    
    # デフォルトのEpic LinkフィールドIDを返す
    echo "customfield_10014"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔗 TaskをEpicに紐づけ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Taskキー: $TASK_KEY"
echo "Epicキー: $EPIC_KEY"
echo ""

# Taskの存在確認
echo "🔄 Task情報を取得中..."
TASK_INFO=$(jira_api_call "GET" "issue/${TASK_KEY}")

if [ $? -ne 0 ] || ! echo "$TASK_INFO" | jq -e . >/dev/null 2>&1; then
  echo "❌ エラー: Task情報の取得に失敗しました" >&2
  handle_jira_error "$TASK_INFO"
  exit 1
fi

TASK_TITLE=$(echo "$TASK_INFO" | jq -r '.fields.summary')
TASK_TYPE=$(echo "$TASK_INFO" | jq -r '.fields.issuetype.name')

echo "✅ Taskキー: $TASK_KEY"
echo "✅ タイトル: $TASK_TITLE"
echo "✅ Issue種別: $TASK_TYPE"
echo ""

# Epicの存在確認
echo "🔄 Epic情報を取得中..."
EPIC_INFO=$(jira_api_call "GET" "issue/${EPIC_KEY}")

if [ $? -ne 0 ] || ! echo "$EPIC_INFO" | jq -e . >/dev/null 2>&1; then
  echo "❌ エラー: Epic情報の取得に失敗しました" >&2
  handle_jira_error "$EPIC_INFO"
  exit 1
fi

EPIC_TITLE=$(echo "$EPIC_INFO" | jq -r '.fields.summary')
EPIC_TYPE=$(echo "$EPIC_INFO" | jq -r '.fields.issuetype.name')

# Epic種別の確認
if [ "$EPIC_TYPE" != "エピック" ] && [ "$EPIC_TYPE" != "Epic" ]; then
    echo "⚠️  警告: ${EPIC_KEY} はEpicではありません（種別: ${EPIC_TYPE}）" >&2
    echo "続行しますか？ (y/N)"
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "❌ キャンセルされました"
        exit 0
    fi
fi

echo "✅ Epicキー: $EPIC_KEY"
echo "✅ タイトル: $EPIC_TITLE"
echo "✅ Issue種別: $EPIC_TYPE"
echo ""

# プロジェクトキーを取得
PROJECT_KEY=$(echo "$TASK_INFO" | jq -r '.fields.project.key')

# Epic LinkフィールドIDを取得
echo "🔄 Epic LinkフィールドIDを取得中..."
EPIC_LINK_FIELD=$(get_epic_link_field_id "$PROJECT_KEY" "$TASK_KEY")

echo "✅ Epic LinkフィールドID: $EPIC_LINK_FIELD"
echo ""

# Epic Linkを設定
echo "🔄 Epic Linkを設定中..."

# EpicのIDを取得
EPIC_ID=$(echo "$EPIC_INFO" | jq -r '.id')

# 方法1: parentフィールドを使用（JiraではEpicがparentとして設定される場合がある）
echo "🔄 parentフィールドで設定を試行中..."
UPDATE_DATA=$(jq -n \
  --arg epic_key "$EPIC_KEY" \
  "{
    fields: {
      parent: {
        key: \$epic_key
      }
    }
  }")

RESPONSE=$(jira_api_call "PUT" "issue/${TASK_KEY}" "$UPDATE_DATA")
UPDATE_STATUS=$?

# parentフィールドで失敗した場合、Epic Linkフィールドを試す
if [ $UPDATE_STATUS -ne 0 ]; then
    echo "⚠️  parentフィールドでの設定に失敗しました。Epic Linkフィールドで再試行します..."
    
    # Epicキーで試す
    UPDATE_DATA=$(jq -n \
      --arg epic_key "$EPIC_KEY" \
      --arg field_id "$EPIC_LINK_FIELD" \
      "{
        fields: {
          (\$field_id): \$epic_key
        }
      }")
    
    RESPONSE=$(jira_api_call "PUT" "issue/${TASK_KEY}" "$UPDATE_DATA")
    UPDATE_STATUS=$?
    
    # Epicキーで失敗した場合、Epic IDで試す
    if [ $UPDATE_STATUS -ne 0 ]; then
        echo "⚠️  Epicキーでの設定に失敗しました。Epic IDで再試行します..."
        UPDATE_DATA=$(jq -n \
          --arg epic_id "$EPIC_ID" \
          --arg field_id "$EPIC_LINK_FIELD" \
          "{
            fields: {
              (\$field_id): \$epic_id
            }
          }")
        
        RESPONSE=$(jira_api_call "PUT" "issue/${TASK_KEY}" "$UPDATE_DATA")
        UPDATE_STATUS=$?
    fi
fi

if [ $UPDATE_STATUS -eq 0 ]; then
    echo "✅ Epic Link設定成功"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ TaskをEpicに紐づけ完了"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Task: $TASK_KEY - $TASK_TITLE"
    echo "Epic: $EPIC_KEY - $EPIC_TITLE"
    echo ""
else
    echo "❌ エラー: Epic Link設定に失敗しました" >&2
    handle_jira_error "$RESPONSE"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚠️  手動での設定方法"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "JiraのWeb UIから手動で設定してください:"
    echo "1. ${JIRA_BASE_URL}/browse/${TASK_KEY} を開く"
    echo "2. 「編集」をクリック"
    echo "3. 「Epic Link」フィールドに「${EPIC_KEY}」を入力"
    echo "4. 「保存」をクリック"
    echo ""
    echo "または、Jiraの設定でEpic LinkフィールドがTaskの編集画面に表示されるように"
    echo "設定してください。"
    echo ""
    exit 1
fi

