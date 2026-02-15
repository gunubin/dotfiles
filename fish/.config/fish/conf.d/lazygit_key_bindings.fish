# Ctrl+g で lazygit を tmux ポップアップで開く
bind \cg 'tmux display-popup -E -w 100% -h 100% -d "#{pane_current_path}" lazygit'
if bind -M insert >/dev/null 2>/dev/null
    bind -M insert \cg 'tmux display-popup -E -w 100% -h 100% -d "#{pane_current_path}" lazygit'
end
