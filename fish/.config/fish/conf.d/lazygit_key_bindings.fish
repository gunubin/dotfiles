# Ctrl+g で lazygit を tmux ポップアップで開く
bind \cg 'tmux display-popup -E -w 95% -h 95% lazygit'
if bind -M insert >/dev/null 2>/dev/null
    bind -M insert \cg 'tmux display-popup -E -w 95% -h 95% lazygit'
end
