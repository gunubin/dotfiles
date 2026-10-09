#!/bin/bash
# resurrect-strip-popups.sh - tmux-resurrect の保存データから popup セッション（tmux-toggle-popup）を除く
# 復元された popup セッションには __tmux_popup_name が戻らず、ポップアップ内から別のポップアップを開くと入れ子になるため。
# popup セッションは次に開いたときに作り直される。
#
# Usage: @resurrect-hook-post-save-all から呼ぶ

dir=$(tmux show -gqv @resurrect-dir)
dir=${dir:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect}
dir=${dir/#\~/$HOME}
file=$(readlink -f "$dir/last" 2>/dev/null) || exit 0
[ -f "$file" ] || exit 0

# 2列目がセッション名（pane / window / grouped_session 行）。state 行の3列目は直前のセッション
awk -F '\t' -v OFS='\t' '
    $2 ~ /^popup[\/-]/ { next }
    $1 == "state" && $3 ~ /^popup[\/-]/ { $3 = "" }
    { print }
' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
