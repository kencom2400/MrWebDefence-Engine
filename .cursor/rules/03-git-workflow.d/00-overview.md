# Git ワークフロー - ブランチ・コミット・PR管理

このファイルは、ブランチ管理、コミット、Pull Requestの運用ルールを統合したものです。

---

## 🚨 絶対禁止事項（CRITICAL）

```
╔════════════════════════════════════════════════════════════╗
║  🔴 CRITICAL RULES - MUST NEVER VIOLATE 🔴                ║
║                                                            ║
║  これらの行為は**絶対に禁止**です。                        ║
║  違反すると重大な問題を引き起こします。                    ║
╚════════════════════════════════════════════════════════════╝
```

### ❌ mainブランチでの直接作業

**禁止事項:**

- mainブランチで直接コードを編集
- mainブランチに直接コミット
- mainブランチに直接push

**正しい手順:**

1. フィーチャーブランチを作成: `git checkout -b feat/XXX-description`
2. フィーチャーブランチで作業
3. フィーチャーブランチにコミット・push
4. PRを作成してレビュー
5. 承認後にmainにマージ

**確認方法:**

```bash
# 現在のブランチを確認
git branch

# mainブランチにいる場合は即座にフィーチャーブランチを作成
git checkout -b feat/XXX-description
```

---

### ❌ PRなしでのmainへのマージ

**禁止事項:**

- PRを作成せずにmainブランチにマージ
- `git merge`を使ってローカルでmainにマージ
- mainブランチに直接push

**正しい手順:**

1. フィーチャーブランチにpush
2. GitHub UIまたは`gh pr create`でPRを作成
3. レビュー・承認を待つ
4. GitHub UIで「Merge pull request」ボタンを押す
5. ローカルでmainブランチを更新: `git checkout main && git pull`

---

### ❌ PRマージ前にIssueをDoneに変更

**禁止事項:**

- PR作成時にIssueをDoneに変更
- PRレビュー中にIssueをDoneに変更
- PRマージ前にIssueをDoneに変更

**正しいタイミング:**

- ✅ **PRがmainにマージされた後のみ** IssueをDoneに変更

**実行コマンド:**

```bash
# PRマージ後のみ実行
./scripts/github/projects/set-issue-done.sh <ISSUE_NUMBER>
```

---

## 🔴 重要: ターミナルコマンド実行時の権限設定

**Git操作を含むターミナルコマンドは、必ず`required_permissions: ['all']`を指定してください。**

### 対象コマンド

以下のコマンドは**すべて`all`権限が必要**：

1. **Git操作**: `git commit`, `git push`, `git checkout`, `git branch`, `git add`, `git status`
2. **GitHub CLI**: `gh issue view`, `gh pr create`, `gh api graphql`
3. **プロジェクトスクリプト**: `./scripts/github/workflow/start-task.sh`

### 理由

- **pre-commitフック**: ESLint/Prettierが実行され、`node_modules`へのアクセスが必要
- **証明書検証**: HTTPSでのGitHub接続に必要
- **環境変数**: GitHubトークンなど機密情報へのアクセス

### 実装例

```typescript
// ✅ 正しい
run_terminal_cmd({
  command: 'git commit -m "feat: 新機能実装"',
  required_permissions: ['all'],
});

// ✅ 正しい
run_terminal_cmd({
  command: './scripts/github/workflow/start-task.sh',
  required_permissions: ['all'],
});

// ❌ エラーになる
run_terminal_cmd({
  command: 'git commit -m "feat: 新機能実装"',
  required_permissions: ['git_write'], // pre-commitフックがエラー
});

// ❌ エラーになる
run_terminal_cmd({
  command: 'gh issue view 248',
  required_permissions: ['network'], // 証明書検証エラー
});
```

**Issue #248の経験: サンドボックス環境では常にエラーが発生するため、最初から`all`権限で実行すること。**

---

## 📋 目次

