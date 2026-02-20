#!/bin/bash
# pane-prompt.sh - Read last prompt for tmux pane-border-format
# Usage: pane-prompt.sh %76
PANE_ID="$1"
[ -z "$PANE_ID" ] && exit 0

FILE="$HOME/.claude/pane-state/prompt-${PANE_ID}"
[ ! -f "$FILE" ] && exit 0

# Read, join lines, trim whitespace, truncate to 30 chars
TEXT=$(tr '\n' ' ' < "$FILE" | sed 's/  */ /g; s/^ //; s/ $//')
[ -z "$TEXT" ] && exit 0

if [ ${#TEXT} -gt 30 ]; then
    TEXT="${TEXT:0:30}…"
fi

echo " $TEXT "
