# ワークフロー・チェックリスト - 最優先ガイド

```
╔═══════════════════════════════════════════════════════════════╗
║  ⭐ WORKFLOW CHECKLIST - 全体フローの羅針盤 ⭐               ║
║                                                               ║
║  このファイルは、タスク開始から完了までの全体フローを       ║
║  示します。各ステップで参照すべきルールファイルが           ║
║  明記されています。                                          ║
╚═══════════════════════════════════════════════════════════════╝
```

## 📋 ワークフロー全体像

```
@start-task
    ↓
1️⃣ タスク開始
    ↓
1.5️⃣ 詳細設計（FEATUREのみ）
    ↓
2️⃣ 実装・コミット
    ↓
3️⃣ push前チェック
    ↓
4️⃣ PR作成・レビュー
    ↓
5️⃣ マージ・完了報告
```

---

## 1️⃣ タスク開始フェーズ

### 🚨 トリガー: `@start-task` コマンド

**実行内容:**

- [ ] GitHub Projectsから「📝 To Do」ステータスのIssueを取得
- [ ] 優先度順にソート（priority: critical > high > medium > low）
- [ ] 最優先Issueを自動選択
- [ ] **🚨 CRITICAL: 必ずフィーチャーブランチを作成**（`feat/XXX-description` または `fix/XXX-description`）
- [ ] ステータスを「🚧 In Progress」に変更

**🔴 絶対禁止事項:**

- ❌ **mainブランチでの直接作業は絶対禁止**
- ❌ ブランチ作成をスキップすることは絶対禁止
- ❌ 作業開始前に必ずブランチを確認する（`git branch`）

**参照ルール:**

- **`.cursor/rules/04-github-integration.md`** - Issue取得・ステータス管理
- **`.cursor/rules/03-git-workflow.md`** - ブランチ作成

**重要事項:**

- ✅ 質問・確認なしで即座に実行
- ✅ **必ずフィーチャーブランチを作成してから作業開始**
- ✅ GitHub ProjectsのステータスをIn Progressに変更
- ✅ 各IssueのAssignee情報を確認し、自分にアサインされているものをフィルタリング

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
  mv "$file" "${file%.template}"
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

---

## 2️⃣ 実装・コミットフェーズ

### 📝 実装中の必須確認事項

**コード品質:**

- [ ] **型安全性を絶対遵守**（any型禁止）
- [ ] **Enum型の比較は型安全に**（`Object.entries()`使用時は明示的型キャスト）
- [ ] 危険な型キャストを使用していないか
- [ ] データアクセスは配列順序依存ではなくIDベースか
- [ ] テストコードも型安全か

**参照ルール:**

- **`.cursor/rules/01-project.md`** - アーキテクチャ原則・技術スタック
- **`.cursor/rules/02-code-standards.md`** - コード品質・型安全性・テスト

### 🔄 コミットタイミング

**🚨 CRITICAL: 作業完了時は即座に自動コミット**

- ✅ 機能実装完了時
- ✅ バグ修正完了時
- ✅ テスト追加時
- ✅ ドキュメント更新時
- ✅ 各レイヤー実装完了時
- ❌ 「後でコミット」は禁止

**コミット前チェックリスト（コンテナ使用）:**

- [ ] ビルドが成功するか（`./scripts/backend/build.sh` - コンテナ使用）
- [ ] Lintエラーがないか（`./scripts/backend/lint.sh` - コンテナ使用）
- [ ] ユニットテストがパスするか（`./scripts/backend/test.sh unit` - コンテナ使用）
- [ ] E2Eテストがパスするか（`./scripts/backend/test.sh e2e` - コンテナ使用、該当する場合）
- [ ] 不要なコメントやconsole.logを削除
- [ ] コミットメッセージが適切か

**⚠️ 重要: テスト実行は必ずコンテナを使用したスクリプトで実行すること**

**参照ルール:**

- **`.cursor/rules/03-git-workflow.md`** - コミットルール・タイミング

---

## 3️⃣ push前チェックフェーズ

### 🚨 CRITICAL: push前の必須チェック

```
╔═══════════════════════════════════════════════════════════════╗
║  🔴 ABSOLUTE PROHIBITION - テスト未実行でのpush禁止 🔴      ║
║                                                               ║
║  ローカルですべてのテストがPASSするまでpushは絶対禁止         ║
║  「見込み」「多分大丈夫」という判断は禁止                     ║
╚═══════════════════════════════════════════════════════════════╝
```

**必須4ステップ（すべてPASS必須・コンテナ使用）:**

```bash
1. ./scripts/backend/lint.sh         # 構文・スタイル（コンテナ使用）
2. ./scripts/backend/build.sh         # ビルド確認（コンテナ使用）⭐ 重要
3. ./scripts/backend/test.sh unit     # ユニットテスト（コンテナ使用）
4. ./scripts/backend/test.sh e2e      # E2Eテスト（コンテナ使用）
```

