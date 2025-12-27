# Jira統合

## 概要

このドキュメントは、Jira API統合とチケット操作に関するルールを定義します。GitHub Issue/ProjectとJiraをプロジェクト単位で選択可能にする機能の使用方法を説明します。

## 🔴 重要な設計原則

### Issue Type IDの動的取得

**❌ 禁止: Issue Type IDのハードコード**

JiraのIssue Type IDはプロジェクトごとに異なる可能性があるため、ハードコードしてはいけません。

```bash
# ❌ 悪い例: ハードコード
case "$issue_type" in
  "Task") echo "10071" ;;
  "Bug") echo "10072" ;;
esac
```

**✅ 推奨: APIから動的に取得**

必ずAPIから動的に取得してください。

```bash
# ✅ 良い例: APIから取得
ISSUE_TYPE_ID=$(get_issue_type_id_from_api "$PROJECT_KEY" "$ISSUE_TYPE")
```

**理由:**
- プロジェクトごとにIssue Type IDが異なる
- カスタムIssue Typeが追加される可能性がある
- メンテナンス性が向上する

### コードの重複を避ける

**❌ 禁止: 共通関数の重複実装**

`common.sh`に定義されている関数を各スクリプトで再実装してはいけません。

```bash
# ❌ 悪い例: jira_api_call関数を重複実装
jira_api_call() {
  # 実装...
}
```

**✅ 推奨: common.shをsourceして使用**

必ず`common.sh`をsourceして共通関数を利用してください。

```bash
# ✅ 良い例: common.shをsource
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
  source "${SCRIPT_DIR}/common.sh"
fi
```

**理由:**
- コードの重複を避ける
- メンテナンス性が向上する
- バグ修正が一箇所で済む

### エラーハンドリングの簡素化

**❌ 禁止: 重複したエラーチェック**

エラーハンドリングのロジックを重複させてはいけません。

```bash
# ❌ 悪い例: 重複したエラーチェック
RESULT=$(some_function 2>&1) || {
  echo "エラー: 処理に失敗しました" >&2
  exit 1
}

if [ -z "$RESULT" ]; then
  echo "エラー: 結果が空です" >&2
  exit 1
fi
```

**✅ 推奨: 1つのチェックに統合**

エラーチェックは1つにまとめてください。

```bash
# ✅ 良い例: 1つのチェックに統合
RESULT=$(some_function 2>&1)
if [ -z "$RESULT" ]; then
  echo "エラー: 処理に失敗しました" >&2
  exit 1
fi
```

**理由:**
- コードがクリーンで保守しやすくなる
- パフォーマンスが向上する

### API呼び出しの効率化

**❌ 禁止: 同じAPI呼び出しの重複実行**

エラー時に同じAPI呼び出しを再度実行してはいけません。

```bash
# ❌ 悪い例: エラー時に同じAPI呼び出しを再度実行
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  -H "Authorization: Basic ${AUTH_HEADER}" \
  "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}")

if [ "$HTTP_CODE" != "204" ]; then
    # エラー詳細を取得するために再度同じAPI呼び出しを実行（非効率）
    ERROR_RESPONSE=$(curl -s -X DELETE \
      -H "Authorization: Basic ${AUTH_HEADER}" \
      "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}")
    handle_jira_error "$ERROR_RESPONSE"
fi
```

**✅ 推奨: 一度のAPI呼び出しでHTTPステータスコードとレスポンスボディの両方を取得**

`curl`の`-w "\n%{http_code}"`オプションを使用して、HTTPステータスコードとレスポンスボディを一度のAPI呼び出しで取得してください。

```bash
# ✅ 良い例: 一度のAPI呼び出しで両方を取得
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
  -H "Authorization: Basic ${AUTH_HEADER}" \
  -H "Accept: application/json" \
  "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}?deleteSubtasks=false" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "204" ]; then
    echo "✅ 成功"
else
    echo "❌ エラー: HTTP ${HTTP_CODE}" >&2
    handle_jira_error "$RESPONSE_BODY"
    exit 1
fi
```

