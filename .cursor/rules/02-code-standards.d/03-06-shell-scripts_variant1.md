## 11. シェルスクリプトのベストプラクティス（Issue #286から学習）

**優先度レベル**: `03-XX` - **一般（MAY）** - 推奨されるルール

### 11-1. マジックナンバーの管理

#### 原則: 共通設定ファイルで一元管理

複数のスクリプトで使用される定数値は、共通設定ファイルで定義して再利用します。

**❌ 悪い例: マジックナンバーが分散**

```bash
# scripts/script1.sh
gh project item-list 1 --limit 9999  # マジックナンバー

# scripts/script2.sh
gh issue list --limit 9999  # 同じ値が複数箇所に

# scripts/script3.sh
gh pr list --limit 9999  # メンテナンスが煩雑
```

**問題点:**

- 値を変更する際に複数ファイルを修正する必要がある
- 修正漏れのリスクがある
- 設定の意図が不明確

**✅ 良い例: 共通設定ファイルで一元管理**

```bash
# scripts/github/workflow/config.sh
export GH_API_LIMIT=9999  # GitHub API limit設定

# scripts/script1.sh
source "${SCRIPT_DIR}/../workflow/config.sh"
gh project item-list 1 --limit "$GH_API_LIMIT"

# scripts/script2.sh
source "${SCRIPT_DIR}/../workflow/config.sh"
gh issue list --limit "$GH_API_LIMIT"
```

**改善点:**

- 設定変更が1箇所で完結
- 設定の意図がコメントで明確
- デフォルト値の設定も可能

**設定ファイルのベストプラクティス:**

```bash
#!/bin/bash

# GitHub Projects設定ファイル

# リポジトリ情報（環境変数または動的取得）
export REPO_OWNER="${REPO_OWNER:-$(gh repo view --json owner -q .owner.login)}"
export REPO_NAME="${REPO_NAME:-$(gh repo view --json name -q .name)}"

# GitHub API設定
export GH_API_LIMIT=9999  # gh project item-list および gh issue list のlimit値
export MIN_ISSUE_COUNT_FOR_COMPLETION=90  # Issue完了確認の最小閾値

# リトライ処理の設定
export MAX_RETRIES=5  # API反映待機のリトライ最大回数
export RETRY_INTERVAL=3  # リトライ間隔（秒）

# API Rate Limit対策
export API_RATE_LIMIT_WAIT=1  # API rate limit対策の基本待機時間（秒）

# プロジェクト情報
export PROJECT_NUMBER=1
export PROJECT_ID="PVT_kwHOANWYrs4BIOm-"
```

**スクリプトでの使用例:**

```bash
#!/bin/bash

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../workflow/config.sh" ]; then
  source "${SCRIPT_DIR}/../workflow/config.sh"
fi

# デフォルト値の設定（設定ファイルで定義されていない場合）
GH_API_LIMIT="${GH_API_LIMIT:-9999}"
MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_INTERVAL="${RETRY_INTERVAL:-3}"
API_RATE_LIMIT_WAIT="${API_RATE_LIMIT_WAIT:-1}"

# 使用例1: API Limit
gh project item-list "$PROJECT_NUMBER" --limit "$GH_API_LIMIT"

# 使用例2: リトライ処理
for ((i=1; i<=MAX_RETRIES; i++)); do
  ITEM_INFO=$(get_item_info)
  if [ -n "$ITEM_INFO" ]; then
    break
  fi
  if [ "$i" -lt "$MAX_RETRIES" ]; then
    sleep "$RETRY_INTERVAL"
  fi
done

# 使用例3: API Rate Limit対策
sleep "$API_RATE_LIMIT_WAIT"
```

**重要なポイント:**

- **すべての定数値を変数化**: 回数、時間、閾値などハードコードされた値を排除
- **デフォルト値の設定**: `${VAR:-default}` パターンで設定ファイル未定義時のフォールバック
- **意味のある変数名**: 用途が明確な名前を使用
- **コメントで説明**: 各変数の用途を明記

**参考:** Issue #286 / PR #288 - Geminiレビュー指摘より

---

### 11-2. コードの重複排除と関数化

#### 原則: 繰り返し処理は関数に切り出す

同じ処理が複数箇所で繰り返される場合は、関数に切り出してDRYにします。

**❌ 悪い例: コードの重複**

