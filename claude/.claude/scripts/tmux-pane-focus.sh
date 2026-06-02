#!/bin/bash
# tmux-pane-focus.sh - pane切替時にウィンドウ名をプロジェクト名に更新
# tmux の after-select-pane hook から呼ばれる

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WINDOW_NAME=$(tmux display-message -p '#{window_name}')

# workmux管理のwindowはリネームしない
case "$WINDOW_NAME" in wm-*) exit 0 ;; esac

# 手動リネーム済み(prefix+R)のwindowは自動命名しない
[ "$(tmux display-message -p '#{@manual_name}')" = "1" ] && exit 0

DIR=$(tmux display-message -p '#{pane_current_path}')
[ -z "$DIR" ] && exit 0

tmux rename-window "$("$SCRIPT_DIR/tmux-project-name.sh" "$DIR")"
