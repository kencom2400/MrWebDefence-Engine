# GitHub Projects設定

## 🔴 重要: GitHub CLI実行時の権限設定

**GitHub CLI (`gh`) コマンドは、必ず`required_permissions: ['all']`を指定してください。**

### 対象コマンド

以下のコマンドは**すべて`all`権限が必要**：

1. **Issue操作**: `gh issue view`, `gh issue comment`, `gh issue list`
2. **PR操作**: `gh pr view`, `gh pr create`, `gh pr comment`
3. **Projects操作**: `gh project item-list`, `gh api graphql`
4. **ワークフロースクリプト**: `./scripts/github/workflow/start-task.sh`

### 理由

- **証明書検証**: HTTPSでのGitHub API接続
- **認証トークン**: GitHub Personal Access Tokenへのアクセス
- **環境変数**: `GH_TOKEN`などの機密情報
- **ネットワークアクセス**: API呼び出し

### 実装例

```typescript
// ✅ 正しい
run_terminal_cmd({
  command: 'gh issue view 248 --json number,title,body',
  required_permissions: ['all'],
});

// ✅ 正しい
run_terminal_cmd({
  command: './scripts/github/workflow/start-task.sh',
  required_permissions: ['all'],
});

// ❌ エラーになる（証明書検証失敗）
run_terminal_cmd({
  command: 'gh issue view 248',
  required_permissions: ['network'],
});

// ❌ エラーになる（権限不足）
run_terminal_cmd({
  command: './scripts/github/workflow/start-task.sh',
  // required_permissions指定なし
});
```

**Issue #248の経験: `network`権限だけでは証明書検証エラーが発生。最初から`all`権限で実行すること。**

---

## 1. GitHub Projects設定

### プロジェクト情報

- **プロジェクト名**: Account Book Development
- **プロジェクト番号**: #1
- **プロジェクトID**: `PVT_kwHOANWYrs4BIOm-`
- **所有者**: @kencom2400

### ステータスフィールド

**ステータス一覧（順序）:**

1. 🎯 Epic (ID: `9aa232cf`)
2. 📋 Backlog (ID: `f908f688`)
3. 📝 To Do (ID: `f36fcf60`)
4. 🚧 In Progress (ID: `16defd77`)
5. 👀 Review (ID: `0f0f2f26`)
6. ✅ Done (ID: `2f722d70`)

**ステータスフィールドID**: `PVTSSF_lAHOANWYrs4BIOm-zg4wCDo`

### Issueワークフロー

```
📋 Backlog → 📝 To Do → 🚧 In Progress → 👀 Review → ✅ Done
```

**ステータス遷移のタイミング:**

- **Backlog**: Issue作成時（自動設定）
- **To Do**: 次に取り組むIssueとして選択した時
- **In Progress**: 実際の作業を開始した時
- **Review**: PRを作成し、レビューを依頼した時
- **Done**: PRがマージされ、Issueをクローズした時

### 🚨 Issue作成方法（重要）

**✅ 必須: 専用スクリプトを使用**

新規Issueを作成する際は、**必ず以下のスクリプトを使用**してください：

#### 方法1: GraphQL統合スクリプト（推奨）

複雑なIssueや長い本文のIssueを作成する場合は、GraphQL統合スクリプトを使用してください：

```bash
# 対話型モード
./scripts/github/issues/create-issue-graphql.sh

# バッチモード（コマンドライン引数）
./scripts/github/issues/create-issue-graphql.sh \
  --title "[bug] タイトル" \
  --body "本文" \
  --labels "bug,testing" \
  --priority "high"

# ファイルから本文を読み込み
./scripts/github/issues/create-issue-graphql.sh \
  --title "[feature] タイトル" \
  --body-file ./scripts/github/issues/templates/feature-template.md \
  --labels "feature,backend" \
  --priority "medium"
```

**メリット:**

- ✅ エスケープ処理が不要
- ✅ プロジェクトへの追加とステータス設定が自動
- ✅ エラーハンドリングが強化されている
- ✅ 対話型とバッチモードの両対応
- ✅ 再現性が高い

**詳細**: `./scripts/github/issues/create-issue-graphql.README.md`

#### 方法2: ファイルベーススクリプト（大量作成向け）

YAML/JSONファイルから大量のIssueを作成する場合は、ファイルベーススクリプトを使用してください：

```bash
# 1. Issue用のJSONまたはYAMLファイルを作成
cat > scripts/github/issues/issue-data/drafts/my-issue.json << EOF
{
  "title": "[FEATURE] 新機能の実装",
  "labels": ["feature", "backend"],
  "body": "## 概要\n\n詳細な説明..."
}
EOF

# 2. スクリプトでIssue作成
./scripts/github/issues/create-issue.sh scripts/github/issues/issue-data/drafts/my-issue.json
```

**メリット:**

- ✅ テンプレート管理が簡単
- ✅ 大量のIssueを一括作成できる
- ✅ バージョン管理が可能

**詳細**: `./scripts/github/issues/README.md`

#### 使い分け

| 用途                       | スクリプト                | 理由                                 |
| -------------------------- | ------------------------- | ------------------------------------ |
| **1つのIssueをすぐに作成** | `create-issue-graphql.sh` | コマンドラインで直接指定可能         |
| **複雑な本文のIssue**      | `create-issue-graphql.sh` | テンプレートファイルから読み込み可能 |
| **大量のIssueを一括作成**  | `create-issue.sh`         | ファイルベースで管理しやすい         |
| **対話型で作成**           | `create-issue-graphql.sh` | 対話型モード対応                     |

**❌ 禁止: GitHub CLI直接使用**

```bash
# ❌ これは使用しないでください
gh issue create --title "..." --body "..."
```

**理由:**

- プロジェクトに自動追加されません
- ステータスが"No Status"になります
- 手動でプロジェクトに追加する手間が発生します

**例外:**

テスト目的など、意図的にプロジェクトに追加したくない場合のみ、GitHub CLI直接使用を許可します。
