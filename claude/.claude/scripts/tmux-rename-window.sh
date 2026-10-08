#!/bin/bash
# tmux-rename-window.sh - prefix+R / 右クリックメニュー用のリネームラッパー
# 手動リネーム時に @manual_name フラグを立て、自動命名(tmux-pane-focus.sh)から保護する。
# 空文字を渡すとフラグを解除し、自動命名(プロジェクト名追従)に戻す。
#
# Usage: tmux-rename-window.sh <name> [window_id]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

name="$1"
WID="${2:-$(tmux display-message -p '#{window_id}')}"

if [ -z "$name" ]; then
    # 解除: フラグを消して即座に自動命名へ復帰
    tmux set-window-option -t "$WID" -u @manual_name 2>/dev/null
    exec "$SCRIPT_DIR/tmux-pane-focus.sh" "$WID"
fi

# 固定: 先にフラグを立ててから改名する（自動命名の割り込みで上書きされないように）
tmux set-window-option -t "$WID" @manual_name 1
tmux rename-window -t "$WID" -- "$name"
