#!/bin/bash

# PRコメント送信スクリプト
# 
# 使い方:
#   comment-pr.sh <PR_NUMBER> [COMMENT_FILE]
#   comment-pr.sh <PR_NUMBER> < <COMMENT_TEXT>
#
# バッククォートなどの特殊文字を含むコメントを安全に送信します。

set -euo pipefail

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

# 使い方表示
show_usage() {
  cat << EOF
使い方: $0 <PR_NUMBER> [COMMENT_FILE]

PRコメントを送信するスクリプトです。バッククォートなどの特殊文字を含む
コメントを安全に送信できます。

引数:
  PR_NUMBER      PR番号（必須）
  COMMENT_FILE   コメント本文のファイルパス（オプション）

使用方法:

  1. ファイルから送信:
     $0 361 /tmp/comment.txt

  2. 標準入力から送信:
     echo "コメント内容" | $0 361

  3. パイプで使用:
     cat comment.md | $0 361

  4. ヒアドキュメントで使用:
     $0 361 << 'EOF'
     コメント内容
     EOF

オプション:
  -h, --help     このヘルプを表示

例:
  # ファイルから送信
  $0 361 /tmp/comment.txt

  # 標準入力から送信
  echo "## レビュー対応完了" | $0 361

  # 複数行のコメントを送信
  $0 361 << 'EOF'
  ## 🙏 Gemini Code Assistレビューへの対応完了

  ご指摘いただいた2つの点について、すべて対応しました。

  ## 📝 修正内容サマリー

  | # | 指摘内容 | コミット | ステータス |
  |---|---------|----------|-----------|
  | 1 | 型安全性の改善 | \`abc123\` | ✅ 完了 |
  | 2 | ドキュメント更新 | \`def456\` | ✅ 完了 |
  EOF

注意:
  - PR番号は数値である必要があります
  - コメントファイルが指定されない場合、標準入力から読み込みます
  - バッククォート（\`）などの特殊文字も安全に処理されます
EOF
}

# ヘルプオプション
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_usage
  exit 0
fi

# PR番号の取得とバリデーション
PR_NUMBER="$1"

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "❌ エラー: 無効なPR番号です: $PR_NUMBER" >&2
  echo "   PR番号は数値である必要があります" >&2
  exit 1
fi

# PRの存在確認
if ! gh pr view "$PR_NUMBER" > /dev/null 2>&1; then
  echo "❌ エラー: PR #${PR_NUMBER} が見つかりません" >&2
  exit 1
fi

# コメント本文の準備
COMMENT_FILE_PATH="${2:-}"

# コメントファイルパスの決定（すべてファイル経由に統一）
if [ -z "$COMMENT_FILE_PATH" ]; then
  # 標準入力から読み込む場合、一時ファイルを使用
  # 理由: クォーテーションなどの特殊文字を正しく処理するため
  TEMP_FILE=$(mktemp)
  COMMENT_FILE_PATH="$TEMP_FILE"
  
  # 標準入力から読み込んで一時ファイルに保存
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

# コメントを送信（すべてファイル経由）
echo "📝 PR #${PR_NUMBER} にコメントを送信中..." >&2
gh pr comment "$PR_NUMBER" --body-file "$COMMENT_FILE_PATH"

echo "✅ PR #${PR_NUMBER} にコメントを送信しました" >&2

