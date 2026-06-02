# tmux_project_name.fish - cd時にtmuxウィンドウ名をプロジェクト名に更新

# 非インタラクティブシェルでは実行しない（Claude Code等のサブシェル対策）
status is-interactive; or return

# シェル起動時に1回だけ実行（--on-variable PWD は PWD 変化時のみ発火するため）
if test -n "$TMUX"
    set -l _win_name (tmux display-message -p '#{window_name}')
    set -l _manual (tmux display-message -p '#{@manual_name}')
    # workmux管理(wm-*)・手動リネーム済み(prefix+R)のwindowはリネームしない
    if not string match -q 'wm-*' $_win_name; and test "$_manual" != 1
        tmux rename-window ($HOME/.claude/scripts/tmux-project-name.sh $PWD)
    end
end

function __tmux_update_project_name --on-variable PWD
    test -n "$TMUX"; or return
    # workmux管理のwindowはリネームしない
    set -l win_name (tmux display-message -p '#{window_name}')
    string match -q 'wm-*' $win_name; and return
    # 手動リネーム済み(prefix+R)のwindowはリネームしない
    set -l manual (tmux display-message -p '#{@manual_name}')
    test "$manual" = 1; and return
    tmux rename-window ($HOME/.claude/scripts/tmux-project-name.sh $PWD)
end
