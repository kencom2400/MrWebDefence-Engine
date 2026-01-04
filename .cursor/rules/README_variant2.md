# GitHub統合 - ディレクトリ

## 目的

このディレクトリには、GitHub Projects管理、Issueステータス管理、Issue完了報告の運用ルールが含まれています。

## ファイル一覧と優先順位

1. **`README.md`** - このファイル（ディレクトリの説明）
2. **`01-projects-setup.md`** - GitHub Projects設定
3. **`02-status-management.md`** - Issueステータス管理
4. **`03-issue-reporting.md`** - Issue完了報告
5. **`04-start-task.md`** - @start-task統合

## セクション間の関係性

```
01-projects-setup.md
    ↓
02-status-management.md
    ↓
03-issue-reporting.md
    ↓
04-start-task.md
```

## 重要事項

1. **Issueステータス管理**: `02-status-management.md`に従い、PRマージ後のみDoneに変更
2. **Issue完了報告**: `03-issue-reporting.md`に従い、commit完了後は必ず報告
3. **@start-task**: `04-start-task.md`に従い、タスク開始時に自動実行

## 関連する他のディレクトリ

- **`00-workflow-checklist.d/`** - ワークフロー全体像
- **`03-git-workflow.d/`** - PR作成・レビュー（連携）

## 使用方法

このディレクトリのファイルは、`@inc-all-rules`で自動的に読み込まれます。

個別に参照する場合は、以下のように指定してください：

```markdown
参照: `.cursor/rules/04-github-integration.d/02-status-management.md`
```
