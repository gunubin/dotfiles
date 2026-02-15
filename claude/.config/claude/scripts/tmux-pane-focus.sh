#!/bin/bash
# tmux-pane-focus.sh - pane切替時にウィンドウ名をフォーカスpaneの状態に更新
# tmux の pane-focus-in hook から呼ばれる

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
        # 孤立したpaneファイルを削除して元の名前に戻す
        rm -f "$PANE_FILE"
        if [ -f "$ORIG_FILE" ]; then
            tmux rename-window "$(cat "$ORIG_FILE")"
        fi
    fi
elif [ -f "$ORIG_FILE" ]; then
    # Claude実行中でないpaneにフォーカス → 元のウィンドウ名に戻す
    tmux rename-window "$(cat "$ORIG_FILE")"
fi
