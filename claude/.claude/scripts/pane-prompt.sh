#!/bin/bash
# pane-prompt.sh - Read the session's first prompt for tmux pane-border-format
# Usage: pane-prompt.sh %76 [fallback]
#   プロンプトがなければ fallback（tmux からはディレクトリ名を渡す）を出す
PANE_ID="$1"
FALLBACK="$2"
[ -z "$PANE_ID" ] && exit 0

STATE_FILE="$HOME/.claude/pane-state.json"
TEXT=""
if [ -f "$STATE_FILE" ]; then
    TEXT=$(jq -r --arg id "$PANE_ID" '.[$id].first_prompt // ""' "$STATE_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
fi

if [ ${#TEXT} -gt 30 ]; then
    TEXT="${TEXT:0:30}…"
fi
echo "${TEXT:-$FALLBACK}"
