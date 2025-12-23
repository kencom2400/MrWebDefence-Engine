# タスク開始フェーズ

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

- **`.cursor/rules/04-github-integration.d/02-status-management.md`** - Issue取得・ステータス管理
- **`.cursor/rules/03-git-workflow.d/01-branch-management.md`** - ブランチ作成

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
