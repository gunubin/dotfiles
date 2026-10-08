#!/bin/bash
# tmux-state.sh - Claude Code hook: pane の状態を JSON に記録し、tmux のタブにアイコンを出す
#   - ~/.claude/pane-state.json: claude-agents.py（prefix + C-a）や pane-prompt.sh が読む
#   - window option @claude_status: tmux.conf の window-status-format が表示する

STATUS_WORKING="working"
STATUS_WAITING="waiting"   # 許可・質問への回答待ち
STATUS_DONE="done"         # 応答完了（ユーザーの入力待ち）
STATUS_IDLE="idle"

# Nerd Font アイコン（tmux.conf の codepoint-widths と揃える）
ICON_WORKING="󰚩"
ICON_WAITING="󰔟"
ICON_DONE="󰄬"

[ -z "$TMUX" ] && exit 0

input=$(cat)
event=$(echo "$input" | jq -r '.hook_event_name // "unknown"' 2>/dev/null)
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null)

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

# タブのアイコンを更新する。waiting / done はウィンドウにフォーカスした時点で消す。
# 表示中のウィンドウで完了した場合は、すでに見ているので done を出さない。
set_window_status() {
    local status="$1" icon=""
    case "$status" in
        "$STATUS_WORKING") icon="$ICON_WORKING" ;;
        "$STATUS_WAITING") icon="$ICON_WAITING" ;;
        "$STATUS_DONE")
            if [ "$(tmux display-message -p -t "$PANE_ID" '#{&&:#{window_active},#{session_attached}}')" != "1" ]; then
                icon="$ICON_DONE"
            fi
            ;;
    esac

    if [ -z "$icon" ]; then
        tmux set-option -uw -t "$PANE_ID" @claude_status 2>/dev/null
        return
    fi
    tmux set-option -w -t "$PANE_ID" @claude_status "$icon" 2>/dev/null
    if [ "$status" != "$STATUS_WORKING" ]; then
        # その後に別の状態へ変わっていたら消さない
        tmux set-hook -w -t "$PANE_ID" pane-focus-in \
            "if-shell -F '#{==:#{@claude_status},$icon}' 'set-option -uw @claude_status'" 2>/dev/null
    fi
}

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
        jq_update --arg id "$PANE_ID" --arg status "$STATUS_IDLE" --arg dir "$DIR_NAME" --arg active "$active" --arg sid "$SESSION_ID" '
            ($active | split(" ") | map(select(length > 0))) as $valid |
            with_entries(select(.key | IN($valid[]))) |
            .[$id] = {"status": $status, "dir": $dir, "prompt": "", "session_id": $sid, "ts": (now | floor)}
        '
        release_lock
        set_window_status "$STATUS_IDLE"
        ;;
    UserPromptSubmit)
        prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null)
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" --arg status "$STATUS_WORKING" --arg dir "$DIR_NAME" --arg prompt "$prompt" --arg sid "$SESSION_ID" \
            '.[$id] = {"status": $status, "dir": $dir, "prompt": $prompt, "session_id": $sid, "ts": (now | floor)}'
        release_lock
        set_window_status "$STATUS_WORKING"
        ;;
    PreToolUse | PostToolUse | Notification | Stop)
        case "$event" in
            Notification) status="$STATUS_WAITING" ;;   # settings.json の matcher で許可・質問に限定
            Stop) status="$STATUS_DONE" ;;
            *) status="$STATUS_WORKING" ;;
        esac
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" --arg status "$status" \
            'if .[$id] then .[$id].status = $status | .[$id].ts = (now | floor) else . end'
        release_lock
        set_window_status "$status"
        ;;
    SessionEnd)
        acquire_lock || exit 0
        jq_update --arg id "$PANE_ID" 'del(.[$id])'
        release_lock
        set_window_status "$STATUS_IDLE"
        ;;
    *)
        ;;
esac

exit 0