1. [ブランチ管理](#1-ブランチ管理)
2. [コミットルール](#2-コミットルール)
3. [Push前チェック](#3-push前チェック)
4. [PR作成・レビュー](#4-pr作成レビュー)

---

## 1. ブランチ管理

### 基本原則

- **Issue開始前に必ず適切なブランチを切ること**
- **ブランチ作成後、すぐにGitHub ProjectsのステータスをIn Progressに変更すること**
- ブランチ名は機能や修正内容を明確に表現する
- mainブランチへの直接コミットは禁止

### ブランチ命名規則

#### 機能追加（feature）

```
feature/issue-<番号>-<簡潔な説明>
```

例: `feature/issue-24-yearly-graph`

#### バグ修正（fix）

```
fix/issue-<番号>-<簡潔な説明>
```

例: `fix/issue-12-balance-calculation`

#### リファクタリング（refactor）

```
refactor/issue-<番号>-<簡潔な説明>
```

例: `refactor/issue-8-onion-architecture`

#### ドキュメント更新（docs）

```
docs/issue-<番号>-<簡潔な説明>
```

例: `docs/issue-5-api-documentation`

### ブランチ作成フロー

#### 1. Issue開始時

```bash
# 最新のmainブランチを取得
git checkout main
git pull origin main

# 新しいブランチを作成
git checkout -b feature/issue-<番号>-<説明>

# GitHub ProjectsでステータスをIn Progressに変更
./scripts/github/projects/set-issue-in-progress.sh <番号>
```

**重要**: ブランチを切った直後、作業開始前に必ずGitHub ProjectsのステータスをIn Progressに更新すること

#### 2. 作業中

```bash
# 定期的にコミット
git add .
git commit -m "適切なコミットメッセージ"

# リモートにプッシュ
git push origin feature/issue-<番号>-<説明>
```

#### 3. 作業完了時

```bash
# 最新のmainを取り込む
git fetch origin
git rebase origin/main

# Pull Requestを作成
# GitHub UIまたはgh cliを使用
```

---

## 2. コミットルール

```
╔════════════════════════════════════════════════════════════╗
║  🚨 CRITICAL RULE - HIGHEST PRIORITY - MUST EXECUTE 🚨   ║
║                                                            ║
║  作業を完了したら、自動的に即座にコミットを実行する        ║
║  ユーザーの許可や確認を待たない                            ║
║  「後でコミット」は禁止                                     ║
╚════════════════════════════════════════════════════════════╝
```

### 🔴 重要: Git commit実行時の権限設定

**pre-commitフックによるLint/Format実行のため、必ず`required_permissions: ['all']`を指定してください。**

```typescript
// ✅ 正しい実行方法
run_terminal_cmd({
  command: 'git commit -m "feat: 新機能実装"',
  required_permissions: ['all'],
});

// ❌ サンドボックスではpre-commitフックがエラーになる
run_terminal_cmd({
  command: 'git commit -m "feat: 新機能実装"',
  required_permissions: ['git_write'], // これではpre-commitフックがエラーになる
});
```

**理由:**

- pre-commitフックがESLint/Prettierを実行
- サンドボックス環境では`node_modules`へのアクセスに制限
- `EPERM: operation not permitted`エラーが発生

**Git操作（commit、push、checkout等）は常に`all`権限を使用すること。**

### 🚨 AIアシスタントへの絶対遵守ルール

#### あなたがコミットを実行しなければならない条件

**以下のいずれかに該当する場合、必ず即座にコミットを実行：**

1. ✅ **機能実装が完了した**
2. ✅ **バグ修正が完了した**
3. ✅ **テストを追加/修正した**
4. ✅ **リファクタリングが完了した**
5. ✅ **ドキュメントを更新した**
6. ✅ **設定ファイルを変更した**
7. ✅ **作業の区切りがついた**

**重要: ユーザーに「コミットしますか？」と聞いてはいけない。自動的に実行する。**

#### あなたがコミットをスキップできる条件

**以下の場合のみコミットをスキップ可能：**

1. ❌ ユーザーが「コミットしないで」「commitはスキップ」と**明示的に指示**した
2. ❌ ユーザーが「実験中」「動作確認中」と**明示的に指示**した
3. ❌ ビルドエラーやテスト失敗で、まだ作業が完了していない

### コミットメッセージテンプレート

#### 基本フォーマット

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type（必須）

| Type       | 説明                                       | 使用例                                           |
| ---------- | ------------------------------------------ | ------------------------------------------------ |
| `feat`     | 新機能の追加                               | `feat(transaction): 取引履歴取得APIを実装`       |
| `fix`      | バグ修正                                   | `fix(balance): 残高計算のロジックを修正`         |
| `refactor` | リファクタリング                           | `refactor(repository): リポジトリパターンに変更` |
| `docs`     | ドキュメント変更                           | `docs(readme): セットアップ手順を追加`           |
| `style`    | コードスタイル修正（空白、フォーマット等） | `style(api): lintエラーを修正`                   |
| `test`     | テストの追加・修正                         | `test(usecase): ユースケースのテストを追加`      |
| `chore`    | ビルド・設定ファイルの変更                 | `chore(deps): 依存関係を更新`                    |
| `perf`     | パフォーマンス改善                         | `perf(query): クエリ処理を最適化`                |
| `ci`       | CI/CD関連の変更                            | `ci(github): GitHub Actionsを設定`               |

#### Scope（オプション）

**アーキテクチャレイヤ：**

- `domain`, `application`, `infrastructure`, `presentation`

**機能モジュール：**

- `transaction`, `account`, `category`, `balance`, `report`, `auth`, `api`, `ui`

#### Subject（必須）

- 変更内容を簡潔に説明（50文字以内推奨）
- 日本語または英語で記述
- 命令形で記述
- 文末にピリオドを付けない

### コミットのタイミング

#### 推奨タイミング

1. ✅ 新機能の実装が完了した時
2. ✅ バグ修正が完了した時
3. ✅ リファクタリングが完了した時
4. ✅ テストが追加・修正された時
5. ✅ ドキュメントが更新された時
6. ✅ 設定ファイルが変更された時
7. ✅ チャットでの一つの作業単位が完了した時

#### コミット前のチェックリスト

- [ ] コードが正しく動作するか確認
- [ ] **ビルドが成功するか確認（必須）**
  ```bash
  ./scripts/build/build.sh
  ```
- [ ] **Lintエラーがないか確認（必須）**
  ```bash
  ./scripts/test/lint.sh
  ```
- [ ] **テストがすべてパスするか確認（必須）**
  ```bash
  ./scripts/test/test.sh all
  ```
- [ ] 不要なコメントやconsole.logを削除
- [ ] 変更内容が一貫性を持っているか確認

### 🚨 必ず守るべきコミットタイミング

**重要**: 以下のタイミングで**必ず即座に**commitを実行すること。最後にまとめてcommitすることは**絶対に禁止**。

#### 1. ドキュメント・設定ファイルの変更後

- `.cursor/rules/`内のファイル変更
- `README.md`、その他ドキュメント更新
- 設定ファイル（`.eslintrc`、`tsconfig.json`等）の変更
- **→ 即座にcommit**

#### 2. Domain層の実装後

- Entityの作成（1つのEntityごと）
- Value Objectの作成
- Repositoryインターフェースの定義
- **→ 各レイヤの実装完了時にcommit**

#### 3. Application層の実装後

- UseCaseの実装（1つのUseCaseごと）
- **→ 実装とテスト完了時にcommit**

#### 4. Infrastructure層の実装後

- Repositoryの実装
- 外部APIクライアントの実装
- **→ 実装完了時にcommit**

#### 5. Presentation層の実装後

- Controllerの実装
- DTOの作成
- **→ 実装完了時にcommit**

### 🔴 絶対禁止事項

**以下の行動は絶対に禁止：**

1. ❌ **「コミットしますか？」とユーザーに確認する**
   - 理由: 自動実行が原則。確認は不要
2. ❌ **「後でコミットします」と言って先送りする**
   - 理由: 必ず即座に実行する
3. ❌ **複数の異なる作業を1つのcommitにまとめる**
   - 理由: 各作業は個別にコミット
4. ❌ **作業完了後、最後にまとめてcommitする**
   - 理由: 作業ごとに小さくコミット

---

## 3. Push前チェック

```
╔═══════════════════════════════════════════════════════════════╗
║  🚨 CRITICAL RULE - PUSH前の4ステップチェック 🚨             ║
║                                                               ║
║  pushする前に必ず以下を順番に実行すること：                   ║
║                                                               ║
║  1. ./scripts/test/lint.sh         （構文・スタイル）         ║
║  2. pnpm build                      （ビルド確認）⭐ NEW     ║
║  3. ./scripts/test/test.sh all     （ユニットテスト）         ║
║  4. ./scripts/test/test-e2e.sh frontend （E2Eテスト）         ║
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
./scripts/test/test-e2e.sh frontend

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

```typescript
test.skip('取引データがない場合はメッセージを表示する', async () => {
  // TODO: このテストは、データがない状態をシミュレートする必要がある
  // 現在は、テストデータが投入されているため、このテストをスキップ
  // 将来的には、テストデータをクリアする機能を実装してから有効化する
  // ...
});
```

**違反した場合の影響**:

- CIが失敗して時間を無駄にする（約5-10分）
- 他の開発者のCI実行をブロックする可能性
- プロジェクトの品質が低下する
- フィードバックループが長くなる

**正しいワークフロー**:

```bash
# 1. すべてのチェックを実行
./scripts/test/lint.sh
pnpm build
./scripts/test/test.sh all
./scripts/test/test-e2e.sh frontend

# 2. すべてPASSしたことを確認
# ✅ Lint: PASS
# ✅ Build: PASS
# ✅ Unit Tests: PASS
# ✅ E2E Tests: PASS

# 3. すべてPASSした場合のみpush
git push origin <ブランチ名>
```

**テストが失敗した場合**:

```bash
# ❌ テストが失敗
./scripts/test/test-e2e.sh frontend
# → 2 failed, 35 passed, 26 skipped

# 🚨 push禁止！失敗したテストを修正する
# （修正作業）
# 例: テストコードの修正、実装の修正、または test.skip() でスキップ

# ✅ 修正後、再度チェック
./scripts/test/test-e2e.sh frontend
# → 0 failed, 37 passed, 26 skipped  ← failedが0であることを確認

# ✅ failedが0になったらpush
git push origin <ブランチ名>
```

**🚨 絶対に守るべき確認事項:**

```bash
# push前の最終確認
./scripts/test/test-e2e.sh frontend | grep -E "(failed|passed|skipped)"

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
# 1. Lintチェック（必須）
./scripts/test/lint.sh

# 2. ビルドチェック（必須・最重要）⭐ NEW
pnpm build
# または
npx turbo build

# 3. ユニットテスト（必須）
./scripts/test/test.sh all

# 4. E2Eテスト（必須）
./scripts/test/test-e2e.sh frontend
```

**実行時間の目安：**

- lint: 約30-60秒
- **build: 約1-2分** ⭐ NEW
- test: 約1-2分
- e2e: 約1-2分
- **合計: 約4-6分**（CI実行とほぼ同等だが、ローカルでの早期発見により時間節約）

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
✅ Lint: PASS
✅ Build: PASS    ← ⭐ 重要！
✅ Unit Tests: PASS
✅ E2E Tests: PASS

→ git push OK
```

**1つでもFAILした場合**:

```bash
✅ Lint: PASS
❌ Build: FAIL    ← ⭐ すべてをブロックする
❌ Unit Tests: SKIP
❌ E2E Tests: SKIP

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
./scripts/test/lint.sh
pnpm build
./scripts/test/test.sh all
./scripts/test/test-e2e.sh frontend

# 2. テスト結果を確認（failedが0であることを確認）
./scripts/test/test-e2e.sh frontend | grep -E "(failed|passed|skipped)"

# 3. 結果の判定
# ✅ failedが表示されていない → push OK
# ❌ failedが1つでもある → push禁止（必ず修正）

# 4. failedがある場合の対応
# - 失敗原因を特定
# - 修正する（推奨）
# - または test.skip() でスキップ（理由を明記）
# - 再度テストを実行してfailedが0であることを確認

# 5. failedが0になったらpush
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

## 4. PR作成・レビュー

### 🤖 PR自動作成ワークフロー

AIアシスタントは以下のワークフローでPRを自動管理します：

#### 🚨 重要: PRは常に通常PRとして作成

**禁止事項:**

- ❌ ドラフトPR（`--draft`フラグ）の作成は禁止
- ❌ 一時的なPRや下書きPRの作成は禁止

**理由:**

- レビューを迅速に開始できる
- PRのステータスが明確になる
- 不要な手順（ドラフト解除）を省略できる

#### 1. 最初のpush時: 通常PRを自動作成

**トリガー:**

- 新しいブランチで最初にpushする時
- ユーザーが「PRを作成して」と明示的に依頼した時

**実行内容:**

```bash
# 通常PRを作成（--draftフラグは使用しない）
gh pr create \
  --title "<type>: <短い説明>" \
  --body "<自動生成された説明>"
```

**PRの本文に含めるべき内容:**

- 変更の概要
- 主な変更点のリスト
- コミット履歴
- 関連するIssue番号（`Closes #XXX`など）

#### 2. 追加のpush時: PR本文を自動更新

**トリガー:**

- 既存のPRがあるブランチにpushする時

**実行内容:**

```bash
# 既存のPR番号を取得
PR_NUMBER=$(gh pr list --head $(git branch --show-current) --json number --jq '.[0].number')

# PR本文を更新
gh pr edit $PR_NUMBER --body "<更新された説明>"
```

### PRサイズガイドライン

**推奨サイズ:**

- **Small**: ~100行以下 - 理想的なサイズ
- **Medium**: 100-300行 - 許容範囲
- **Large**: 300-500行 - 分割を検討
- **Extra Large**: 500行以上 - 必ず分割すべき

### PR作成前のチェックリスト

- [ ] すべての変更がコミット済み
- [ ] **push前のローカルチェックを完了（必須）**
- [ ] テストが通ることを確認
- [ ] Lintエラーがないことを確認
- [ ] コンフリクトが発生していないことを確認
- [ ] 適切なブランチ名が付けられている

### CI確認と対応

#### PR作成後の自動確認

```bash
# PRのCI実行状況を確認（30〜60秒待機してから実行）
sleep 45
gh pr checks <PR番号>
```

#### エラー発生時の原因究明

**1. エラーログの取得**

```bash
# 失敗したCIのログを確認
gh run view <run-id> --log-failed
```

**2. 原因の特定**

- 今回の修正で新しく発生したエラーか？
- 既存のコードベースに元々存在していたエラーか？

#### 対応方針

**A. 自身の修正で発生したエラーの場合**

✅ **即座に解決する**

1. ローカルで同じエラーを再現
2. エラーを修正
3. ローカルで確認
4. コミット & プッシュ
5. 再度CIを確認

**B. 既存のエラーである場合**

✅ **Bugのissueを作成する**

**必ず`create-issue.sh`スクリプトを使用してください:**

```bash
# 1. Issue用のJSONファイルを作成
cat > scripts/github/issues/issue-data/drafts/ci-error-bug.json << EOF
{
  "title": "[BUG] [CI名]で[エラー数]個のエラー/警告が発生",
  "labels": ["bug", "infrastructure", "priority: high"],
  "body": "[詳細な内容]"
}
EOF

# 2. スクリプトでIssue作成（自動的にBacklogに設定される）
./scripts/github/issues/create-issue.sh scripts/github/issues/issue-data/drafts/ci-error-bug.json
```

❌ **禁止**: `gh issue create`を直接使用しないでください。プロジェクトに自動追加されません。

### 🤖 Gemini Code Assistレビュー対応

```
╔══════════════════════════════════════════════════════════════════╗
║  🚨 CRITICAL: Geminiレビュー対応の絶対ルール 🚨                   ║
║                                                                  ║
║  1. すべての指摘に必ず対応する（見落とし禁止）                    ║
║  2. 1つの指摘に対して、必ず1 commitで対応                        ║
║  3. 複数の指摘をまとめて1つのcommitにすることは絶対に禁止         ║
║  4. すべてのcommit完了後、まとめてpushする                        ║
║  5. すべての指摘対応完了後、必ずPRコメントで返信                  ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Step 1: すべての指摘を確認・リスト化（必須）

**重要**: Geminiのインラインコメントを取得する際は、必ずGraphQL APIを使用してください。`gh pr view --comments`やREST APIではインラインコメントの詳細が取得できません。

```bash
# ✅ 正しい方法: GraphQL APIで全コメントを取得
gh api graphql -f query='
query {
  repository(owner: "kencom2400", name: "account-book") {
    pullRequest(number: <PR番号>) {
      reviews(first: 10) {
        nodes {
          author { login }
          body
          comments(first: 20) {
            nodes {
              id
              path
              body
              line
            }
          }
        }
      }
    }
  }
}'
```

**必須**: 指摘の総数を確認し、**すべてに対応する**

#### Step 2: 指摘ごとに個別対応（必須）

**1つの指摘ごとにcommit（pushはまだしない）**：

1. 該当ファイルを修正
2. `git add <修正したファイル>`
3. `git commit -m "docs: Gemini指摘対応 - <具体的な修正内容>"`
4. 次の指摘に進む

**重要**: この段階ではまだpushしない。すべての指摘への対応commitを完了してから、次のステップでまとめてpushする。

#### Step 3: すべての修正をまとめてpush（必須）

すべての指摘に対するcommitが完了したら、まとめてpushする：

```bash
# push前に必ずローカルチェックを実行（必須）
./scripts/test/lint.sh
./scripts/test/test.sh all
./scripts/test/test-e2e.sh frontend

# すべてのcommitをまとめてpush
git push origin <ブランチ名>
```

**理由**:

- コミットの粒度を保ちつつ、CIの無駄な実行を防ぐ
- 1回のpushで複数のcommitが含まれるため、CI実行は1回のみ
- push前にローカルチェックを実行することで、CIエラーを事前に防止

#### Step 4: CI確認（推奨）

push後、CIの状況を確認：

```bash
gh pr checks <PR番号>
```

#### Step 5: PRコメントで対応完了を報告（必須）

**🚨 重要: バッククォートなどの特殊文字を含むコメントは、必ず`comment-pr.sh`スクリプトを使用してください。**

```bash
# ✅ 推奨: comment-pr.shスクリプトを使用（特殊文字を安全に処理）
./scripts/github/pr/comment-pr.sh <PR番号> << 'EOF'
## 🙏 Gemini Code Assistレビューへの対応完了

ご指摘いただいた<N>つの点について、すべて対応しました。

## 📝 修正内容サマリー

| # | 指摘内容 | コミット | ステータス |
|---|---------|----------|-----------|
| 1 | <指摘1> | `<hash1>` | ✅ 完了 |
| 2 | <指摘2> | `<hash2>` | ✅ 完了 |

## ✅ テスト結果

- ✅ ローカルビルド成功
- ✅ Lintエラーなし
- ✅ テスト成功
EOF
```

**代替方法（ファイルから送信）:**

```bash
# コメントをファイルに保存
cat > /tmp/pr-comment.md << 'EOF'
## 🙏 Gemini Code Assistレビューへの対応完了
...
EOF

# ファイルから送信
./scripts/github/pr/comment-pr.sh <PR番号> /tmp/pr-comment.md
```

**❌ 非推奨: 直接`gh pr comment`を使用（特殊文字でエラーになる可能性）**

```bash
# ❌ バッククォートが含まれるとシェルエラーが発生する可能性
gh pr comment <PR番号> --body "コメント内に\`コード\`が含まれるとエラー"
```

**スクリプトの詳細:**

- スクリプト: `scripts/github/pr/comment-pr.sh`
- 機能: バッククォートなどの特殊文字を安全に処理
- 使用方法: `./scripts/github/pr/comment-pr.sh --help` でヘルプを表示

#### Step 6: Issueにもコメント（必須）

PRだけでなく、関連するIssueにもGeminiレビュー対応完了を報告する：

```bash
gh issue comment <Issue番号> --body "## 🤖 Gemini Code Assistレビュー対応完了

PR #<PR番号> に対するGeminiレビューの指摘<N>件について、すべて対応しました。

---

## 📝 修正内容サマリー

| # | 指摘内容 | ファイル | コミット | ステータス |
|---|---------|----------|----------|-----------|
| 1 | <指摘1> | \`<ファイル1>\` | \`<hash1>\` | ✅ 完了 |
| 2 | <指摘2> | \`<ファイル2>\` | \`<hash2>\` | ✅ 完了 |

---

## 🔗 関連リンク

- **PR**: #<PR番号>
- **PRコメント**: <PRコメントURL>

---

再度レビューをお願いします。"
```

**重要**: Issueへのコメントにより、Issue上でもGeminiレビュー対応の履歴が追跡できるようになる。

---

## 🔍 トラブルシューティング

### 誤ってmainブランチで作業してしまった場合

```bash
# ステップ1: 現在の変更をstash
git stash

# ステップ2: フィーチャーブランチを作成
git checkout -b feat/XXX-description

# ステップ3: stashを適用
git stash pop

# ステップ4: コミット・push
git add -A
git commit -m "feat: ..."
git push origin feat/XXX-description
```

---

### 誤ってmainブランチにコミットしてしまった場合

```bash
# ステップ1: コミットを取り消す（まだpushしていない場合）
git reset --soft 'HEAD^'

# ステップ2: フィーチャーブランチを作成
git checkout -b feat/XXX-description

# ステップ3: 再度コミット
git commit -m "feat: ..."

# ステップ4: push
git push origin feat/XXX-description
```

---

### 誤ってmainブランチにpushしてしまった場合

```bash
# ⚠️ 警告: この操作は慎重に行ってください

# ステップ1: mainブランチの現在の状態から、復旧用のブランチを作成
git checkout -b feature/recover-my-work

# ステップ2: mainブランチに切り替えて、コミットを巻き戻す
git checkout main
git reset --hard 'HEAD^'

# ステップ3: force pushでリモートのmainブランチも巻き戻す
git push origin main --force

# ステップ4: 復旧用ブランチに切り替えて作業を続ける
git checkout feature/recover-my-work
# これで、このブランチから安全にPRを作成できます。
```

---

### 誤ってIssueをDoneに変更してしまった場合

```bash
# ステップ1: IssueをIn Progressに戻す
./scripts/github/projects/set-issue-in-progress.sh <ISSUE_NUMBER>

# ステップ2: PR作成・レビュー・マージを進める

# ステップ3: PRマージ後、改めてDoneに変更
./scripts/github/projects/set-issue-done.sh <ISSUE_NUMBER>
```

---

## 📚 参考資料

- `.cursor/rules/00-WORKFLOW-CHECKLIST.md` - ワークフロー全体
- `.cursor/rules/02-code-standards.md` - コード品質・テスト
- `.cursor/rules/04-github-integration.md` - Issue管理
- `.cursor/rules/05-ci-cd.md` - CI/CD設定
