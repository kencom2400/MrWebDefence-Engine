# @start-task統合

## 4. @start-task統合

### 🚨 トリガー: `@start-task` コマンド

**🔴 重要: 実行権限について**

`@start-task`コマンドの実行時は、以下の理由から**必ず`required_permissions: ['all']`を指定**してください：

1. **GitHub API呼び出し**: Issue情報の取得、プロジェクトステータスの更新
2. **Git操作**: ブランチの作成、チェックアウト
3. **証明書検証**: HTTPSでのGitHub接続

**サンドボックス環境ではこれらの操作がエラーになるため、最初からall権限で実行すること。**

```typescript
// ✅ 正しい実行方法
run_terminal_cmd({
  command: './scripts/github/workflow/start-task.sh',
  required_permissions: ['all'],
});

// ❌ サンドボックスではエラーになる
run_terminal_cmd({
  command: './scripts/github/workflow/start-task.sh',
  // required_permissionsなし、またはnetworkのみ
});
```

**実行内容:**

0. **ルールファイル再読込**（最優先）
   - すべてのルールファイルを読み込む（@inc-all-rulesと同じ処理）
   - 最新のプロジェクトルールに従って作業を実行

1. **Issue取得**
   - GitHub Projectsから「📝 To Do」ステータスのIssueを取得
   - 各IssueのAssignee情報を確認
   - 自分にアサインされているOPENなIssueをフィルタリング

2. **優先順位判定とソート**
   - `priority: critical` → レベル4
   - `priority: high` → レベル3
   - `priority: medium` → レベル2
   - `priority: low` → レベル1
   - ラベルなし → レベル0
   - 同じ優先度の場合、Issue番号が小さい方を優先

3. **最優先Issueの選択と開始**
   - ソート後の最初のIssueを選択
   - Issueの詳細を表示
   - mainブランチを最新化してからブランチを作成
   - **GitHub ProjectsのステータスをIn Progressに変更**
   - Issueの内容に従って作業を即座に開始

### ✨ 新機能: start-task.sh スクリプト

Issue #201で実装された`start-task.sh`スクリプトを使用して、Issue開始を自動化できます。

#### 基本的な使い方

```bash
# 最優先Issueを自動選択
./scripts/github/workflow/start-task.sh

# Issue番号を指定して開始
./scripts/github/workflow/start-task.sh #201
./scripts/github/workflow/start-task.sh 201  # #なしでもOK

# ヘルプ表示
./scripts/github/workflow/start-task.sh --help
```

#### 機能

**自動選択モード（引数なし）:**

- GitHub Projectsから「📝 To Do」ステータスのIssueを取得
- 優先度順に自動ソート
- 最優先Issueを自動的に開始

**Issue ID指定モード（引数あり）:**

- 指定したIssue番号で作業を開始
- Issue存在確認、ステータス確認を自動実行

#### スクリプトが実行する処理

1. Issue情報の取得と確認
   - Issue存在確認
   - OPENステータス確認
   - アサイン状況確認
2. 自分にアサイン（未アサインの場合）
3. mainブランチの最新化
4. フィーチャーブランチの作成（`feature/issue-{番号}-{タイトル}`）
5. GitHub ProjectsでステータスをIn Progressに変更

#### エラーハンドリング

- Issue不存在時: エラーメッセージを表示して終了
- クローズ済みIssue: エラーメッセージを表示して終了
- 既にアサイン済み: 確認プロンプトを表示
- 他の人にアサイン済み: エラーメッセージを表示して終了
- 無効な形式: エラーメッセージと正しい形式を表示

詳細は[scripts/github/workflow/README.md](../../../scripts/github/workflow/README.md)を参照してください。

### Issue取得コマンド（手動実行の場合）

**🔴 重要: Issue詳細取得のベストプラクティス**

Issue詳細を取得する際は、**必ず`required_permissions: ['all']`を指定**してください。
サンドボックス環境では証明書検証やネットワークアクセスの制限により、GitHub API呼び出しが失敗します。

```typescript
// ✅ 正しい実行方法
run_terminal_cmd({
  command: 'gh issue view 248 --json number,title,body,labels',
  required_permissions: ['all'],
});

// ❌ サンドボックスではエラーになる
run_terminal_cmd({
  command: 'gh issue view 248 --json number,title,body,labels',
  required_permissions: ['network'], // これでもエラーになる
});
```

**エラーの理由:**

- 証明書検証の問題
- GitHub APIのHTTPS接続
- 環境変数やトークンへのアクセス

