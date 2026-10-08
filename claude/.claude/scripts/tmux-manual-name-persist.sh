#!/bin/bash
# tmux-manual-name-persist.sh - 手動リネーム(@manual_name)を tmux-resurrect の保存・復元に引き継ぐ
# resurrect はウィンドウ名を戻すが @manual_name は保存しないため、復元後に自動命名で上書きされる。
#
# Usage: tmux-manual-name-persist.sh save|restore
#   save:    @resurrect-hook-post-save-all から呼ぶ
#   restore: @resurrect-hook-post-restore-all から呼ぶ

STATE_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/manual-names.tsv"

case "$1" in
save)
    mkdir -p "$(dirname "$STATE_FILE")"
    tmux list-windows -a -F "#{@manual_name}	#{session_name}:#{window_index}	#{window_name}" |
        awk -F '\t' '$1 == "1" { print $2 "\t" $3 }' > "$STATE_FILE.tmp" &&
        mv "$STATE_FILE.tmp" "$STATE_FILE"
    ;;
restore)
    [ -f "$STATE_FILE" ] || exit 0
    # 復元中のペイン選択で自動命名が先に走るため、フラグに加えて名前も戻す
    while IFS=$'\t' read -r target name; do
        tmux set-window-option -t "$target" @manual_name 1 2>/dev/null || continue
        tmux rename-window -t "$target" -- "$name"
    done < "$STATE_FILE"
    ;;
*)
    echo "Usage: $0 save|restore" >&2
    exit 1
    ;;
esac
