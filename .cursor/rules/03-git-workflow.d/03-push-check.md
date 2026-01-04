## 3. Push前チェック

```
╔═══════════════════════════════════════════════════════════════╗
║  🚨 CRITICAL RULE - PUSH前の必須チェック 🚨                 ║
║                                                               ║
║  pushする前に必ず以下を順番に実行すること：                   ║
║                                                               ║
║  1. poetry run black scripts/ tests/  （コードフォーマット）   ║
║  2. poetry run black --check scripts/ tests/  （フォーマットチェック） ║
║  3. poetry run flake8 scripts/ tests/  （リントチェック）     ║
║  4. poetry run pytest tests/  （テスト実行）                  ║
╚═══════════════════════════════════════════════════════════════╝
```

### 🔴 絶対禁止事項: テスト未実行・失敗テストありでのpush

```
╔═══════════════════════════════════════════════════════════════╗
║  🔴 ABSOLUTE PROHIBITION - テスト失敗時のpush禁止 🔴        ║
║                                                               ║
║  以下の行為は絶対に禁止です：                                 ║
║                                                               ║
║  ❌ ローカルでテストを実行せずにpushする                      ║
║  ❌ テストが失敗している状態でpushする                        ║
║  ❌ 失敗したテストが1つでもある状態でpushする                ║
║  ❌ 「一部のテストが失敗していても、他のテストがPASSしていればOK」 ║
║  ❌ 「見込み」「多分大丈夫」という判断でpushする              ║
║  ❌ CIで確認すればいいという考えでpushする                   ║
║  ❌ 一部のテストだけ実行してpushする                          ║
║  ❌ テストが失敗しているが「後で修正する」とpushする         ║
║  ❌ 「別のテストファイルの失敗だから関係ない」とpushする     ║
║                                                               ║
║  ✅ ローカルですべてのテストがPASSするまでpush禁止            ║
║  ✅ 実際にコマンドを実行して、すべてPASSしたことを確認        ║
║  ✅ 失敗したテストは必ず修正してから再度チェック             ║
║  ✅ テスト結果に「failed」が1つでもある場合はpush禁止        ║
║  ✅ 失敗したテストを修正できない場合は、スキップして理由を明記 ║
╚═══════════════════════════════════════════════════════════════╝
```

**🚨 重要: テスト結果の確認方法**

```bash
# テスト実行後、必ず結果を確認
poetry run pytest tests/ -v

# 結果の確認ポイント:
# ✅ "X passed" のみ → push OK
# ❌ "X failed" が1つでもある → push禁止（必ず修正）
# ⚠️ "X skipped" のみ → push OK（スキップは問題なし）
# ❌ "X failed" と "X passed" が混在 → push禁止（failedを修正）
```

**失敗したテストの対応方法:**

1. **修正する（推奨）**: 失敗原因を特定して修正
2. **スキップする**: 修正できない場合は `test.skip()` を使用し、理由をコメントで明記
3. **削除する**: 不要なテストの場合は削除（ただし、慎重に判断）

**スキップする場合の例:**

```python
@pytest.mark.skip(reason="このテストは、データがない状態をシミュレートする必要がある")
def test_no_transaction_data():
    # TODO: 現在は、テストデータが投入されているため、このテストをスキップ
    # 将来的には、テストデータをクリアする機能を実装してから有効化する
    ...
```

**違反した場合の影響**:

- CIが失敗して時間を無駄にする（約5-10分）
- 他の開発者のCI実行をブロックする可能性
- プロジェクトの品質が低下する
- フィードバックループが長くなる

**正しいワークフロー**:

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

**テストが失敗した場合**:

```bash
# ❌ テストが失敗
poetry run pytest tests/ -v
# → 2 failed, 35 passed, 26 skipped

# 🚨 push禁止！失敗したテストを修正する
# （修正作業）
# 例: テストコードの修正、実装の修正、または pytest.mark.skip でスキップ

# ✅ 修正後、再度チェック
poetry run pytest tests/ -v
# → 0 failed, 37 passed, 26 skipped  ← failedが0であることを確認

# ✅ failedが0になったらpush
git push origin <ブランチ名>
```

**🚨 絶対に守るべき確認事項:**

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

### 🚨 必ず実行すること

**理由**:

- pushするとGitHub ActionsでCIが実行される（約3-5分）
- CI実行には時間とリソースが必要
- ローカルでエラーを事前に検出することで、無駄なCI実行を防止できる
- **特にビルドエラーはすべてのCI jobをブロックするため、最優先で確認**
- フィードバックループが短縮され、開発効率が向上する

### 📋 テスト実行の判断基準

#### ✅ テスト・E2Eテストが**必須**な場合

以下のファイルに変更がある場合は、必ずステップ3・4を実行：

- **ソースコード**: `*.ts`, `*.tsx`, `*.js`, `*.jsx`
- **テストコード**: `*.spec.ts`, `*.test.ts`, `*.e2e-spec.ts`
- **設定ファイル**: `package.json`, `tsconfig.json`, `jest.config.js`, `playwright.config.ts`
- **環境設定**: `.env`, `.env.example`, `docker-compose.yml`
- **スクリプト**: `scripts/**/*.sh`, `scripts/**/*.ts`

#### ⚠️ テスト・E2Eテストが**任意**な場合

以下のファイルのみの変更の場合は、ステップ1・2のみでOK：

- **ドキュメント**: `*.md`, `docs/**/*`
- **Cursorルール**: `.cursor/**/*.md`, `.cursorrules`
- **Gitファイル**: `.gitignore`, `.gitattributes`
- **エディタ設定**: `.vscode/**/*`, `.editorconfig`