```bash
# 1回目: アイテム情報を取得
ITEM_INFO=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit "$GH_API_LIMIT" | \
  jq --arg num "$ISSUE_NUMBER" '.items[] | select(.content.number == ($num | tonumber)) | {id: .id, title: .title, status: .status}')

if [ -z "$ITEM_INFO" ]; then
  # Issueを追加
  gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$ISSUE_URL"

  # 2回目: 同じ処理を繰り返す
  ITEM_INFO=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit "$GH_API_LIMIT" | \
    jq --arg num "$ISSUE_NUMBER" '.items[] | select(.content.number == ($num | tonumber)) | {id: .id, title: .title, status: .status}')
fi
```

**問題点:**

- 同じコマンドが2回記述されている
- メンテナンス性が低い
- 変更時に複数箇所を修正する必要がある

**✅ 良い例: 関数に切り出す**

```bash
# アイテム情報を取得する関数
get_item_info() {
  gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit "$GH_API_LIMIT" | \
    jq --arg num "$ISSUE_NUMBER" '.items[] | select(.content.number == ($num | tonumber)) | {id: .id, title: .title, status: .status}'
}

# 使用例
ITEM_INFO=$(get_item_info)

if [ -z "$ITEM_INFO" ]; then
  # Issueを追加
  gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$ISSUE_URL"

  # 関数を再利用
  ITEM_INFO=$(get_item_info)
fi
```

**改善点:**

- コードが簡潔になる
- 変更が1箇所で完結
- 可読性が向上

**参考:** Issue #286 / PR #288 - Geminiレビュー指摘より

---

### 11-3. 固定時間待機の回避（リトライ処理）

#### 原則: APIの反映待ちには固定時間ではなくリトライ処理を使用

外部APIの反映を待つ際、固定時間の`sleep`は不安定です。リトライ処理を使用します。

**❌ 悪い例: 固定時間待機**

```bash
# Issueをプロジェクトに追加
gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$ISSUE_URL"

# 固定時間待機
sleep 3

# 再度取得
ITEM_INFO=$(get_item_info)
```

**問題点:**

- APIの反映が3秒以上かかる場合に失敗する
- 無駄な待機時間が発生する可能性
- 環境によって必要な時間が異なる

**✅ 良い例: リトライ処理**

```bash
# Issueをプロジェクトに追加
gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$ISSUE_URL"

echo "✅ Issue #${ISSUE_NUMBER} をプロジェクトに追加しました"
echo "⏳ GitHub APIの反映を待機し、再度アイテム情報を取得します..."

# API反映を待つためリトライ処理を追加
for i in {1..5}; do
  ITEM_INFO=$(get_item_info)
  if [ -n "$ITEM_INFO" ]; then
    break
  fi
  if [ "$i" -lt 5 ]; then
    echo "  リトライ ($i/5)..."
    sleep 3
  fi
done

if [ -z "$ITEM_INFO" ]; then
  echo "❌ エラー: Issueの追加後もアイテム情報を取得できませんでした"
  exit 1
fi
```

**改善点:**

- 最大5回リトライ（最大15秒待機）
- 成功したら即座に次の処理に進む
- 環境の違いやAPIの遅延に対応できる
- 進捗状況をユーザーに通知

**リトライ処理のベストプラクティス:**

```bash
# 設定
MAX_RETRIES=5
RETRY_INTERVAL=3

# リトライループ
for ((i=1; i<=MAX_RETRIES; i++)); do
  RESULT=$(some_command)

  # 成功判定
  if [ -n "$RESULT" ]; then
    echo "✅ 成功"
    break
  fi

  # 最終試行でなければ待機
  if [ "$i" -lt $MAX_RETRIES ]; then
    echo "  リトライ ($i/$MAX_RETRIES)..."
    sleep $RETRY_INTERVAL
  fi
done

# 最終的な成功判定
if [ -z "$RESULT" ]; then
  echo "❌ エラー: $MAX_RETRIES 回のリトライ後も失敗しました"
  exit 1
fi
```

**参考:** Issue #286 / PR #288 - Geminiレビュー指摘より

---

### 11-4. コードの簡素化とDRY原則（PR #368から学習）

#### 原則: 不要な処理を削除し、重複を排除する

シェルスクリプトでは、不要な変数や処理を削除し、コードの重複を排除することで可読性と保守性を向上させます。

#### ❌ 悪い例1: 未使用変数の定義

```bash
# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# この変数は使用されていない
```

**問題点:**

- 不要なコードが可読性を損なう
- メンテナンスの対象が増える
- コードの意図が不明確になる

**✅ 良い例: 未使用変数を削除**

```bash
# 使用されていない変数は定義しない
set -euo pipefail
```

