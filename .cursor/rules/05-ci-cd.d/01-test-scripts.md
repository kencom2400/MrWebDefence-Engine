# テスト実行スクリプトの設計原則

## 基本原則

- **CI/CD設定は常にローカル環境でも再現可能であること**
- **環境変数の管理は明示的かつ安全であること**
- **テスト実行スクリプトは堅牢で、エラーハンドリングが適切であること**
- **ポート競合やリソース競合を避ける設計であること**
- **YAMLの重複は可能な限りアンカー機能で削減すること**
- **ドキュメントと実装の整合性を常に保つこと**

## テスト実行スクリプトの設計原則

### サーバー起動待機処理

**❌ 悪い例（固定sleep）:**

```bash
# 固定の待機時間は不確実
pnpm dev &
sleep 5  # サーバーが起動していない可能性がある
```

**✅ 良い例（ヘルスチェックベース）:**

```bash
# ヘルスチェックでサーバーの起動を確認
pnpm dev > /tmp/server.log 2>&1 &
SERVER_PID=$!

BACKEND_URL="http://localhost:3001"
MAX_RETRIES=30
RETRY_COUNT=0

# curlコマンドの存在確認
if ! command -v curl > /dev/null 2>&1; then
  echo "⚠ curlコマンドが見つかりません。固定待機時間を使用します。"
  sleep 5
else
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -f "$BACKEND_URL" > /dev/null 2>&1; then
      echo "✅ サーバーが起動しました"
      break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
      echo "  待機中... (${RETRY_COUNT}/${MAX_RETRIES})"
    fi
    sleep 1
  done

  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ サーバーの起動に失敗しました（タイムアウト）"
    echo "ログを確認: tail -20 /tmp/server.log"
    tail -20 /tmp/server.log 2>/dev/null || echo "ログファイルが見つかりません"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
  fi
fi
```

### エラーハンドリングとログ出力

**必須事項:**

1. **ログファイルへの出力**: サーバーの起動ログをファイルに出力し、エラー時に確認できるようにする
2. **プロセスの適切な終了**: テスト終了時にバックグラウンドプロセスを確実に終了する
3. **終了コードの伝播**: テストの終了コードを適切に伝播する

```bash
# ログファイルに出力
pnpm dev > /tmp/server.log 2>&1 &
SERVER_PID=$!

# テスト実行
pnpm test:e2e
TEST_EXIT_CODE=$?

# プロセスを終了
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# 終了コードを伝播
exit $TEST_EXIT_CODE
```
