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

## 1. Jiraのチケット種別構造

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
./scripts/jira/get-issue-types.sh <project_key>
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

### 遷移可能なステータスの確認

```bash
./scripts/jira/get-transitions.sh <issue_key>
```

### ステータス遷移の実行

```bash
./scripts/jira/transition-issue.sh <issue_key> <status_name>
```

**例:**

```bash
# To Do に遷移
./scripts/jira/transition-issue.sh TEST-1 "To Do"

# In Progress に遷移
./scripts/jira/transition-issue.sh TEST-1 "In Progress"

# Done に遷移
./scripts/jira/transition-issue.sh TEST-1 "Done"
```

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

1. 利用可能なIssue種別を確認: `./scripts/jira/get-issue-types.sh <project_key>`
2. 正しいIssue種別名を使用（Epic, Bug, Story, Task, Sub-task）

## 9. 参考スクリプト

### プロジェクト情報取得

```bash
./scripts/jira/get-project-info.sh <project_key>
```

### Issue種別取得

```bash
./scripts/jira/get-issue-types.sh <project_key>
```

### フィールド定義取得

```bash
./scripts/jira/get-fields.sh <project_key> [issue_type_id]
```

### Issue情報取得

```bash
./scripts/jira/get-issue.sh <issue_key>
```

### ステータス遷移取得

```bash
./scripts/jira/get-transitions.sh <issue_key>
```

### ステータス遷移実行

```bash
./scripts/jira/transition-issue.sh <issue_key> <status_name>
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

