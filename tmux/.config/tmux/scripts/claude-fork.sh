#!/usr/bin/env bash
# 現在のpaneで動いているClaude Codeセッションを正確にforkする
# Usage: claude-fork.sh <pane_id>
#
# pane_id → session_id の対応は tmux-state.sh (SessionStart hook) が
# ~/.claude/pane-state.json に記録している。これを逆引きして
# `claude --resume <session-id> --fork-session` を右paneで起動する。
# session_idが取れない/jsonlが無い場合は claude-resume.sh のfzf pickerにフォールバック。

set -euo pipefail

CALLER_PANE="${1:?pane_id required}"
STATE_FILE="$HOME/.claude/pane-state.json"
CLAUDE_PROJECTS="$HOME/.claude/projects"

CWD=$(tmux display-message -t "$CALLER_PANE" -p '#{pane_current_path}')
[ -z "$CWD" ] && exit 1

# 現在paneのsession_idを逆引き
SESSION_ID=""
if [ -f "$STATE_FILE" ]; then
    SESSION_ID=$(jq -r --arg id "$CALLER_PANE" '.[$id].session_id // ""' "$STATE_FILE" 2>/dev/null || echo "")
fi

# cwdをClaude Codeのプロジェクトディレクトリ名にエンコード（claude-resume.shと同じ規則）
PROJECT_DIR="$CLAUDE_PROJECTS/$(echo "$CWD" | sed 's|[/.]|-|g')"

# session_idが取れ、対応するjsonlが実在すればfork
if [ -n "$SESSION_ID" ] && [ -f "$PROJECT_DIR/$SESSION_ID.jsonl" ]; then
    tmux split-window -h -t "$CALLER_PANE" -c "$CWD" \
        "claude --resume $SESSION_ID --fork-session --dangerously-skip-permissions"
    exit 0
fi

# フォールバック: fzf pickerでセッションを選んでresume
exec "$(dirname "$0")/claude-resume.sh" "$CALLER_PANE"
