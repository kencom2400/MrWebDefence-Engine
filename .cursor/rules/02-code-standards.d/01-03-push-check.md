## 10. push前の必須チェック

**優先度レベル**: `01-XX` - **必須（MUST）** - 絶対に守るべきルール

```

╔═══════════════════════════════════════════════════════════════╗
║ 🚨 CRITICAL RULE - PUSH前の4ステップチェック 🚨 ║
║ ║
║ 詳細は `.cursor/rules/03-git-workflow.d/03-push-check.md` を参照 ║
╚═══════════════════════════════════════════════════════════════╝

```

**必須4ステップ**:

```bash
1. ./scripts/test/lint.sh         # 構文・スタイル
2. pnpm build                      # ビルド確認 ⭐ 重要
3. ./scripts/test/test.sh all     # ユニットテスト
4. ./scripts/test/test-e2e.sh frontend # E2Eテスト
```

**実行時間**: 約4-6分

**なぜ重要か**:

- ビルドエラーはすべてのCI jobをブロックする
- ローカルでの早期発見により時間節約（実例: Issue #22で20分の損失を防げた）

**詳細**: `.cursor/rules/03-git-workflow.d/03-push-check.md` 参照

---
