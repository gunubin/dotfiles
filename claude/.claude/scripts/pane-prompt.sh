#!/bin/bash
# pane-prompt.sh - Read pane ID and last prompt for tmux pane-border-format
# Usage: pane-prompt.sh %76
PANE_ID="$1"
[ -z "$PANE_ID" ] && exit 0

PANE_NUM="${PANE_ID#%}"

STATE_FILE="$HOME/.claude/pane-state.json"
TEXT=""
if [ -f "$STATE_FILE" ]; then
    TEXT=$(jq -r --arg id "$PANE_ID" '.[$id].prompt // ""' "$STATE_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
fi

if [ -n "$TEXT" ]; then
    if [ ${#TEXT} -gt 30 ]; then
        TEXT="${TEXT:0:30}…"
    fi
    echo " ${PANE_NUM} ${TEXT} "
else
    echo " ${PANE_NUM} "
fi
