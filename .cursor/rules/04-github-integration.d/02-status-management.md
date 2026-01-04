# Issueステータス管理

## 2. Issueステータス管理

### 基本方針

**AIアシスタントは、ユーザーとの会話の文脈を理解し、適切なタイミングでIssue/PRのステータスを更新します。**

- ✅ 自然な対話フローの中で状態を確認
- ✅ 文脈に応じた適切な判断
- ✅ ユーザーの意図を尊重
- ❌ 機械的・自動的な更新は行わない

### トリガー条件

#### 1. PR関連の会話

**マージ完了時:**

```
ユーザー: "PRをマージしました"
ユーザー: "マージ完了"
ユーザー: "#217をマージした"
```

**アクション（必須）:**

1. PRの状態を確認（`gh pr view <PR番号> --json state,mergedAt`）
2. マージされている場合（`state: "MERGED"`）、関連Issueを特定
   - PR本文から「Closes #XXX」「Fixes #XXX」「Resolves #XXX」を抽出
   - 会話の文脈から関連Issueを特定
3. **プロジェクトステータスを「✅ Done」に更新（必須）**
   ```bash
   ./scripts/github/projects/set-issue-done.sh <issue番号>
   ```
4. **Issueをクローズ（必須）**
   ```bash
   gh issue close <issue番号>
   ```

**🚨 CRITICAL: マージ完了後は必ず上記の手順を実行すること**

**重要**: ユーザーが「マージします」と言った場合、マージ実行後に自動的にステータスを更新する

#### 2. 作業完了の報告

```
ユーザー: "実装完了"
ユーザー: "タスク完了"
ユーザー: "#219の作業が終わりました"
```

**アクション:**

1. 作業内容を確認
2. PRが作成されているか確認
3. PRの状態に応じてIssueステータスを更新

#### 3. 明示的な指示

```
ユーザー: "Issueステータスを更新して"
ユーザー: "#219をDoneにして"
```

**アクション:**

1. 指示に従ってステータスを更新
2. 更新結果を報告

### 実行フロー

#### ステップ1: PR状態の確認

```bash
# PRの詳細を取得
gh pr view <PR番号> --json number,title,state,mergedAt,closedAt,body
```

**判定条件:**

- `state: "MERGED"` かつ `mergedAt` が存在 → マージ済み
- `state: "CLOSED"` かつ `mergedAt` が null → クローズのみ
- `state: "OPEN"` → まだオープン

#### ステップ2: 関連Issueの特定

PRの本文から関連Issueを抽出：

```typescript
// 複数のIssueキーワードに対応
const issueKeywords = ['Closes', 'Fixes', 'Resolves', 'closes', 'fixes', 'resolves'];
const issueNumbers: number[] = [];

for (const keyword of issueKeywords) {
  const regex = new RegExp(`${keyword}\\s+#(\\d+)`, 'g');
  let match;
  while ((match = regex.exec(prBody)) !== null) {
    const issueNumber = parseInt(match[1], 10);
    if (!issueNumbers.includes(issueNumber)) {
      issueNumbers.push(issueNumber);
    }
  }
}
```

#### ステップ3: Issueステータスの更新

```bash
# Doneに変更（必須）
./scripts/github/projects/set-issue-done.sh <issue番号>
```

#### ステップ4: Issueをクローズ

```bash
# Issueをクローズ（必須）
gh issue close <issue番号>
```

#### ステップ5: 確認メッセージ

更新結果をユーザーに報告：

```
✅ Issue #209のステータスを「✅ Done」に更新しました
✅ Issue #209をクローズしました
✅ プロジェクト: Account Book Development
```

### 注意事項

#### 1. 確認してから更新

**常にPRの状態を確認してから更新する**:

```bash
# 良い例: 状態確認後に更新
gh pr view 217 --json state
# state が MERGED であることを確認してから
./scripts/github/projects/set-issue-done.sh 209
```

#### 2. ユーザーの意図を尊重

機械的に更新せず、必要に応じて確認

#### 3. エラーハンドリング

スクリプト実行時のエラーを適切に処理

#### 4. 複数Issue対応

1つのPRが複数のIssueに関連する場合：

```
PR本文: "Closes #209, Closes #210"
```

**全ての関連Issueに対して以下を実行（必須）:**
1. プロジェクトステータスを「✅ Done」に更新
2. Issueをクローズ

```bash
# 例: Issue #209と#210の両方に対して実行
./scripts/github/projects/set-issue-done.sh 209
gh issue close 209

./scripts/github/projects/set-issue-done.sh 210
gh issue close 210
```