**実行時間:** 約4-6分

**🚨 絶対禁止事項:**

- ❌ テストを実行せずにpushする
- ❌ テストが失敗している状態でpushする
- ❌ **失敗したテストが1つでもある状態でpushする**（最重要）
- ❌ 「一部のテストが失敗していても、他のテストがPASSしていればOK」という考え
- ❌ 「別のテストファイルの失敗だから関係ない」という考え
- ❌ 「見込み」「多分大丈夫」という判断でpushする
- ❌ 「CIで確認すればいい」という考えでpushする
- ❌ 一部のテストだけ実行してpushする
- ❌ テスト結果に「failed」が表示されているのにpushする

**✅ 正しいワークフロー（コンテナ使用）:**

```bash
# 1. すべてのチェックを実行（コンテナ使用）
./scripts/backend/lint.sh
./scripts/backend/build.sh
./scripts/backend/test.sh unit
./scripts/backend/test.sh e2e

# 2. すべてPASSしたことを確認
# ✅ Lint: PASS
# ✅ Build: PASS
# ✅ Unit Tests: PASS
# ✅ E2E Tests: PASS

# 3. すべてPASSした場合のみpush
git push origin <ブランチ名>
```

**テストが失敗した場合:**

```bash
# ❌ テストが失敗
./scripts/backend/test.sh e2e
# → 2 failed, 35 passed, 26 skipped

# 🚨 push禁止！失敗したテストを必ず修正する
# （修正作業）
# 例: テストコードの修正、実装の修正、または test.skip() でスキップ

# ✅ 修正後、再度チェック
./scripts/backend/test.sh e2e
# → 0 failed, 37 passed, 26 skipped  ← failedが0であることを確認

# ✅ failedが0になったらpush
git push origin <ブランチ名>
```

**🚨 テスト結果の確認方法:**

```bash
# push前の最終確認
./scripts/backend/test.sh e2e | grep -E "(failed|passed|skipped)"

# 出力例（push OK）:
#   37 passed
#   26 skipped
#   → failedが表示されていない = push OK

# 出力例（push禁止）:
#   2 failed
#   35 passed
#   26 skipped
#   → failedが1つでもある = push禁止（必ず修正）
```

**なぜ重要か:**

- ビルドエラーはすべてのCI jobをブロックする
- ローカルでの早期発見により時間節約（実例: Issue #22で20分の損失）
- CI実行の無駄を防ぐ（約5-10分の節約）
- プロジェクトの品質を維持する

**詳細:** `.cursor/rules/03-git-workflow.md` の「3. Push前チェック」セクション参照

---

## 4️⃣ PR作成・レビューフェーズ

### 📤 PR作成ワークフロー

**🚨 CRITICAL: PR作成は必須**

- ❌ **mainブランチへの直接push・コミットは絶対禁止**
- ✅ **すべての変更は必ずPRを経由してmainにマージ**
- ✅ PRが承認・マージされるまでIssueはIn Progressのまま

**自動化されたフロー:**

1. **フィーチャーブランチにpush後**: PRを作成
2. **追加のpush時**: PR本文を自動更新（必要に応じて）
3. **レビュー依頼**: 必要に応じてレビュアーを指定
4. **PR承認後**: mainにマージ
5. **マージ後のみ**: IssueをDoneに変更

**PR作成前チェック:**

- [ ] 現在のブランチがmainではないことを確認（`git branch`）
- [ ] すべての変更がコミット済み
- [ ] push前のローカルチェックを完了（lint/test/e2e）
- [ ] テストが通ることを確認
- [ ] コンフリクトが発生していないか確認

**参照ルール:**

- **`.cursor/rules/03-git-workflow.md`** - PR作成・レビュー対応

### 🔍 CI確認と対応

**PR作成後の自動確認:**

1. CIステータスの確認（30-60秒待機後）
2. エラー発生時の原因究明
3. 自分の修正によるエラー → 即座に修正
4. 既存のエラー → Issue作成

**参照ルール:**

- **`.cursor/rules/03-git-workflow.md`** - CI確認・エラー対応

### 🤖 Gemini Code Assistレビュー対応

**🚨 CRITICAL: レビュー対応の絶対ルール**

- [ ] すべての指摘に必ず対応する（見落とし禁止）
- [ ] 1つの指摘に対して、1 commitで対応する
- [ ] すべての指摘対応完了後、PRコメントで返信する
- [ ] 関連するIssueにもコメントする（必須）

**参照ルール:**

- **`.cursor/rules/03-git-workflow.md`** - Geminiレビュー対応の詳細手順

---

## 5️⃣ マージ・完了報告フェーズ

### ✅ マージ時の自動処理

**🚨 CRITICAL: Issueを Doneに変更するタイミング**

