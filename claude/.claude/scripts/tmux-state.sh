#!/bin/bash
# tmux-state.sh - Claude Code hook: write pane state to JSON for claude-panes

STATUS_WORKING="working"
STATUS_WAITING="waiting"
STATUS_IDLE="idle"

[ -z "$TMUX" ] && exit 0

input=$(cat)
event=$(echo "$input" | jq -r '.hook_event_name // "unknown"' 2>/dev/null)

PANE_ID="$TMUX_PANE"
[ -z "$PANE_ID" ] && exit 0
[[ "$PANE_ID" =~ ^%[0-9]+$ ]] || exit 0

STATE_FILE="$HOME/.claude/pane-state.json"
LOCK_DIR="$STATE_FILE.lock"

DIR_NAME=$(basename "$(tmux display-message -p -t "$PANE_ID" '#{pane_current_path}')")

# mkdir-based lock (portable, works on macOS without flock)
acquire_lock() {
    local i=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        i=$((i + 1))
        [ $i -ge 20 ] && return 1
        sleep 0.1
    done
    return 0
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null
}
trap 'release_lock' EXIT

# Run jq on STATE_FILE atomically (caller must hold lock)
jq_update() {
    [ ! -f "$STATE_FILE" ] && echo '{}' > "$STATE_FILE"
    local tmp="$STATE_FILE.tmp.$$"
    if jq "$@" "$STATE_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$STATE_FILE"
    else
        rm -f "$tmp"
    fi
}

case "$event" in
    SessionStart)
        mkdir -p "$(dirname "$STATE_FILE")"
        # Migrate from old per-file format
        rm -rf "$HOME/.claude/pane-state" 2>/dev/null
        # Cleanup stale + add new entry in one lock
        active=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr '\n' ' ')
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" --arg status "$STATUS_IDLE" --arg dir "$DIR_NAME" --arg active "$active" '
            ($active | split(" ") | map(select(length > 0))) as $valid |
            with_entries(select(.key | IN($valid[]))) |
            .[$id] = {"status": $status, "dir": $dir, "prompt": ""}
        '
        release_lock
        ;;
    UserPromptSubmit)
        prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null)
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" --arg status "$STATUS_WORKING" --arg dir "$DIR_NAME" --arg prompt "$prompt" \
            '.[$id] = {"status": $status, "dir": $dir, "prompt": $prompt}'
        release_lock
        ;;
    PreToolUse)
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" --arg status "$STATUS_WORKING" \
            'if .[$id] then .[$id].status = $status else . end'
        release_lock
        ;;
    Stop)
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" --arg status "$STATUS_WAITING" \
            'if .[$id] then .[$id].status = $status else . end'
        release_lock
        ;;
    SessionEnd)
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" 'del(.[$id])'
        release_lock
        ;;
    *)
        ;;
esac

exit 0
