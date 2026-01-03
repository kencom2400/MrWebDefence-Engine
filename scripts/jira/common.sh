#!/bin/bash

# Jira API共通関数
# このファイルは他のJiraスクリプトからsourceして使用します

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config.sh" ]; then
  source "${SCRIPT_DIR}/config.sh"
fi

# 認証情報の確認
check_jira_auth() {
  if [ -z "$JIRA_EMAIL" ] || [ -z "$JIRA_API_TOKEN" ]; then
    echo "❌ エラー: 環境変数 JIRA_EMAIL と JIRA_API_TOKEN が設定されていません。" >&2
    echo "" >&2
    echo "以下のコマンドで設定してください:" >&2
    echo "  export JIRA_EMAIL='your-email@example.com'" >&2
    echo "  export JIRA_API_TOKEN='your-api-token'" >&2
    exit 1
  fi
}

# Basic認証ヘッダーの生成
get_auth_header() {
  check_jira_auth
  echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64
}

# Jira API呼び出し関数
jira_api_call() {
  local method="${1:-GET}"
  local endpoint="$2"
  local data="${3:-}"
  
  check_jira_auth
  
  local auth_header=$(get_auth_header)
  local url="${JIRA_BASE_URL}/rest/api/3/${endpoint}"
  
  local curl_args=(
    -s
    -X "$method"
    -H "Authorization: Basic ${auth_header}"
    -H "Accept: application/json"
    -H "Content-Type: application/json"
  )
  
  if [ -n "$data" ]; then
    curl_args+=(-d "$data")
  fi
  
  local response
  local http_code
  
  response=$(curl -w "\n%{http_code}" "${curl_args[@]}" "$url" 2>&1)
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | sed '$d')
  
  # HTTPステータスコードの確認
  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "$response_body"
  else
    echo "HTTPエラー: $http_code" >&2
    echo "$response_body" >&2
    return 1
  fi
}

# エラーハンドリング
handle_jira_error() {
  local response="$1"
  local error_message=$(echo "$response" | jq -r '.errorMessages[]? // .errors | to_entries[]? | "\(.key): \(.value)"' 2>/dev/null)
  
  if [ -n "$error_message" ]; then
    echo "❌ Jira APIエラー:" >&2
    echo "$error_message" >&2
    return 1
  fi
}

# Issue種別IDをAPIから動的に取得
# JiraのIssue Type IDはプロジェクトごとに異なる可能性があるため、APIから取得する
get_issue_type_id_from_api() {
  local project_key="$1"
  local issue_type_name="$2"
  
  if [ -z "$project_key" ] || [ -z "$issue_type_name" ]; then
    echo "" >&2
    return 1
  fi
  
  # 認証チェック
  check_jira_auth || return 1
  
  local issue_types_data
  issue_types_data=$(jira_api_call "GET" "issue/createmeta?projectKeys=${project_key}&expand=projects.issuetypes")
  local api_call_status=$?
  
  if [ $api_call_status -ne 0 ] || ! echo "$issue_types_data" | jq -e . >/dev/null 2>&1; then
    # エラーメッセージは jira_api_call で出力される
    echo "" >&2
    return 1
  fi
  
  # 大文字小文字を区別せずにIssue Type名でIDを検索
  local issue_type_id
  issue_type_id=$(echo "$issue_types_data" | jq -r --arg name "$issue_type_name" '.projects[0].issuetypes[] | select(.name | test($name; "i")) | .id' | head -n 1)
  
  if [ -z "$issue_type_id" ] || [ "$issue_type_id" = "null" ]; then
    echo ""
    return 1
  else
    echo "$issue_type_id"
    return 0
  fi
}

# ステータス名のマッピング（英語名 → 日本語名）
# 実際のJiraのステータス名を取得して、英語名とマッチングする
map_status_name() {
  local status_name="$1"
  local issue_key="$2"
  
  # 入力文字列を小文字に正規化して比較（大文字小文字を区別しない）
  local normalized_status=$(echo "$status_name" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]_]//g')
  
  # 既に日本語名の場合はそのまま返す
  case "$normalized_status" in
    "todo"|"tod")
      echo "To Do"
      ;;
    "inprogress"|"in_progress")
      echo "進行中"
      ;;
    "done")
      echo "完了"
      ;;
    "backlog")
      echo "バックログ"
      ;;
    *)
      # 不明なステータス名の場合、実際のJiraから取得を試みる
      if [ -n "$issue_key" ]; then
        local transitions_data=$(jira_api_call "GET" "issue/${issue_key}/transitions" 2>/dev/null)
        if [ $? -eq 0 ] && echo "$transitions_data" | jq -e . >/dev/null 2>&1; then
          # 実際のステータス名を取得して、部分一致で検索
          local matched_name=$(echo "$transitions_data" | jq -r --arg status "$status_name" \
            '.transitions[] | select(.name | test($status; "i")) | .name' | head -1)
          if [ -n "$matched_name" ] && [ "$matched_name" != "null" ]; then
            echo "$matched_name"
            return 0
          fi
        fi
      fi
      # マッチしない場合は元の名前を返す
      echo "$status_name"
      ;;
  esac
}

