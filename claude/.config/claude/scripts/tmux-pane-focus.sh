#!/bin/bash
# tmux-pane-focus.sh - pane切替時にウィンドウ名をプロジェクト名に更新
# tmux の after-select-pane hook から呼ばれる

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WINDOW_NAME=$(tmux display-message -p '#{window_name}')

# workmux管理のwindowはリネームしない
case "$WINDOW_NAME" in wm-*) exit 0 ;; esac

# フォアグラウンドプロセスがシェルなら pane_current_path をそのまま使用
# シェル以外（claude, vim等）なら fish が保存した @shell_cwd を使用
PANE_CMD=$(tmux display-message -p '#{pane_current_command}')
case "$PANE_CMD" in
    fish|bash|zsh|sh)
        DIR=$(tmux display-message -p '#{pane_current_path}')
        ;;
    *)
        DIR=$(tmux display-message -p '#{@shell_cwd}')
        [ -z "$DIR" ] && exit 0
        ;;
esac

tmux rename-window "$("$SCRIPT_DIR/tmux-project-name.sh" "$DIR")"
