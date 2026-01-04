# ワークフロー全体像

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

## 📚 ルールファイル一覧

### 基本ルール

1. **`00-workflow-checklist.d/`** ⭐ このディレクトリ（全体フロー）
2. **`01-project.d/`** - プロジェクト概要・技術スタック・アーキテクチャ
3. **`02-code-standards.d/`** - コード品質・型安全性・テスト
4. **`03-git-workflow.d/`** - ブランチ・コミット・PR
5. **`04-github-integration.d/`** - Issue管理・ステータス・報告
6. **`05-ci-cd.d/`** - CI/CD設定

### テンプレート

- **`templates/issue-report.md`** - Issue報告テンプレート
- **`templates/pr-description.md`** - PR説明テンプレート

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
./scripts/test/lint.sh
pnpm build  # ⭐ ビルドチェック追加
./scripts/test/test.sh all
./scripts/test/test-e2e.sh frontend
```

**詳細**: `.cursor/rules/03-git-workflow.d/03-push-check.md` 参照

## ⚡ クイックリファレンス

### よく使うコマンド

```bash
# タスク開始
@start-task

# ビルド確認
./scripts/build/build.sh

# Lintチェック
./scripts/test/lint.sh

# テスト実行
./scripts/test/test.sh all

# E2Eテスト
./scripts/test/test-e2e.sh frontend

# Issue報告
gh issue comment <ISSUE_NUMBER> --body "<報告内容>"

# ステータス更新
./scripts/github/projects/set-issue-in-progress.sh <ISSUE_NUMBER>
./scripts/github/projects/set-issue-done.sh <ISSUE_NUMBER>
```

---

**このワークフローを常に参照し、各フェーズで適切なルールファイルを確認してください。**
