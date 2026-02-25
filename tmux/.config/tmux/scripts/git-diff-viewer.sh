#!/bin/bash
# シンプルな git 差分ビューア（fzf-tmux ポップアップ）

FZF=$(command -v fzf-tmux 2>/dev/null) || { echo "fzf-tmux not found" >&2; exit 1; }
STRIP="sed 's/^...//; s/\"//g'"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

git -c color.status=always status --short \
  | $FZF -p 80%,80% \
    --ansi \
    --preview "git diff --color=always -- \$(echo {} | $STRIP) 2>/dev/null; git diff --cached --color=always -- \$(echo {} | $STRIP) 2>/dev/null" \
    --preview-window=right:65% \
    --header="ESC: quit" \
    --style=full \
    --no-border \
    --padding=0,0 \
    --input-label=" Git Status " \
    --color=spinner:#F2D5CF,hl:#E78284 \
    --color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF \
    --color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 \
    --color=bg+:#51576D \
    --color=border:#303446,label:#C6D0F5 \
    --color=preview-border:#9999cc,preview-label:#ccccff \
    --color=list-border:#bfe7bb,list-label:#99cc99 \
    --color=input-border:#f6cce7,input-label:#ffcccc
