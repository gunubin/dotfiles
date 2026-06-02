#!/bin/bash
# tmux-rename-window.sh - prefix+R 用のリネームラッパー
# 手動リネーム時に @manual_name フラグを立て、自動命名(tmux-pane-focus.sh)から保護する。
# 空文字を渡すとフラグを解除し、自動命名(プロジェクト名追従)に戻す。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

name="$1"

if [ -z "$name" ]; then
    # 解除: フラグを消して即座に自動命名へ復帰
    tmux set-window-option -u @manual_name 2>/dev/null
    exec "$SCRIPT_DIR/tmux-pane-focus.sh"
fi

# 固定: 入力名にリネームしフラグを立てる
tmux rename-window -- "$name"
tmux set-window-option @manual_name 1
