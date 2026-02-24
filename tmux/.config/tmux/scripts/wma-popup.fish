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
    # 親リポジトリのルート（worktree 削除時に cwd を退避するため）
    set -l main_repo (dirname (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null))

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
                if not workmux merge $name
                    echo ""
                    printf "  %s✗ merge failed — resolve conflicts and retry%s\n" $warn $reset
                    echo ""
                    read -n 1 -P "  $dim(press any key)$reset "
                end
                break
            case d D
                cd "$main_repo"
                if not workmux remove -f $name
                    echo ""
                    printf "  %s✗ remove failed%s\n" $warn $reset
                    echo ""
                    read -n 1 -P "  $dim(press any key)$reset "
                end
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
        workmux add "$task_desc" </dev/null
    else
        wma </dev/null
    end
end

# workmux の post_create hook 失敗等のエラーコードを吸収
# (popup は UI 層なので run-shell にエラーを伝播させない)
exit 0