- ✅ **PRがmainにマージされた後のみ** Issueを Doneに変更
- ❌ **PR作成時やマージ前にDoneに変更することは絶対禁止**
- ✅ PRマージまではIn Progressのまま維持

**PRマージ時に実行:**

- [ ] PRをmainにマージ
- [ ] マージ確認後、IssueのステータスをDoneに更新
- [ ] Issueをクローズ

**参照ルール:**

- **`.cursor/rules/04-github-integration.md`** - ステータス更新

### 📊 Issue完了報告

**🚨 CRITICAL: commit完了後は必ずIssue報告**

**タイミング:**

- commit完了後（push前でも可）
- 長時間作業（4時間超）の場合は途中報告

**報告内容:**

- 実施した作業
- 成果物（ファイルリスト）
- 達成した目標（受入基準）
- 次のステップ（レビュー依頼等）
- 作業時間
- 関連リンク（PR、ブランチ、コミット）

**実行方法:**

```bash
gh issue comment <ISSUE_NUMBER> --body "<報告内容>"
```

**参照ルール:**

- **`.cursor/rules/04-github-integration.md`** - Issue報告
- **`.cursor/rules/templates/issue-report.md`** - 報告テンプレート

---

## 🔄 フェーズ間の状態遷移

### GitHub Projectsステータス

```
📝 To Do → 🚧 In Progress → ✅ Done
```

**遷移タイミング:**

- **To Do → In Progress**: タスク開始時（`@start-task`実行時、フィーチャーブランチ作成後）
- **In Progress → Done**: **PRがmainにマージされた後のみ**

**🚨 CRITICAL: 絶対禁止事項**

- ❌ **PR作成時にDoneに変更することは絶対禁止**
- ❌ **PRマージ前にDoneに変更することは絶対禁止**
- ✅ **PRマージ後のみDoneに変更可能**

**参照ルール:**

- **`.cursor/rules/04-github-integration.md`** - ステータス管理

---

## 📚 ルールファイル一覧

### 基本ルール

1. **`00-WORKFLOW-CHECKLIST.md`** ⭐ このファイル（全体フロー）
2. **`01-project.md`** - プロジェクト概要・技術スタック・アーキテクチャ
3. **`02-code-standards.md`** - コード品質・型安全性・テスト
4. **`03-git-workflow.md`** - ブランチ・コミット・PR
5. **`04-github-integration.md`** - Issue管理・ステータス・報告
6. **`05-ci-cd.md`** - CI/CD設定

### テンプレート

- **`templates/issue-report.md`** - Issue報告テンプレート
- **`templates/pr-description.md`** - PR説明テンプレート

---

## 🚨 最優先事項サマリー

### 絶対に守るべきルール

1. **型安全性**: any型の使用禁止
2. **🔴 mainブランチでの直接作業禁止**: 必ずフィーチャーブランチを作成
3. **🔴 PRなしでのmainへのマージ禁止**: すべての変更はPR経由
4. **🔴 PRマージ前にIssueをDoneに変更することは絶対禁止**
5. **⭐ FEATUREチケットでは実装前に詳細設計書を作成**: 必須セクションは必ず作成
6. **自動コミット**: 作業完了時は即座にコミット（質問・確認不要）
7. **push前チェック**: lint/test/e2eを必ず実行
8. **@start-task**: 質問せず即座に最優先タスクを開始
9. **Geminiレビュー対応**: すべての指摘に個別commit/pushで対応
10. **Issue報告**: commit完了後は必ずGitHub Issueに報告

### push前の必須チェック

```bash
./scripts/backend/lint.sh  # コンテナ使用
./scripts/backend/build.sh  # ビルドチェック・コンテナ使用 ⭐
./scripts/backend/test.sh unit  # ユニットテスト・コンテナ使用
./scripts/backend/test.sh e2e  # E2Eテスト・コンテナ使用
```

**詳細**: `.cursor/rules/03-git-workflow.md` 参照

---

## ⚡ クイックリファレンス

### よく使うコマンド

```bash
# タスク開始
@start-task

# ビルド確認
./scripts/build/build.sh

# Lintチェック（コンテナ使用）
./scripts/backend/lint.sh

# ビルド確認（コンテナ使用）
./scripts/backend/build.sh

# ユニットテスト（コンテナ使用）
./scripts/backend/test.sh unit

# E2Eテスト（コンテナ使用）
./scripts/backend/test.sh e2e

# Issue報告
gh issue comment <ISSUE_NUMBER> --body "<報告内容>"

# ステータス更新
./scripts/github/projects/set-issue-in-progress.sh <ISSUE_NUMBER>
./scripts/github/projects/set-issue-done.sh <ISSUE_NUMBER>
```

---

**このワークフローを常に参照し、各フェーズで適切なルールファイルを確認してください。**
