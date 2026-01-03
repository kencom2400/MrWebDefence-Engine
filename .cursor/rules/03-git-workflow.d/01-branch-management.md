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
