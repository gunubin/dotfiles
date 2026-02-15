# tmux_project_name.fish - cd時にtmuxウィンドウ名をプロジェクト名に更新

# シェル起動時に1回だけ実行（--on-variable PWD は PWD 変化時のみ発火するため）
if test -n "$TMUX"
    set -l _pane_id (tmux display-message -p '#{pane_id}')
    if not test -f "/tmp/claude-tmux/pane-$_pane_id"
        tmux rename-window ($HOME/.config/claude/scripts/tmux-project-name.sh $PWD)
    end
end

function __tmux_update_project_name --on-variable PWD
    test -n "$TMUX"; or return
    # Claude pane 自身は tmux-state.sh が管理するのでスキップ
    set -l pane_id (tmux display-message -p '#{pane_id}')
    test -f "/tmp/claude-tmux/pane-$pane_id"; and return
    tmux rename-window ($HOME/.config/claude/scripts/tmux-project-name.sh $PWD)
end
