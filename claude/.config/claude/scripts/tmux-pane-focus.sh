#!/bin/bash
# tmux-pane-focus.sh - pane切替時にウィンドウ名をフォーカスpaneの状態に更新
# tmux の pane-focus-in hook から呼ばれる

ICON_IDLE="󰭻"
ICON_WORKING="󰑮"
STALE_THRESHOLD=30  # seconds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/tmp/claude-tmux"

PANE_ID=$(tmux display-message -p '#{pane_id}')
WINDOW_ID=$(tmux display-message -p '#{window_id}')
PANE_FILE="$STATE_DIR/pane-${PANE_ID}"
ORIG_FILE="$STATE_DIR/orig-${WINDOW_ID}"
REFS_FILE="$STATE_DIR/refs-${WINDOW_ID}"

# Correct stale working state: if mtime is older than threshold, rewrite to idle
correct_stale_state() {
    [ -f "$PANE_FILE" ] || return
    local content
    content=$(cat "$PANE_FILE")
    case "$content" in
        "${ICON_WORKING}"*)
            local age
            if [ "$(uname)" = "Darwin" ]; then
                age=$(( $(date +%s) - $(stat -f %m "$PANE_FILE") ))
            else
                age=$(( $(date +%s) - $(stat -c %Y "$PANE_FILE") ))
            fi
            if [ "$age" -ge "$STALE_THRESHOLD" ]; then
                local dir_name="${content#"${ICON_WORKING} "}"
                echo "${ICON_IDLE} ${dir_name}" > "$PANE_FILE"
            fi
            ;;
    esac
}

if [ -f "$PANE_FILE" ]; then
    # refs にこのpaneが登録されているか検証（孤立ファイル対策）
    if [ -f "$REFS_FILE" ] && grep -qxF "$PANE_ID" "$REFS_FILE"; then
        correct_stale_state
        tmux rename-window "$(cat "$PANE_FILE")"
    else
        # 孤立したpaneファイルを削除してカレントディレクトリ名を表示
        rm -f "$PANE_FILE"
        if [ -f "$REFS_FILE" ] && [ -s "$REFS_FILE" ]; then
            tmux rename-window "$("$SCRIPT_DIR/tmux-project-name.sh" "$(tmux display-message -p '#{pane_current_path}')")"
        fi
    fi
elif [ -f "$REFS_FILE" ] && [ -s "$REFS_FILE" ]; then
    # Claude実行中のウィンドウで非Claudeペインにフォーカス → カレントディレクトリ名を表示
    tmux rename-window "$("$SCRIPT_DIR/tmux-project-name.sh" "$(tmux display-message -p '#{pane_current_path}')")"
else
    # Claude状態なし → project名にフォールバック（resurrectの古い名前を上書き）
    tmux rename-window "$("$SCRIPT_DIR/tmux-project-name.sh" "$(tmux display-message -p '#{pane_current_path}')")"
fi
