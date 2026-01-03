# PlaywrightのwebServer設定

## 基本原則

- **CI/CD設定は常にローカル環境でも再現可能であること**
- **環境変数の管理は明示的かつ安全であること**
- **テスト実行スクリプトは堅牢で、エラーハンドリングが適切であること**
- **ポート競合やリソース競合を避ける設計であること**
- **YAMLの重複は可能な限りアンカー機能で削減すること**
- **ドキュメントと実装の整合性を常に保つこと**

## PlaywrightのwebServer設定

### 複数サーバーの起動

**設定例:**

```typescript
webServer: [
  // バックエンドサーバー
  {
    command: 'pnpm --filter @account-book/backend dev',
    url: 'http://localhost:3001/api/health/institutions',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
    stdout: 'pipe',
    stderr: 'pipe',
    cwd: process.cwd(),
    env: {
      ENCRYPTION_KEY: process.env.ENCRYPTION_KEY || 'default-key',
      CRYPTO_SALT: process.env.CRYPTO_SALT || 'default-salt',
      NODE_ENV: process.env.NODE_ENV || 'development',
      PORT: process.env.BACKEND_PORT || '3001',
    },
  },
  // フロントエンドサーバー
  {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
    stdout: 'pipe',
    stderr: 'pipe',
    cwd: process.cwd(),
    env: {
      PORT: process.env.FRONTEND_PORT || '3000',
    },
  },
];
```

### 重要な設定項目

1. **`reuseExistingServer`**: CI環境では`false`、ローカル環境では`true`に設定
2. **`timeout`**: サーバー起動のタイムアウト（120秒以上推奨）
3. **`stdout`/`stderr`**: `'pipe'`に設定してログを取得可能にする
4. **`cwd`**: 作業ディレクトリを明示的に指定
5. **`env`**: 必要な環境変数を明示的に設定
