# 環境変数の管理

## 基本原則

- **CI/CD設定は常にローカル環境でも再現可能であること**
- **環境変数の管理は明示的かつ安全であること**
- **テスト実行スクリプトは堅牢で、エラーハンドリングが適切であること**
- **ポート競合やリソース競合を避ける設計であること**
- **YAMLの重複は可能な限りアンカー機能で削減すること**
- **ドキュメントと実装の整合性を常に保つこと**

## 環境変数の管理

### ポート競合の回避

**❌ 悪い例（環境変数の競合）:**

```yaml
# CI設定
env:
  PORT: 3001 # これがNext.jsにも影響してしまう
```

```typescript
// Playwright設定
webServer: {
  command: 'pnpm dev',  // PORT=3001が設定されていると、Next.jsも3001を使おうとする
  url: 'http://localhost:3000',
}
```

**✅ 良い例（明示的なポート指定）:**

```yaml
# CI設定
env:
  BACKEND_PORT: 3001 # バックエンド専用
  FRONTEND_PORT: 3000 # フロントエンド専用
```

```typescript
// Playwright設定
webServer: [
  {
    command: 'pnpm --filter @account-book/backend dev',
    url: 'http://localhost:3001/api/health/institutions',
    env: {
      PORT: process.env.BACKEND_PORT || '3001', // 明示的に指定
    },
  },
  {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    env: {
      PORT: process.env.FRONTEND_PORT || '3000', // 明示的に指定
    },
  },
];
```

### 環境変数の命名規則

- **サーバー固有の環境変数**: `{SERVER}_PORT`, `{SERVER}_HOST`などの形式を使用
- **共通の環境変数**: `NODE_ENV`, `ENCRYPTION_KEY`などは明示的に設定
- **デフォルト値の提供**: 環境変数が設定されていない場合のデフォルト値を提供