**GitHub CLI (`gh`) コマンドを実行する際は、常に`all`権限を使用すること。**

```bash
# ステップ1: GitHub Projectsから "📝 To Do" ステータスのIssue番号を取得
PROJECT_NUMBER="${PROJECT_NUMBER:-1}"
# OWNERは環境変数から取得、またはgh repo viewで動的に取得
OWNER="${OWNER:-$(gh repo view --json owner -q .owner.login)}"

TODO_ISSUES=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 9999 | \
  jq -r '.items[] | select(.status == "📝 To Do") | .content.number')

# ステップ2: 各IssueのAssignee情報とState（OPEN/CLOSED）を確認
ASSIGNED_ISSUES=()
for issue_num in $TODO_ISSUES; do
  assignee=$(gh issue view "$issue_num" --json assignees --jq '.assignees[].login' 2>/dev/null)
  issue_state=$(gh issue view "$issue_num" --json state --jq '.state' 2>/dev/null)
  current_user=$(gh api user --jq '.login')

  # OPENなIssueかつ自分にアサインされているもののみを対象
  if [ "$issue_state" = "OPEN" ] && echo "$assignee" | grep -q "$current_user"; then
    ASSIGNED_ISSUES+=("$issue_num")
  fi
done

# ステップ3: アサインされているIssueの詳細を取得
if [ ${#ASSIGNED_ISSUES[@]} -eq 0 ]; then
  echo "[]"
else
  for issue_num in "${ASSIGNED_ISSUES[@]}"; do
    gh issue view "$issue_num" --json number,title,labels,url
  done | jq -s '.'
fi
```

### ブランチ作成とステータス更新

```bash
# mainブランチを最新化
git checkout main
git pull origin main

# 新しいブランチを作成
git checkout -b feature/issue-<番号>-<説明>

# GitHub ProjectsのステータスをIn Progressに変更
./scripts/github/projects/set-issue-in-progress.sh <issue番号>
```

**重要事項:**

- ✅ 質問・確認なしで即座に実行
- ✅ GitHub ProjectsのステータスをIn Progressに変更
- ✅ 各IssueのAssignee情報を確認し、自分にアサインされているものをフィルタリング
- ✅ CLOSEDなIssueは除外（OPENなもののみ対象）

### 自動実行の対象外

以下のIssueは自動的に除外される：

- ✅ クローズ済みのIssue（`--state open` で除外）
- 👤 他のユーザーにアサインされているIssue（Assignee情報で除外）
- 📝 「📝 To Do」ステータス以外のIssue
- 📋 「📋 Backlog」ステータスのIssue

---

## 📚 よく使うコマンド集

### Issue操作

```bash
# Issue一覧取得
gh issue list --limit 100

# 特定ステータスのIssue取得（Project経由）
gh project item-list 1 --owner @me --format json | jq '.items[] | select(.status == "📝 To Do")'

# Issueのステータス更新
gh api graphql -f query="mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: \"PVT_kwHOANWYrs4BIOm-\"
    itemId: \"<PROJECT_ITEM_ID>\"
    fieldId: \"PVTSSF_lAHOANWYrs4BIOm-zg4wCDo\"
    value: { singleSelectOptionId: \"f36fcf60\" }
  }) {
    projectV2Item { id }
  }
}"
```

### Project操作

```bash
# Project全体の状態確認
gh project view 1 --owner @me

# Project Item一覧（JSON）
gh project item-list 1 --owner @me --format json --limit 200

# ステータス別集計
gh project item-list 1 --owner @me --format json | jq '[.items[] | {number: .content.number, status: .status}] | group_by(.status) | map({status: .[0].status, count: length})'
```

### PR状態確認

```bash
# PR詳細取得
gh pr view <PR番号> --json number,title,state,mergedAt,closedAt,body

# PRリスト取得
gh pr list --state all --limit 10

# 特定IssueのPR検索
gh pr list --search "Closes #209"
```

---

## 🔄 他のルールとの連携

### commit.md との連携

作業完了時：

1. コミット作成
2. PRプッシュ
3. **PRマージ後、プロジェクトステータスを「✅ Done」に更新**
   - `./scripts/github/projects/set-issue-done.sh <issue番号>`を実行
   - 関連するすべてのIssueのステータスを更新

---

## 📚 参考資料

- `.cursor/rules/00-workflow-checklist.d/` - ワークフロー全体
- `.cursor/rules/03-git-workflow.d/` - Git ワークフロー
- `templates/issue-report.md` - Issue報告テンプレート
