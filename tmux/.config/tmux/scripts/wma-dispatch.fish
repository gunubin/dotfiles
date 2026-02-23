#!/usr/bin/env fish

set -l pane_path $argv[1]
set -l window_name $argv[2]

set -l is_workmux false

# 1. tmux window名で判定
if string match -q 'wm-*' "$window_name"
    set is_workmux true
end

# 2. git worktree かどうかで判定（.git がファイル = worktree）
if not $is_workmux
    set -l toplevel (git -C "$pane_path" rev-parse --show-toplevel 2>/dev/null)
    if test -n "$toplevel" -a -f "$toplevel/.git"
        set is_workmux true
    end
end

if $is_workmux
    tmux display-popup -E -d "$pane_path" -w 50% -h 7 \
        -b rounded -S "fg=#f38ba8" -T " 󰆴 manage " \
        "fish ~/.config/tmux/scripts/wma-popup.fish manage"
else
    tmux display-popup -E -d "$pane_path" -w 50% -h 6 \
        -b rounded -S "fg=#cba6f7" -T " 󰝰 workmux " \
        "fish ~/.config/tmux/scripts/wma-popup.fish create"
end
