#!/bin/bash
# tmux-pane-focus.sh - pane切替時にウィンドウ名をフォーカスpaneの状態に更新
# tmux の pane-focus-in hook から呼ばれる

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/tmp/claude-tmux"

PANE_ID=$(tmux display-message -p '#{pane_id}')
WINDOW_ID=$(tmux display-message -p '#{window_id}')
PANE_FILE="$STATE_DIR/pane-${PANE_ID}"
ORIG_FILE="$STATE_DIR/orig-${WINDOW_ID}"
REFS_FILE="$STATE_DIR/refs-${WINDOW_ID}"

if [ -f "$PANE_FILE" ]; then
    # refs にこのpaneが登録されているか検証（孤立ファイル対策）
    if [ -f "$REFS_FILE" ] && grep -qxF "$PANE_ID" "$REFS_FILE"; then
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
fi
