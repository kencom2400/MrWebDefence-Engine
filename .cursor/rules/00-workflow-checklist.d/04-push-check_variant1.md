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

**必須4ステップ（すべてPASS必須）:**

```bash
1. poetry run black scripts/ tests/  # コードフォーマット
2. poetry run black --check scripts/ tests/  # フォーマットチェック
3. poetry run flake8 scripts/ tests/  # リントチェック
4. poetry run pytest tests/  # テスト実行
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

**✅ 正しいワークフロー:**

```bash
# 1. すべてのチェックを実行
poetry run black scripts/ tests/
poetry run black --check scripts/ tests/
poetry run flake8 --max-line-length=100 --extend-ignore=E203,E266,W503,F401,F541,F841 \
  --exclude=.git,__pycache__,.venv,venv,build,dist,.eggs,*.egg scripts/ tests/
poetry run pytest tests/

# 2. すべてPASSしたことを確認
# ✅ Black (format): PASS
# ✅ Black (check): PASS
# ✅ Flake8: PASS
# ✅ Pytest: PASS

# 3. すべてPASSした場合のみpush
git push origin <ブランチ名>
```

**テストが失敗した場合:**

```bash
# ❌ テストが失敗
poetry run pytest tests/ -v
# → 2 failed, 35 passed, 26 skipped

# 🚨 push禁止！失敗したテストを必ず修正する
# （修正作業）
# 例: テストコードの修正、実装の修正、または pytest.mark.skip でスキップ

# ✅ 修正後、再度チェック
poetry run pytest tests/ -v
# → 0 failed, 37 passed, 26 skipped  ← failedが0であることを確認

# ✅ failedが0になったらpush
git push origin <ブランチ名>
```

**🚨 テスト結果の確認方法:**

```bash
# push前の最終確認
poetry run pytest tests/ -v | grep -E "(FAILED|PASSED|ERROR|SKIPPED)"

# 出力例（push OK）:
#   37 PASSED
#   26 SKIPPED
#   → FAILEDが表示されていない = push OK

# 出力例（push禁止）:
#   2 FAILED
#   35 PASSED
#   26 SKIPPED
#   → FAILEDが1つでもある = push禁止（必ず修正）
```

**なぜ重要か:**

- フォーマットエラーやリントエラーはCIをブロックする
- ローカルでの早期発見により時間節約
- CI実行の無駄を防ぐ（約5-10分の節約）
- プロジェクトの品質を維持する

**詳細:** `.cursor/rules/03-git-workflow.d/03-push-check.md` 参照
