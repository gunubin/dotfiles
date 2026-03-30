#!/usr/bin/env bash
# Claude Code セッションをfzfで選択してresumeする
# Usage: claude-resume.sh <pane_id>

set -euo pipefail

CALLER_PANE="${1:?pane_id required}"
CLAUDE_PROJECTS="$HOME/.claude/projects"

# 呼び出し元paneのカレントディレクトリを取得
CWD=$(tmux display-message -t "$CALLER_PANE" -p '#{pane_current_path}')
[ -z "$CWD" ] && exit 1

# cwdをClaude Codeのプロジェクトディレクトリ名にエンコード
PROJECT_DIR="$CLAUDE_PROJECTS/$(echo "$CWD" | sed 's|/|-|g')"
[ -d "$PROJECT_DIR" ] || { tmux display-message "No Claude sessions for this directory"; exit 0; }

# プレビュー用スクリプト（fzfの--previewから呼ばれる）
preview_session() {
    local jsonl="$1"
    [ -f "$jsonl" ] || return

    # メタデータ表示
    head -5 "$jsonl" | jq -r '
        select(.type == "user") |
        "\u001b[36mSlug:\u001b[0m    " + (.slug // "unnamed") +
        "\n\u001b[36mBranch:\u001b[0m  " + (.gitBranch // "?") +
        "\n\u001b[36mCWD:\u001b[0m     " + .cwd +
        "\n\u001b[36mVersion:\u001b[0m " + (.version // "?") +
        "\n"
    ' 2>/dev/null | head -5

    echo -e "\u001b[33m━━━ Recent conversation ━━━\u001b[0m"
    echo ""

    # 末尾200行からuser/assistantメッセージを抽出（新しい順）
    tail -200 "$jsonl" | jq -rs '
        [.[] | select(.type == "user" or .type == "assistant")] | reverse[] |
        (.timestamp | split("T") | .[0] as $d | .[1] | split(".")[0] | "\($d) \(.[0:5])") as $ts |
        if .type == "user" then
            "\u001b[42;30m USER \u001b[0m \u001b[90m" + $ts + "\u001b[0m\n" +
            (.message.content |
                if type == "string" then .[:500]
                elif type == "array" then
                    [.[] | select(type == "object") |
                        if .type == "text" then .text
                        elif .type == "tool_result" then
                            (.content |
                                if type == "array" then [.[] | select(.type == "text") | .text] | join("")
                                elif type == "string" then .
                                else "" end)
                        else "" end
                    ] | join("") | .[:500]
                else "" end) + "\n"
        elif .type == "assistant" then
            "\u001b[48;5;208;30m CLAUDE \u001b[0m \u001b[90m" + $ts + "\u001b[0m\n" +
            (.message.content |
                if type == "string" then .[:500]
                elif type == "array" then
                    [.[] | select(type == "object" and .type == "text") | .text] | join("") | .[:500]
                else "" end) + "\n"
        else empty end
    ' 2>/dev/null | head -80
}

# --preview から呼ばれた場合
if [ "${2:-}" = "--preview" ]; then
    SESSION_ID="$3"
    preview_session "$PROJECT_DIR/$SESSION_ID.jsonl"
    exit 0
fi

# セッション一覧を生成（タイムスタンプ降順）
list_sessions() {
    for f in "$PROJECT_DIR"/*.jsonl; do
        [ -f "$f" ] || continue
        local basename
        basename=$(basename "$f" .jsonl)
        head -5 "$f" | jq -r --arg id "$basename" '
            select(.type == "user") |
            .timestamp + "\t" + $id + "\t" + (.slug // "unnamed") + "\t" +
            (.message.content |
                if type == "string" then .[:80] | gsub("\n"; " ")
                elif type == "array" then
                    [.[] | select(type == "object" and .type == "text") | .text] | join("") | .[:80] | gsub("\n"; " ")
                else "" end)
        ' 2>/dev/null | head -1
    done | sort -rk1,1
}

SESSIONS=$(list_sessions)
[ -z "$SESSIONS" ] && { tmux display-message "No Claude sessions found"; exit 0; }

# タイムスタンプを読みやすい形式に変換し、表示用リストを作成
DISPLAY_LIST=$(echo "$SESSIONS" | while IFS=$'\t' read -r ts id slug msg; do
    # ISO 8601 → 表示用フォーマット
    if command -v gdate &>/dev/null; then
        display_ts=$(gdate -d "$ts" '+%m/%d %H:%M' 2>/dev/null || echo "${ts:5:11}")
    elif date -d "$ts" '+%m/%d %H:%M' &>/dev/null 2>&1; then
        display_ts=$(date -d "$ts" '+%m/%d %H:%M')
    else
        # macOS date fallback
        display_ts="${ts:5:11}"
    fi
    printf "\033[36m%s\033[0m\t%s\t\033[33m%s\033[0m\t%s\n" "$display_ts" "$id" "$slug" "$msg"
done)

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

SELECTED=$(echo "$DISPLAY_LIST" | fzf-tmux -p 85%,85% \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=1,3,4 \
    --nth=2,3 \
    --header="Enter: resume / Esc: cancel" \
    --preview="bash \"$SCRIPT_PATH\" \"$CALLER_PANE\" --preview {2}" \
    --preview-window=right:55%:wrap \
    --no-sort \
    --border=rounded \
    --border-label=" Claude Sessions " \
    --border-label-pos=2 \
) || exit 0

SESSION_ID=$(echo "$SELECTED" | cut -d$'\t' -f2)
[ -z "$SESSION_ID" ] && exit 0

tmux send-keys -t "$CALLER_PANE" "claude --resume $SESSION_ID" Enter
