#!/bin/bash

# Epicのタスクを一括作成するスクリプト
# 使用方法: ./scripts/jira/create-epic-tasks.sh <epic_num>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 一時ファイルのクリーンアップ関数
cleanup_temp_files() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# スクリプト終了時に一時ファイルをクリーンアップ
trap cleanup_temp_files EXIT INT TERM

if [ $# -lt 1 ]; then
    echo "使用方法: $0 <epic_num>" >&2
    echo "例: $0 2" >&2
    exit 1
fi

EPIC_NUM=$1

# 一時ディレクトリを作成
TEMP_DIR=$(mktemp -d -t "epic-tasks-${EPIC_NUM}-XXXXXX" 2>/dev/null || mktemp -d)
EPIC_KEY="MWD-${EPIC_NUM}"
EPIC_TASK_DESIGN="${REPO_ROOT}/docs/EPIC_TASK_DESIGN.md"

if [ ! -f "$EPIC_TASK_DESIGN" ]; then
    echo "❌ エラー: EPIC_TASK_DESIGN.md が見つかりません" >&2
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Epic ${EPIC_NUM} のタスク作成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Pythonスクリプトでタスク情報を抽出して本文ファイルを作成
python3 << PYTHON_SCRIPT
import re
import sys
import os

epic_num = ${EPIC_NUM}
temp_dir = "${TEMP_DIR}"

# 一時ディレクトリが存在することを確認
if not os.path.exists(temp_dir):
    os.makedirs(temp_dir)

# EPIC_TASK_DESIGN.mdを読み込む
with open('${EPIC_TASK_DESIGN}', 'r', encoding='utf-8') as f:
    content = f.read()

# このEpicのタスクを抽出
task_pattern = rf'##### Task {epic_num}\.(\d+): (.+?)\n\*\*リポジトリ\*\*: (.+?)\n\n\*\*なぜやるか\*\*\n(.+?)\n\n\*\*何をやるか（概要）\*\*\n(.+?)\n\n\*\*受け入れ条件\*\*\n(.+?)(?=\n\n##### Task|\n---|\Z)'
tasks = re.finditer(task_pattern, content, re.DOTALL)

for task in tasks:
    task_num = task.group(1)
    task_title = task.group(2).strip()
    repo = task.group(3).strip()
    why = task.group(4).strip()
    what = task.group(5).strip()
    acceptance = task.group(6).strip()
    
    # 本文ファイルを作成（一時ディレクトリを使用）
    body_file = os.path.join(temp_dir, f"task{epic_num}_{task_num}_body.md")
    with open(body_file, 'w', encoding='utf-8') as f:
        f.write(f"""## なぜやるか

{why}

## 何をやるか（概要）

{what}

## 受け入れ条件

{acceptance}

## リポジトリ

- {repo}
""")
    
    # タイトルを一時ファイルに保存（シェル側で再利用するため）
    title_file = os.path.join(temp_dir, f"task{epic_num}_{task_num}_title.txt")
    with open(title_file, 'w', encoding='utf-8') as f:
        f.write(task_title)
    
    print(f"Task {epic_num}.{task_num}: {task_title}")
    print(f"  本文ファイル: {body_file}")

PYTHON_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Jiraにタスクを作成中..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# タスクを作成
CREATED_TASKS=()

for task_file in "${TEMP_DIR}"/task${EPIC_NUM}_*_body.md; do
    if [ ! -f "$task_file" ]; then
        continue
    fi
    
    # タスク番号を抽出
    task_num=$(basename "$task_file" | sed "s/task${EPIC_NUM}_\(.*\)_body.md/\1/")
    
    # タイトルを取得（Pythonスクリプトで保存したファイルから読み込む）
    title_file="${TEMP_DIR}/task${EPIC_NUM}_${task_num}_title.txt"
    if [ -f "$title_file" ]; then
        title=$(cat "$title_file")
    else
        # フォールバック: ファイルが存在しない場合は従来の方法で取得
        title_line=$(grep -A 1 "##### Task ${EPIC_NUM}.${task_num}:" "$EPIC_TASK_DESIGN" | head -1)
        title=$(echo "$title_line" | sed "s/##### Task [0-9.]*: //")
    fi
    
    echo "作成中: Task ${EPIC_NUM}.${task_num}: ${title}"
    
    # Jiraに作成
    OUTPUT=$(bash "${REPO_ROOT}/scripts/jira/issues/create-issue.sh" \
        --project-key MWD \
        --title "Task ${EPIC_NUM}.${task_num}: ${title}" \
        --issue-type タスク \
        --body-file "$task_file" \
        --status ToDo 2>&1)
    
    CREATE_EXIT_CODE=$?
    
    # Issueキーを抽出
    ISSUE_KEY=$(echo "$OUTPUT" | grep "Issueキー:" | sed 's/.*Issueキー: //' | head -1)
    
    if [ $CREATE_EXIT_CODE -eq 0 ] && [ -n "$ISSUE_KEY" ]; then
        CREATED_TASKS+=("$ISSUE_KEY")
        echo "  ✅ 作成成功: $ISSUE_KEY"
    else
        echo "  ❌ 作成失敗 (終了コード: ${CREATE_EXIT_CODE})"
        echo "$OUTPUT" | grep -E "(エラー|error|Error)" | head -3
        # エラーが発生しても続行（他のタスクの作成を試みる）
    fi
    
    echo ""
    sleep 1
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Epic ${EPIC_NUM} にタスクを紐づけ中..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Epicに紐づけ
LINK_SUCCESS_COUNT=0
LINK_FAIL_COUNT=0

for task_key in "${CREATED_TASKS[@]}"; do
    echo "紐づけ中: ${task_key} → ${EPIC_KEY}"
    if bash "${REPO_ROOT}/scripts/jira/issues/link-task-to-epic.sh" "$task_key" "$EPIC_KEY" >/dev/null 2>&1; then
        echo "  ✅ 紐づけ成功"
        LINK_SUCCESS_COUNT=$((LINK_SUCCESS_COUNT + 1))
    else
        echo "  ❌ 紐づけ失敗"
        LINK_FAIL_COUNT=$((LINK_FAIL_COUNT + 1))
    fi
    sleep 1
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Epic ${EPIC_NUM} のタスク作成完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "作成されたタスク: ${#CREATED_TASKS[@]} 個"
for task_key in "${CREATED_TASKS[@]}"; do
    echo "  - ${task_key}"
done

if [ ${#CREATED_TASKS[@]} -gt 0 ]; then
    echo ""
    echo "紐づけ結果:"
    echo "  ✅ 成功: ${LINK_SUCCESS_COUNT} 個"
    if [ $LINK_FAIL_COUNT -gt 0 ]; then
        echo "  ❌ 失敗: ${LINK_FAIL_COUNT} 個"
        echo ""
        echo "⚠️  一部のタスクの紐づけに失敗しました。"
        echo "   手動で紐づけを行うか、スクリプトを再実行してください。"
    fi
fi

# 一時ファイルのクリーンアップ（明示的に実行）
cleanup_temp_files

