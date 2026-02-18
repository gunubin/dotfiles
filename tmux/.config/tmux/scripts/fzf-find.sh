#!/bin/bash
CALLER_PANE="$1"
result=$(/opt/homebrew/bin/fd --type f --hidden --exclude .git --color=always | /opt/homebrew/bin/fzf-tmux -p 80%,80% \
  --ansi \
  --preview "/opt/homebrew/bin/bat --color=always {} 2>/dev/null" \
  --expect=ctrl-a \
  --header="enter: relative / ctrl-a: absolute" \
  --style=full \
  --no-border \
  --padding=0,0 \
  --input-label=" Input " \
  --color=spinner:#F2D5CF,hl:#E78284 \
  --color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF \
  --color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 \
  --color=bg+:#51576D \
  --color=border:#303446,label:#C6D0F5 \
  --color=preview-border:#9999cc,preview-label:#ccccff \
  --color=list-border:#bfe7bb,list-label:#99cc99 \
  --color=input-border:#f6cce7,input-label:#ffcccc)
if [ -z "$result" ]; then
  exit 0
fi
key=$(echo "$result" | head -1)
file=$(echo "$result" | tail -1)
if [ "$key" = "ctrl-a" ]; then
  file="$(pwd)/$file"
fi
tmux send-keys -t "$CALLER_PANE" "$file"
