#!/bin/bash
CALLER_PANE="$1"
EZA=$(command -v eza || true)
FZF=$(command -v fzf-tmux || true)
if [ -z "$FZF" ]; then tmux display-message "fzf not found"; exit 1; fi
FD=$(command -v fd || command -v fdfind || true)
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
  if [ -n "$FD" ]; then $FD --type f --hidden --exclude .git; else find . -type f -not -path '*/.git/*' 2>/dev/null; fi
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
  --input-label=" Input ")
if [ -z "$result" ]; then
  exit 0
fi
key=$(echo "$result" | head -1)
file=$(echo "$result" | tail -1 | sed $'s/\033\\[[0-9;]*m//g; s/^[^\t]*\t//' | perl -CSD -pe 's/^.\s//')
if [ "$key" = "ctrl-a" ]; then
  file="$(pwd)/$file"
fi
tmux send-keys -t "$CALLER_PANE" -l -- "$file"
