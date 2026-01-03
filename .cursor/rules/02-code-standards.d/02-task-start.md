# タスク開始フェーズ

## 1️⃣ タスク開始フェーズ

### 🚨 トリガー: `@start-task` コマンド

**実行内容:**

- [ ] Issueトラッカーから「To Do」ステータスのIssueを取得
  - GitHub Projects: 「📝 To Do」ステータス
  - Jira: 「To Do」ステータス
- [ ] 優先度順にソート
  - GitHub: priority: critical > high > medium > low
  - Jira: Critical > High > Medium > Low
- [ ] 最優先Issueを自動選択
- [ ] **🚨 CRITICAL: 必ずフィーチャーブランチを作成**（`feature/{ISSUE_KEY}-{タイトル}` 形式）
  - Jira: `feature/{ISSUE_KEY}-{タイトル}`（例: `feature/MWD-18-task-1-1`）
  - GitHub: `feature/issue-{ISSUE_NUM}-{タイトル}`（例: `feature/issue-198-description`）
- [ ] **🚨 CRITICAL: 必ずステータスを「In Progress」に変更**
  - GitHub Projects: 「🚧 In Progress」
  - Jira: 「In Progress」（日本語: 「進行中」）
  - **必須**: チケット開始時には必ずステータスを「In Progress」に変更すること
  - ステータス変更に失敗した場合は警告を表示するが、作業は継続可能

**🔴 絶対禁止事項:**

- ❌ **mainブランチでの直接作業は絶対禁止**
- ❌ ブランチ作成をスキップすることは絶対禁止
- ❌ 作業開始前に必ずブランチを確認する（`git branch`）

**参照ルール:**

- **`.cursor/rules/04-github-integration.d/02-status-management.md`** - Issue取得・ステータス管理（GitHub）
- **`.cursor/rules/04-github-integration.d/05-jira-integration.md`** - Jira統合（Jira）
- **`.cursor/rules/03-git-workflow.d/01-branch-management.md`** - ブランチ作成

**重要事項:**

- ✅ 質問・確認なしで即座に実行
- ✅ **必ずフィーチャーブランチを作成してから作業開始**
- ✅ **必ずIssueトラッカーのステータスをIn Progressに変更**
  - GitHub Projects: `./scripts/github/workflow/start-task.sh`
  - Jira: `./scripts/jira/workflow/start-task.sh`
  - **詳細**: 上記の「🚨 CRITICAL: 必ずステータスを「In Progress」に変更」を参照
- ✅ 各IssueのAssignee情報を確認し、自分にアサインされているものをフィルタリング

**🔴 実行権限について:**

`@start-task`コマンドの実行時は、以下の理由から**必ず`required_permissions: ['all']`を指定**してください：

1. **API呼び出し**: Issue情報の取得、ステータス遷移（GitHub API / Jira API）
2. **Git操作**: ブランチの作成、チェックアウト、プル
3. **ネットワーク接続**: HTTPSでのAPI接続、証明書検証

**サンドボックス環境ではこれらの操作がエラーになるため、最初からall権限で実行すること。**

```typescript
// ✅ 正しい実行方法（Jiraプロジェクトの場合）
run_terminal_cmd({
  command: 'bash scripts/jira/workflow/start-task.sh',
  required_permissions: ['all'],
});

// ✅ 正しい実行方法（GitHubプロジェクトの場合）
run_terminal_cmd({
  command: 'bash scripts/github/workflow/start-task.sh',
  required_permissions: ['all'],
});
```

**🚨 CRITICAL: AIアシスタントへの指示**

`@start-task`コマンドを受け取った際は、**必ず`required_permissions: ['all']`を指定して実行**してください。これは必須事項です。サンドボックス環境の制限により、ネットワーク接続やGit操作が失敗するため、最初からall権限で実行する必要があります。

---

## 1.5️⃣ 詳細設計フェーズ（FEATUREチケットのみ）

### 📐 FEATUREチケットでは実装前に詳細設計書を作成

**🚨 CRITICAL: FEATUREチケットの実装開始前に必須**

**対象:**

- ✅ FEATUREラベルのIssue
- ❌ バグ修正（既存設計の範囲内）
- ❌ リファクタリング（設計変更を伴わない）
- ❌ 設定値の変更のみ
- ❌ ドキュメント修正のみ
- ❌ テストコードの追加・修正のみ

**必須セクション（すべてのFEATUREで作成）:**

- [ ] **README.md**: 設計書の概要とアーキテクチャ
- [ ] **class-diagrams.md**: クラス構造
- [ ] **sequence-diagrams.md**: 処理フロー
- [ ] **input-output-design.md**: API仕様

**推奨セクション（必要に応じて作成）:**

- [ ] **screen-transitions.md**: 画面遷移（画面がある場合）
- [ ] **state-transitions.md**: 状態管理（複雑な状態がある場合）

**オプションセクション（必要に応じて作成）:**

- [ ] **batch-processing.md**: バッチ処理（バッチ処理がある場合）

**作成手順:**

```bash
# 1. ディレクトリ作成（FR番号は機能要件書を参照）
DIR="docs/detailed-design/FR-XXX_feature-name"
mkdir -p "$DIR"

# 2. テンプレートをコピー
cp docs/detailed-design/TEMPLATE/*.template "$DIR/"

# 3. .templateを削除してリネーム
cd "$DIR"
for file in *.template; do
  if [ -f "$file" ]; then
    mv "$file" "${file%.template}"
  fi
done

# 4. 不要なセクションを削除
# 画面がない場合
rm screen-transitions.md
# 状態管理が単純な場合
rm state-transitions.md
# バッチ処理がない場合
rm batch-processing.md
```

**設計レビュー:**

- [ ] 設計書を作成後、PRまたはIssueコメントでレビュー依頼
- [ ] レビュー承認後に実装開始
- [ ] 設計変更が必要な場合は、設計書を更新してから実装変更

**参照資料:**

- **`docs/development/detailed-design-guideline.md`** - 詳細設計書作成ガイドライン
- **`docs/detailed-design/TEMPLATE/`** - テンプレート
- **`docs/detailed-design/FR-001-005_institution-integration/`** - 参考例

**重要事項:**

- ✅ **実装前に必ず作成**（手戻り防止）
- ✅ 必須セクションは必ず作成
- ✅ Mermaid記法で図を作成
- ✅ レビュー承認後に実装開始
- ❌ 実装後の事後作成は避ける
