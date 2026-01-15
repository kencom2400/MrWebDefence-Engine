# push前チェックフェーズ

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
2. ./scripts/backend/build.sh        # ビルド確認（コンテナ使用）⭐ 重要
3. ./scripts/backend/test.sh unit    # ユニットテスト（コンテナ使用）
4. ./scripts/backend/test.sh e2e     # E2Eテスト（コンテナ使用）
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
# push前の最終確認（コンテナ使用）
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

**詳細:** `.cursor/rules/03-git-workflow.d/03-push-check.md` 参照