**注意**: 上記の場合でも、Lint・ビルドチェック（ステップ1・2）は必須です。

#### 💡 判断のポイント

```bash
# 変更されたファイルを確認
git diff --name-only

# マークダウンのみの変更？
git diff --name-only | grep -v '\.md$' | wc -l
# → 0の場合: テスト不要（ステップ1・2のみ）
# → 1以上の場合: テスト必須（ステップ1・2・3・4）
```

**実行手順：**

```bash
# 1. コードフォーマット（必須）
poetry run black scripts/ tests/

# 2. フォーマットチェック（必須）
poetry run black --check scripts/ tests/

# 3. リントチェック（必須）
poetry run flake8 --max-line-length=100 --extend-ignore=E203,E266,W503,F401,F541,F841 \
  --exclude=.git,__pycache__,.venv,venv,build,dist,.eggs,*.egg scripts/ tests/

# 4. テスト実行（必須）
poetry run pytest tests/
```

**実行時間の目安：**

- black（フォーマット）: 約10-30秒
- black（チェック）: 約10-30秒
- flake8: 約30-60秒
- pytest: 約1-2分
- **合計: 約2-4分**（CI実行とほぼ同等だが、ローカルでの早期発見により時間節約）

### ⭐ ビルドチェックの重要性（Issue #22 / PR #262から学習）

**なぜビルドチェックが追加されたか**:

1. **実例**: レスポンスDTOをclassとして定義 → プロパティ初期化エラー
2. Lintは通過、Unit Testsも通過
3. **ビルドチェックをスキップしてpush**
4. CI Build: ❌ FAIL（TS2564エラー 8箇所）
5. CI Unit Tests: ❌ FAIL（ビルドできないため）
6. CI E2E Tests: ❌ FAIL（ビルドできないため）
7. 合計**3つのCIジョブが失敗**

**時間の損失**:

- CI実行待ち: 約5分
- エラー確認・修正: 約10分
- 再CI実行: 約5分
- **合計**: 約20分

**教訓**:

```
ローカルでビルドを確認していれば1分で発見できた
→ 19分の時間の無駄を防げた
```

**ビルドで検出できるエラー**:

- TypeScript compilation errors
- `strictPropertyInitialization` violations
- Interface/Type compatibility issues
- Missing dependencies
- DTOのclass/interface設計ミス

### 📊 チェックリスト実行結果の判定

**すべてPASSした場合のみpush可能**:

```bash
✅ Black (format): PASS
✅ Black (check): PASS
✅ Flake8: PASS
✅ Pytest: PASS

→ git push OK
```

**1つでもFAILした場合**:

```bash
✅ Black (format): PASS
❌ Black (check): FAIL    ← ⭐ すべてをブロックする
❌ Flake8: SKIP
❌ Pytest: SKIP

→ 修正してから再度チェック
→ pushは絶対禁止
```

### 🚨 AIアシスタントへの絶対遵守ルール

**pushを実行する前に、必ず以下を確認すること**:

1. ✅ **実際にローカルで4ステップすべてを実行した**
2. ✅ **すべてのステップがPASSしたことを目視確認した**
3. ✅ **テスト結果に「failed」が1つもないことを確認した**
4. ✅ **テストが失敗している場合は、修正してから再度チェックした**
5. ✅ **「見込み」「多分大丈夫」という判断をしていない**

**禁止事項**:

- ❌ テストを実行せずにpushする
- ❌ テストが失敗している状態でpushする
- ❌ **失敗したテストが1つでもある状態でpushする**（最重要）
- ❌ 「一部のテストが失敗していても、他のテストがPASSしていればOK」という考え
- ❌ 「別のテストファイルの失敗だから関係ない」という考え
- ❌ 「CIで確認すればいい」という考えでpushする
- ❌ 一部のテストだけ実行してpushする
- ❌ ユーザーに「pushしますか？」と確認する（テストが通っていれば自動実行）

**push前の必須確認フロー**:

```bash
# 1. すべてのチェックを実行
poetry run black scripts/ tests/
poetry run black --check scripts/ tests/
poetry run flake8 --max-line-length=100 --extend-ignore=E203,E266,W503,F401,F541,F841 \
  --exclude=.git,__pycache__,.venv,venv,build,dist,.eggs,*.egg scripts/ tests/
poetry run pytest tests/

# 2. テスト結果を確認（failedが0であることを確認）
poetry run pytest tests/ -v | grep -E "(FAILED|PASSED|ERROR)"

# 3. 結果の判定
# ✅ FAILEDが表示されていない → push OK
# ❌ FAILEDが1つでもある → push禁止（必ず修正）

# 4. failedがある場合の対応
# - 失敗原因を特定
# - 修正する（推奨）
# - または pytest.mark.skip でスキップ（理由を明記）
# - 再度テストを実行してFAILEDが0であることを確認

# 5. すべてPASSしたらpush
git push origin <ブランチ名>
```

**正しい判断フロー**:

```
1. 変更をコミット
   ↓
2. 4ステップチェックを実行
   ↓
3. すべてPASS？
   ├─ YES → push実行
   └─ NO  → 修正 → 2に戻る
```

### 例外: 一部スキップ可能な場合

以下の場合のみ、一部スクリプトをスキップ可能：

- ドキュメントファイル（`*.md`）のみの変更: build/test/e2eはスキップ可、lintは実行推奨
- 設定ファイル（`.cursor/**`）のみの変更: build/test/e2eはスキップ可、lintは実行推奨

**ただし、以下の場合は4ステップすべて実行必須：**

- `eslint.config.*`, `tsconfig.json`, `jest.config.*`, `package.json`, `pnpm-workspace.yaml`

**重要**: エラーがある場合は、修正してからpushすること。

---
