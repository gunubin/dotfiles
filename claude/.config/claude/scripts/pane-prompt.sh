#!/bin/bash
# pane-prompt.sh - Read last prompt for tmux pane-border-format
# Usage: pane-prompt.sh %76
PANE_ID="$1"
[ -z "$PANE_ID" ] && exit 0

FILE="$HOME/.claude/pane-state/prompt-${PANE_ID}"
[ ! -f "$FILE" ] && exit 0

# Read, join lines, trim whitespace, truncate to 60 chars
TEXT=$(tr '\n' ' ' < "$FILE" | sed 's/  */ /g; s/^ //; s/ $//')
[ -z "$TEXT" ] && exit 0

if [ ${#TEXT} -gt 60 ]; then
    TEXT="${TEXT:0:60}…"
fi

echo " $TEXT "
