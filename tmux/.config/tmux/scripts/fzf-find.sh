#!/bin/bash
CALLER_PANE="$1"
EZA=$(command -v eza || true)
FZF=/opt/homebrew/bin/fzf-tmux
FD=/opt/homebrew/bin/fd
BAT=$(command -v bat || true)
STRIP="perl -CSD -pe 's/\e\[\d+(?:;\d+)*m//g; s/^.\s//'"

git_map=$(mktemp)
trap 'rm -f "$git_map"' EXIT

if git rev-parse --is-inside-work-tree &>/dev/null; then
  git status --porcelain 2>/dev/null | awk '{ print substr($0, 4) "\t" substr($0, 1, 2) }' > "$git_map"
fi

result=$({
  if [ -s "$git_map" ]; then
    cut -f1 "$git_map" | while IFS= read -r f; do
      [ -e "$f" ] && echo "$f"
    done
  fi
  $FD --type f --hidden --exclude .git
} | awk 'seen[$0]++ == 0' \
  | if [ -n "$EZA" ]; then $EZA --stdin --color=always --icons=always --sort=none -1 2>/dev/null; else cat; fi \
  | awk -v mapfile="$git_map" '
  BEGIN {
    while ((getline line < mapfile) > 0) {
      idx = index(line, "\t")
      if (idx > 0) statuses[substr(line, 1, idx-1)] = substr(line, idx+1)
    }
    close(mapfile)
  }
  {
    plain = $0
    gsub(/\033\[[0-9;]*m/, "", plain)
    sub(/^. /, "", plain)
    st = statuses[plain]
    if (st == "??")                                    prefix = "\033[90m??\033[0m"
    else if (st == " M" || st == " D")                 prefix = "\033[31m" st "\033[0m"
    else if (st == "M " || st == "A " || st == "D " || st == "R ") prefix = "\033[32m" st "\033[0m"
    else if (st == "MM" || st == "AM")                 prefix = "\033[33m" st "\033[0m"
    else if (st != "")                                 prefix = st
    else                                               prefix = "  "
    printf "%s\t%s\n", prefix, $0
  }' \
  | $FZF -p 80%,80% \
  --ansi \
  --delimiter=$'\t' \
  --tabstop=3 \
  --nth=2 \
  --preview "$(if [ -n "$BAT" ]; then echo "$BAT --color=always --style=plain"; else echo "cat"; fi) \$(echo {2} | $STRIP) 2>/dev/null" \
  --expect=ctrl-a \
  --header="enter: relative / ctrl-a: absolute" \
  --tiebreak=index \
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
file=$(echo "$result" | tail -1 | sed $'s/\033\\[[0-9;]*m//g; s/^[^\t]*\t//' | perl -CSD -pe 's/^.\s//')
if [ "$key" = "ctrl-a" ]; then
  file="$(pwd)/$file"
fi
tmux send-keys -t "$CALLER_PANE" "$file"
