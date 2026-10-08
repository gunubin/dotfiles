#!/bin/bash
# tmux-pane-focus.sh - pane切替時にウィンドウ名をプロジェクト名に更新
# tmux の after-select-pane hook などから呼ばれる
#
# Usage: tmux-pane-focus.sh [window_id]
#   window_id 省略時は呼び出し時点のアクティブウィンドウ。
#   run-shell -b は非同期のため、判定とリネームの間にアクティブウィンドウが変わりうる。
#   最初に window_id を確定し、以降はすべて -t で同じウィンドウを操作する。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WID="${1:-$(tmux display-message -p '#{window_id}')}"
[ -z "$WID" ] && exit 0

# タブは IFS の空白扱いで空フィールドが詰められるため、空になりうる値は末尾に置く
IFS=$'\t' read -r MANUAL DIR WINDOW_NAME < <(
    tmux display-message -p -t "$WID" "#{?@manual_name,#{@manual_name},0}	#{pane_current_path}	#{window_name}" 2>/dev/null
) || exit 0

# workmux管理のwindowはリネームしない
case "$WINDOW_NAME" in wm-*) exit 0 ;; esac

# 手動リネーム済み(prefix+R)のwindowは自動命名しない
[ "$MANUAL" = "1" ] && exit 0

[ -z "$DIR" ] && exit 0

NAME="$("$SCRIPT_DIR/tmux-project-name.sh" "$DIR")"

# プロジェクト名の算出中に手動リネームされた場合に備えて直前に再確認する
[ "$(tmux display-message -p -t "$WID" '#{@manual_name}' 2>/dev/null)" = "1" ] && exit 0

tmux rename-window -t "$WID" -- "$NAME"
