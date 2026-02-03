#!/bin/bash
# Claude Code完了通知スクリプト
# 通知タップ時に該当tmuxウィンドウをアクティブにする

NOTIFICLI="$HOME/.local/bin/notificli"

# TMUX_PANEから現在のペイン情報を取得し、そこからウィンドウ情報を取得
if [ -n "$TMUX_PANE" ]; then
    TMUX_SESSION=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}' 2>/dev/null)
    TMUX_WINDOW=$(tmux display-message -t "$TMUX_PANE" -p '#{window_index}' 2>/dev/null)
    TMUX_WINDOW_NAME=$(tmux display-message -t "$TMUX_PANE" -p '#{window_name}' 2>/dev/null)
else
    TMUX_SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null)
    TMUX_WINDOW=$(tmux display-message -p '#{window_index}' 2>/dev/null)
    TMUX_WINDOW_NAME=$(tmux display-message -p '#{window_name}' 2>/dev/null)
fi

# tmux外で実行された場合はフォールバック
if [ -z "$TMUX_SESSION" ] || [ -z "$TMUX_WINDOW" ]; then
    osascript -e 'display notification "Finished!!!" with title "Claude Code"' &
    afplay /System/Library/Sounds/Purr.aiff &
    exit 0
fi

# バックグラウンドで通知を送信し、クリックを待機
bash -c "
    RESPONSE=\$('$NOTIFICLI' \
        -title 'Claude Code' \
        -message 'Finished! (${TMUX_SESSION}:${TMUX_WINDOW} ${TMUX_WINDOW_NAME})' \
        -sound 'Purr' \
        -actions 'Open')

    if [ -n \"\$RESPONSE\" ]; then
        osascript -e 'tell application \"Ghostty\" to activate'
        sleep 0.3
        tmux select-window -t '${TMUX_SESSION}:${TMUX_WINDOW}'
    fi
" &
