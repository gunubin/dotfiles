#!/bin/bash
WIN=$1
[ -z "$WIN" ] && exit 0
if tmux list-windows -F '#{window_index}' | grep -qx "$WIN"; then
    tmux select-window -t ":$WIN"
else
    tmux display-message "Window $WIN does not exist"
fi