**理由:**
- API呼び出し回数が減り、パフォーマンスが向上する
- ネットワーク負荷が軽減される
- エラー時のレスポンスボディを確実に取得できる
- `common.sh`の`jira_api_call`関数と同じパターンで一貫性が保たれる
- エラーメッセージの重複を避ける
- デバッグが容易になる

### 未使用変数の削除

**❌ 禁止: 未使用変数の定義**

使用されない変数を定義してはいけません。

```bash
# ❌ 悪い例: 未使用変数
ISSUE_NUM=$(echo "$ISSUE_KEY" | sed 's/.*-//')
BRANCH_NAME="feature/${ISSUE_KEY}-${TITLE}"
# ISSUE_NUM は使用されていない
```

**✅ 推奨: 必要な変数のみ定義**

実際に使用する変数のみを定義してください。

```bash
# ✅ 良い例: 必要な変数のみ
BRANCH_NAME="feature/${ISSUE_KEY}-${TITLE}"
```

**理由:**
- コードがクリーンで読みやすくなる
- 混乱を避ける
- メンテナンス性が向上する

### 引数パースの堅牢性

**推奨: 位置引数からオプション引数への移行**

将来的な拡張性を考慮して、位置引数ではなくオプション引数を使用することを推奨します。

```bash
# ✅ 良い例: オプション引数を使用
while [[ $# -gt 0 ]]; do
  case $1 in
    --project-key)
      PROJECT_KEY="$2"
      shift 2
      ;;
    --json)
      OUTPUT_JSON="--json"
      shift
      ;;
    *)
      echo "❌ エラー: 不明なオプション: $1" >&2
      exit 1
      ;;
  esac
done
```

**理由:**
- 引数の順序に依存しない
- 新しいオプションの追加が容易
- メンテナンス性が向上する

## 1. 必要な依存関係

### yqコマンド

Jira設定ファイル（`config.sh`）は、プロジェクト設定ファイル（`config/projects/*.yaml`）から設定を読み込むために`yq`コマンドを使用します。

**インストール方法:**

