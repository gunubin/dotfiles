#!/usr/bin/env fish

set -g fish_escape_delay_ms 50
bind \e 'exit 0'

set -l dim (set_color 6c7086)
set -l accent (set_color cba6f7)
set -l warn (set_color f38ba8)
set -l name_clr (set_color fab387)
set -l reset (set_color normal)

set -l mode $argv[1]

if test "$mode" = manage
    # git worktree root からワークスペース名を取得
    set -l worktree_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l name (basename "$worktree_root")

    echo ""
    printf "  %s⚠ workspace %s%s%s\n" $warn $name_clr $name $reset
    echo ""
    printf "  %sm%s = merge · %sd%s = remove · %sESC%s = cancel\n" $accent $dim $warn $dim $dim $reset
    echo ""

    while true
        read -n 1 -P "  $warn❯$reset " key
        or exit 0

        switch "$key"
            case m M
                workmux merge $name
                break
            case d D
                workmux remove -f $name
                break
        end
    end
else
    echo ""
    printf "  %sワークスペース名を入力 · 空Enter = 自動命名%s\n" $dim $reset
    echo ""
    read -P "  $accent❯$reset " task_desc
    or exit 0

    if test -n "$task_desc"
        workmux add "$task_desc"
    else
        wma
    end
end
