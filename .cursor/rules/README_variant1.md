# CI/CD設定ガイドライン - ディレクトリ

## 目的

このディレクトリには、CI/CD設定のガイドライン（テスト実行スクリプト、環境変数管理、Playwright設定、GitHub Actions設定）が含まれています。

## ファイル一覧と優先順位

1. **`README.md`** - このファイル（ディレクトリの説明）
2. **`01-test-scripts.md`** - テスト実行スクリプト
3. **`02-env-management.md`** - 環境変数の管理
4. **`03-playwright-config.md`** - Playwright設定
5. **`04-github-actions.md`** - GitHub Actions設定

## セクション間の関係性

```
01-test-scripts.md
    ↓
02-env-management.md
    ↓
03-playwright-config.md
    ↓
04-github-actions.md
```

## 基本原則

1. **ローカル環境での再現性**: CI/CD設定は常にローカル環境でも再現可能であること
2. **環境変数の明示的管理**: 環境変数の管理は明示的かつ安全であること
3. **堅牢なエラーハンドリング**: テスト実行スクリプトは堅牢で、エラーハンドリングが適切であること

## 関連する他のディレクトリ

- **`02-code-standards.d/`** - コード品質基準（テスト実装ガイドライン）
- **`03-git-workflow.d/`** - push前チェック（テスト実行）

## 使用方法

このディレクトリのファイルは、`@inc-all-rules`で自動的に読み込まれます。

個別に参照する場合は、以下のように指定してください：

```markdown
参照: `.cursor/rules/05-ci-cd.d/01-test-scripts.md`
```
