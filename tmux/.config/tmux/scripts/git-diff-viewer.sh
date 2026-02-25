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
    --input-label=" Git Status "