#### ⚠️ 注意: 一時ファイルの使用が必要な場合

**原則: 特殊文字を正しく処理するため、ファイル経由に統一する**

標準入力から直接読み込む方式（`--body-file -`）では、クォーテーションなどの特殊文字が正しく処理されない場合があります。そのため、すべての入力を一時ファイル経由で処理することで、特殊文字の扱いを一貫させます。

**✅ 良い例: 一時ファイル経由で統一**

```bash
# 一時ファイルのパス
TEMP_FILE=""

# クリーンアップ関数
cleanup() {
  if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
    rm -f "$TEMP_FILE"
  fi
}

# 終了時にクリーンアップを実行
trap cleanup EXIT

# 標準入力から読み込む場合も一時ファイルを使用
if [ -z "$COMMENT_FILE_PATH" ]; then
  TEMP_FILE=$(mktemp)
  COMMENT_FILE_PATH="$TEMP_FILE"
  cat > "$TEMP_FILE"
fi

# すべてファイル経由で送信
gh pr comment "$PR_NUMBER" --body-file "$COMMENT_FILE_PATH"
```

**理由:**

- クォーテーションなどの特殊文字を正しく処理できる
- ファイル経由に統一することで、特殊文字の扱いが一貫する
- エラーハンドリングが統一される

**注意点:**

- 一時ファイルのクリーンアップ（`trap`と`cleanup`関数）は必須
- エラーハンドリングを適切に実装する

#### ❌ 悪い例3: コードの重複

```bash
if [ -n "$COMMENT_FILE" ]; then
  # ファイルが指定されている場合
  if [ ! -f "$COMMENT_FILE" ]; then
    echo "❌ エラー: ファイルが見つかりません: $COMMENT_FILE" >&2
    exit 1
  fi

  # ファイルから直接送信
  echo "📝 PR #${PR_NUMBER} にコメントを送信中..." >&2
  gh pr comment "$PR_NUMBER" --body-file "$COMMENT_FILE"
else
  # 標準入力から読み込む
  TEMP_FILE=$(mktemp)
  cat > "$TEMP_FILE"

  # ファイルが空でないことを確認
  if [ ! -s "$TEMP_FILE" ]; then
    echo "❌ エラー: コメント本文が空です" >&2
    exit 1
  fi

  # 一時ファイルから送信
  echo "📝 PR #${PR_NUMBER} にコメントを送信中..." >&2
  gh pr comment "$PR_NUMBER" --body-file "$TEMP_FILE"
fi
```

**問題点:**

- `gh pr comment`の呼び出しが重複
- エラーメッセージの表示が重複
- メンテナンス性が低い

**✅ 良い例: DRY原則に従ったリファクタリング**

```bash
# コメントファイルパスの決定（すべてファイル経由に統一）
COMMENT_FILE_PATH="${2:-}"

if [ -z "$COMMENT_FILE_PATH" ]; then
  # 標準入力から読み込む場合、一時ファイルを使用
  # 理由: クォーテーションなどの特殊文字を正しく処理するため
  TEMP_FILE=$(mktemp)
  COMMENT_FILE_PATH="$TEMP_FILE"
  cat > "$TEMP_FILE"
else
  # ファイルが指定されている場合、存在確認
  if [ ! -f "$COMMENT_FILE_PATH" ]; then
    echo "❌ エラー: ファイルが見つかりません: $COMMENT_FILE_PATH" >&2
    exit 1
  fi
fi

# ファイルが空でないことを確認（共通処理）
if [ ! -s "$COMMENT_FILE_PATH" ]; then
  echo "❌ エラー: コメント本文が空です" >&2
  exit 1
fi

# コメントを送信（共通処理）
echo "📝 PR #${PR_NUMBER} にコメントを送信中..." >&2
gh pr comment "$PR_NUMBER" --body-file "$COMMENT_FILE_PATH"
```

**改善点:**

- `gh pr comment`の呼び出しが1箇所に集約
- コメント本文の空チェックが1箇所に集約
- コードの重複が解消
- メンテナンス性が向上

**重要なポイント:**

1. **未使用変数の削除**: 使用されていない変数は定義しない
2. **一時ファイルの使用**: 特殊文字を正しく処理するため、すべての入力を一時ファイル経由で処理する
3. **DRY原則の遵守**: 同じ処理は1箇所に集約
4. **一時ファイルのクリーンアップ**: `trap`と`cleanup`関数で確実にクリーンアップする

**参考:** PR #368 - Geminiレビュー指摘より

---
