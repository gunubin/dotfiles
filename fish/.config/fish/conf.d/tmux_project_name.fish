# tmux_project_name.fish - cd時にtmuxウィンドウ名をプロジェクト名に更新

# シェル起動時に1回だけ実行（--on-variable PWD は PWD 変化時のみ発火するため）
if test -n "$TMUX"
    set -l _win_name (tmux display-message -p '#{window_name}')
    if not string match -q 'wm-*' $_win_name
        tmux rename-window ($HOME/.config/claude/scripts/tmux-project-name.sh $PWD)
    end
    tmux set-option -pq @shell_cwd $PWD
end

function __tmux_update_project_name --on-variable PWD
    test -n "$TMUX"; or return
    tmux set-option -pq @shell_cwd $PWD
    # workmux管理のwindowはリネームしない
    set -l win_name (tmux display-message -p '#{window_name}')
    string match -q 'wm-*' $win_name; and return
    tmux rename-window ($HOME/.config/claude/scripts/tmux-project-name.sh $PWD)
end