- **macOS**: `brew install yq`
- **Linux**: `snap install yq` または `sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq`
- **Windows**: `choco install yq` または [GitHub Releases](https://github.com/mikefarah/yq/releases) からダウンロード

**注意:**
- `yq`がインストールされていない場合、設定ファイルは警告を表示し、デフォルト値または環境変数を使用します
- プロジェクト設定ファイル（`config/projects/*.yaml`）から設定を読み込むには`yq`が必要です

## 2. Jiraのチケット種別構造

### 階層構造

```
Epic（最上位）
  ├─ Bug（バグ）
  ├─ Story（ストーリー）
  ├─ Task（タスク）
  └─ Sub-task（サブタスク）
```

### チケット種別の説明

- **Epic**: 大規模な機能やプロジェクト全体を表す最上位のチケット
- **Bug**: 問題やエラーを報告するチケット
- **Story**: ユーザー目標として表明された機能
- **Task**: さまざまな小規模作業
- **Sub-task**: 大規模なタスク内の小さな作業

### チケット種別ID

**🔴 重要: Issue Type IDはプロジェクトごとに異なります**

各チケット種別にはIDが割り当てられていますが、**プロジェクトごとに異なる可能性があるため、ハードコードしてはいけません**。

**❌ 禁止: ハードコード**
```bash
# これは使用しないでください
case "$issue_type" in
  "Task") echo "10071" ;;
  "Bug") echo "10072" ;;
esac
```

**✅ 推奨: APIから動的に取得**
```bash
# 必ずAPIから取得してください
ISSUE_TYPE_ID=$(get_issue_type_id_from_api "$PROJECT_KEY" "$ISSUE_TYPE")
```

**理由:**
- プロジェクトごとにIssue Type IDが異なる
- カスタムIssue Typeが追加される可能性がある
- メンテナンス性が向上する

**取得方法:**
```bash
# 利用可能なIssue種別とIDを確認
./scripts/jira/issues/get-issue-types.sh <project_key>
```

## 2. ステータス遷移ルール

### ステータス一覧

- **Backlog**: バックログ（未着手）
- **To Do**: To Do（着手予定）
- **In Progress**: 進行中（作業中）
- **Done**: 完了

### ステータス遷移フロー

```
Backlog → To Do → In Progress → Done
                ↑                ↓
                └────────────────┘
              （戻り遷移）
```

### 遷移ルール

1. **Backlog → To Do**: 次に取り組むチケットとして選択した時
2. **To Do → In Progress**: 実際の作業を開始した時
3. **In Progress → Done**: 作業が完了した時
4. **Done → To Do**: 完了後に再作業が必要になった時（戻り遷移）
5. **In Progress → To Do**: 作業を中断し、後で再開する時（戻り遷移）

### ステータス遷移のタイミング

- **Backlog**: チケット作成時（自動設定）
- **To Do**: 次に取り組むチケットとして選択した時
- **In Progress**: 実際の作業を開始した時
- **Done**: 作業が完了し、PRがマージされた時

## 3. フィールド定義の取得方法

### APIエンドポイント

```bash
GET /rest/api/3/issue/createmeta?projectKeys={projectKey}&expand=projects.issuetypes.fields
```

### 必須フィールド

各チケット種別には必須フィールドがあります：

- **summary**: チケットのタイトル（必須）
- **description**: チケットの説明（必須）
- **project**: プロジェクトキー（必須）
- **issuetype**: チケット種別（必須）

### カスタムフィールド

プロジェクトによっては、カスタムフィールドが定義されている場合があります。フィールド定義を取得して確認してください：

```bash
./scripts/jira/get-fields.sh <project_key> [issue_type_id]
```

## 4. Issue作成方法

### ✅ 必須: 専用スクリプトを使用

新規Jira Issueを作成する際は、**必ず以下のスクリプトを使用**してください：

#### 方法1: 対話型モード（推奨）

```bash
./scripts/jira/issues/create-issue.sh
```

対話形式で以下を入力します：
1. プロジェクトキー（設定ファイルから取得可能）
2. Issue種別（Epic, Bug, Story, Task, Sub-task）
3. タイトル
4. 本文（ファイルから読み込み可能）
5. ステータス（Backlog, ToDo, In Progress, Done）

#### 方法2: バッチモード

```bash
./scripts/jira/issues/create-issue.sh \
  --title "[bug] E2Eテストエラー" \
  --body "## 概要\n\nE2Eテストが失敗します" \
  --issue-type Bug \
  --status ToDo \
  --project-key TEST
```

#### 方法3: ファイルから本文を読み込み

```bash
./scripts/jira/issues/create-issue.sh \
  --title "[feature] 新機能" \
  --body-file ./issue-content.md \
  --issue-type Story \
  --status Backlog \
  --project-key TEST
```

**詳細**: `./scripts/jira/issues/create-issue.README.md`

**❌ 禁止: Jira API直接使用**

```bash
# ❌ これは使用しないでください
curl -X POST "https://kencom2400.atlassian.net/rest/api/3/issue" \
  -H "Authorization: Basic ..." \
  -H "Content-Type: application/json" \
  -d '{"fields": {...}}'
```

**理由:**

- エラーハンドリングが不十分
- ステータス遷移が自動化されない
- 設定ファイルの管理が複雑

## 5. ステータス遷移方法

### ステータス名のマッピング

Jiraのステータス名は、プロジェクトによって英語名または日本語名が使用される可能性があります。`map_status_name`関数は、英語名を日本語名に自動的にマッピングします。

**推奨: 大文字小文字を区別しない比較**

ステータス名の比較は、大文字小文字を区別しない方法を使用してください。

```bash
# ✅ 良い例: 小文字に正規化して比較
local normalized_status=$(echo "$status_name" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]_]//g')
case "$normalized_status" in
  "todo"|"tod")
    echo "To Do"
    ;;
  "inprogress"|"in_progress")
    echo "進行中"
    ;;
esac
```

**理由:**
- 複数のパターン（"To Do"|"ToDo"|"TODO"）を1つにまとめられる
- 可読性と保守性が向上する
- 将来的にステータス名が増えた場合に対応しやすい

### 遷移可能なステータスの確認

```bash
./scripts/jira/projects/get-transitions.sh <issue_key>
```

### ステータス遷移の実行

```bash
./scripts/jira/projects/transition-issue.sh <issue_key> <status_name>
```

**例:**

```bash
# To Do に遷移
./scripts/jira/projects/transition-issue.sh TEST-1 "To Do"

# In Progress に遷移
./scripts/jira/projects/transition-issue.sh TEST-1 "In Progress"

# Done に遷移
./scripts/jira/projects/transition-issue.sh TEST-1 "Done"
```

**注意:** ステータス名は自動的にマッピングされます（例: "In Progress" → "進行中"）

## 6. APIキー設定方法

### 環境変数の設定

Jira APIを使用するには、以下の環境変数を設定する必要があります：

```bash
export JIRA_EMAIL='your-email@example.com'
export JIRA_API_TOKEN='your-api-token'
```

### 設定ファイルの使用（推奨）

`scripts/jira/config.local.sh` ファイルを作成して、認証情報を設定してください：

```bash
# scripts/jira/config.local.sh.example をコピー
cp scripts/jira/config.local.sh.example scripts/jira/config.local.sh

# 認証情報を設定
export JIRA_EMAIL='your-email@example.com'
export JIRA_API_TOKEN='your-api-token'
```

**重要**: `config.local.sh` は `.gitignore` に追加されているため、Gitにpushされません。

### APIトークンの取得方法

1. Jiraにログイン
2. アカウント設定 → セキュリティ → APIトークン
3. 「APIトークンの作成」をクリック
4. トークン名を入力して作成
5. 表示されたトークンをコピー（一度しか表示されません）

## 7. プロジェクト設定

### プロジェクト設定ファイル

プロジェクト単位で `issue_tracker` を設定できます：

```yaml
# config/projects/<project_name>.yaml
project_name: my-project
repositories:
  - name: my-repo
    url: https://github.com/owner/my-repo
    branch: main
    language: python/3.12

# Issueトラッカー設定
issue_tracker: jira  # または "github"

# Jira設定（issue_tracker が jira の場合に必須）
jira:
  project_key: TEST
  base_url: https://kencom2400.atlassian.net  # オプション
```

### 設定の読み込み

配信先リポジトリでは、`scripts/jira/config.sh` から設定を読み込みます：

```bash
source scripts/jira/config.sh
# → ISSUE_TRACKER=jira
# → JIRA_PROJECT_KEY=TEST
# → JIRA_BASE_URL=https://kencom2400.atlassian.net
```

## 8. エラーハンドリング

### 認証エラー

```
❌ エラー: 環境変数 JIRA_EMAIL と JIRA_API_TOKEN が設定されていません。
```

**対処方法:**

1. `scripts/jira/config.local.sh` を作成
2. `JIRA_EMAIL` と `JIRA_API_TOKEN` を設定
3. スクリプトを再実行

### プロジェクト未検出

```
❌ エラー: プロジェクト情報の取得に失敗しました
```

**対処方法:**

1. プロジェクトキーが正しいか確認
2. プロジェクトへのアクセス権限を確認
3. JiraインスタンスのURLが正しいか確認

### Issue種別未検出

```
❌ エラー: 不明なIssue種別: InvalidType
```

**対処方法:**

1. 利用可能なIssue種別を確認: `./scripts/jira/issues/get-issue-types.sh <project_key>`
2. 正しいIssue種別名を使用（Epic, Bug, Story, Task, Sub-task）

## 9. 参考スクリプト

### プロジェクト情報取得

```bash
./scripts/jira/projects/get-project-info.sh <project_key>
```

### Issue種別取得

```bash
./scripts/jira/issues/get-issue-types.sh <project_key>
```

### フィールド定義取得

```bash
./scripts/jira/get-fields.sh <project_key> [issue_type_id]
```

### Issue情報取得

```bash
./scripts/jira/issues/get-issue.sh <issue_key>
```

### ステータス遷移取得

```bash
./scripts/jira/projects/get-transitions.sh <issue_key>
```

### ステータス遷移実行

```bash
./scripts/jira/projects/transition-issue.sh <issue_key> <status_name>
```

## 10. セキュリティのベストプラクティス

1. **APIトークンの管理**
   - `config.local.sh` を使用して認証情報を管理
   - `.gitignore` で `config.local.sh` を除外
   - APIトークンは定期的に更新

2. **環境変数の使用**
   - 本番環境では環境変数を使用
   - スクリプト内に認証情報をハードコードしない

3. **アクセス権限の確認**
   - 必要最小限の権限のみを付与
   - プロジェクトへのアクセス権限を定期的に確認

## 11. GitHub統合との違い

| 項目 | GitHub | Jira |
|------|--------|------|
| Issue種別 | Labelで管理 | 階層構造（Epic > Bug/Story/Task > Sub-task） |
| ステータス | GitHub Projectsで管理 | Jiraのワークフローで管理 |
| プロジェクト | リポジトリ単位 | プロジェクト単位（複数リポジトリ） |
| 認証 | GitHub Personal Access Token | Jira API Token |

## 12. 使い分け

### GitHub Issueを使用する場合

- リポジトリ単位でIssueを管理したい
- GitHub Projectsと連携したい
- オープンソースプロジェクト

### Jiraを使用する場合

- プロジェクト単位でIssueを管理したい
- 複数のリポジトリを1つのプロジェクトで管理したい
- エンタープライズ環境

## 13. @start-task統合（Jira版）

### 🚨 トリガー: `@start-task` コマンド

**🔴 重要: 実行権限について**

`@start-task`コマンドの実行時は、以下の理由から**必ず`required_permissions: ['all']`を指定**してください：

1. **Jira API呼び出し**: Issue情報の取得、ステータス遷移
2. **Git操作**: ブランチの作成、チェックアウト
3. **証明書検証**: HTTPSでのJira接続

**サンドボックス環境ではこれらの操作がエラーになるため、最初からall権限で実行すること。**

```typescript
// ✅ 正しい実行方法（Jiraプロジェクトの場合）
run_terminal_cmd({
  command: './scripts/jira/workflow/start-task.sh',
  required_permissions: ['all'],
});

// ✅ 正しい実行方法（GitHubプロジェクトの場合）
run_terminal_cmd({
  command: './scripts/github/workflow/start-task.sh',
  required_permissions: ['all'],
});
```

**実行内容:**

0. **ルールファイル再読込**（最優先）
   - すべてのルールファイルを読み込む（@inc-all-rulesと同じ処理）
   - 最新のプロジェクトルールに従って作業を実行

1. **Issue取得**
   - Jiraから「To Do」ステータスのIssueを取得
   - 現在のユーザーにアサインされているIssueをフィルタリング

2. **優先順位判定とソート**
   - `Critical` → レベル4
   - `High` → レベル3
   - `Medium` → レベル2
   - `Low` → レベル1
   - 優先度なし → レベル0
   - 同じ優先度の場合、Issueキーでソート

3. **最優先Issueの選択と開始**
   - ソート後の最初のIssueを選択
   - Issueの詳細を表示
   - mainブランチを最新化してからブランチを作成
   - **JiraのステータスをIn Progressに変更**
   - Issueの内容に従って作業を即座に開始

### ✨ 新機能: start-task.sh スクリプト（Jira版）

Jira統合で実装された`start-task.sh`スクリプトを使用して、Issue開始を自動化できます。

#### 基本的な使い方

```bash
# 最優先Issueを自動選択
./scripts/jira/workflow/start-task.sh

# Issueキーを指定して開始
./scripts/jira/workflow/start-task.sh MWD-123

# ヘルプ表示
./scripts/jira/workflow/start-task.sh --help
```

#### 機能

**自動選択モード（引数なし）:**

- Jiraから「To Do」ステータスのIssueを取得
- 現在のユーザーにアサインされているIssueのみを対象
- 優先度順に自動ソート
- 最優先Issueを自動的に開始

**Issueキー指定モード（引数あり）:**

- 指定したIssueキー（例：MWD-123）で作業を開始
- Issue存在確認、ステータス確認を自動実行

#### スクリプトが実行する処理

1. Issue情報の取得と確認
   - Issue存在確認
   - 完了ステータス確認（statusCategory.key = "done"）
   - アサイン状況確認
2. 自分にアサイン（未アサインの場合）
3. mainブランチの最新化
4. フィーチャーブランチの作成（`feature/{ISSUE_KEY}-{タイトル}`）
5. JiraでステータスをIn Progressに変更

#### エラーハンドリング

- Issue不存在時: エラーメッセージを表示して終了
- 完了済みIssue: エラーメッセージを表示して終了
- 既にアサイン済み: 確認プロンプトを表示
- 他の人にアサイン済み: エラーメッセージを表示して終了
- 無効な形式: エラーメッセージと正しい形式を表示

#### プロジェクト設定

スクリプトは以下の環境変数または設定ファイルからプロジェクトキーを取得します：

- `JIRA_PROJECT_KEY`: 優先的に使用
- `TEST_PROJECT_KEY`: フォールバック
- `config/projects/*.yaml`の`jira.project_key`: プロジェクト設定から取得

### Issue取得コマンド（手動実行の場合）

**🔴 重要: Issue詳細取得のベストプラクティス**

Issue詳細を取得する際は、**必ず`required_permissions: ['all']`を指定**してください。
サンドボックス環境では証明書検証やネットワークアクセスの制限により、Jira API呼び出しが失敗します。

```typescript
// ✅ 正しい実行方法
run_terminal_cmd({
  command: './scripts/jira/get-issue.sh MWD-123',
  required_permissions: ['all'],
});
```

**Jira API (`curl`) コマンドを実行する際は、常に`all`権限を使用すること。**

```bash
# JQLで「To Do」ステータスのIssueを取得
JQL="project = MWD AND status = \"To Do\" AND assignee = currentUser() ORDER BY priority DESC, created ASC"
JQL_ENCODED=$(echo "$JQL" | jq -sRr @uri)

# Jira APIで検索
curl -s -X GET \
  -H "Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)" \
  -H "Accept: application/json" \
  "${JIRA_BASE_URL}/rest/api/3/search?jql=${JQL_ENCODED}&maxResults=50&fields=summary,status,priority,assignee"
```

### ブランチ作成とステータス更新

```bash
# mainブランチを最新化
git checkout main
git pull origin main

# 新しいブランチを作成
git checkout -b feature/MWD-123-<説明>

# JiraのステータスをIn Progressに変更
./scripts/jira/projects/set-issue-in-progress.sh MWD-123
```

**重要事項:**

- ✅ 質問・確認なしで即座に実行
- ✅ JiraのステータスをIn Progressに変更
- ✅ 各IssueのAssignee情報を確認し、自分にアサインされているものをフィルタリング
- ✅ 完了済みIssueは除外（statusCategory.key != "done"）

### 自動実行の対象外

以下のIssueは自動的に除外される：

- ✅ 完了済みのIssue（statusCategory.key = "done"）
- 👤 他のユーザーにアサインされているIssue（Assignee情報で除外）
- 📝 「To Do」ステータス以外のIssue
- 📋 「Backlog」ステータスのIssue

### 🚨 重要な方針: 該当するチケットがない場合の動作

**意図しないタスクが実行されることを防ぐため、以下の方針を厳守すること：**

1. **「To Do」ステータスのIssueがない場合**
   - 自動的に「Backlog」から選択することは**禁止**
   - その旨を伝えたうえで**終了する**
   - ユーザーが明示的にIssueキーを指定した場合のみ開始可能

2. **理由**
   - 意図しないタスクの実行を防ぐ
   - ユーザーが明示的に選択したIssueのみを開始する
   - 自動選択の範囲を明確に定義する

3. **実装**
   - `start-task.sh`スクリプトは「To Do」ステータスのIssueのみを自動選択
   - 該当するIssueがない場合は、エラーメッセージを表示して終了
   - 手動でIssueキーを指定する場合は、ステータスに関わらず開始可能

### GitHub版との違い

| 項目 | GitHub版 | Jira版 |
|------|----------|--------|
| Issue識別子 | Issue番号（例：#198） | Issueキー（例：MWD-123） |
| ステータス名 | 「📝 To Do」 | 「To Do」 |
| 優先度 | ラベル（priority: critical等） | フィールド（Priority） |
| アサイン | GitHubユーザー名 | JiraアカウントID |
| ステータス更新 | GitHub Projects API | Jira Transitions API |
| スクリプトパス | `./scripts/github/workflow/start-task.sh` | `./scripts/jira/workflow/start-task.sh` |

