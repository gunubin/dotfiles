#!/usr/bin/env bash
# Claude Code セッションをfzfで選択して resume / focus する
# Usage: claude-resume.sh <pane_id>
#
# 一覧・プレビュー(recap)とも claude-session-list.py が生成する
# （TSV: 表示 / session_id / cwd / pane_id / jsonl）。
#   - スコープは ctrl-a でトグル: カレントディレクトリ <-> 全プロジェクト直近7日
#   - 起動中セッション(●)は Enter でその pane にフォーカス（別ウィンドウならウィンドウごと移動）
#   - 終了済み(○)は Enter でそのセッションの cwd で resume

set -euo pipefail

CALLER_PANE="${1:?pane_id required}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$0")"
LIST_SCRIPT="$SCRIPT_DIR/claude-session-list.py"
DAYS=7
TAB=$(printf '\t')

CWD=$(tmux display-message -t "$CALLER_PANE" -p '#{pane_current_path}')
[ -z "$CWD" ] && exit 1

# --- サブコマンド（fzf から呼び戻される） -----------------------------------
case "${2:-}" in
    --list)
        python3 "$LIST_SCRIPT" --scope "$3" --cwd "$CWD" --days "$DAYS"
        exit 0
        ;;
    --toggle)
        # 状態ファイルを反転し、fzf に渡すアクション文字列を返す（transform bind）
        state_file="$3"
        scope=$(cat "$state_file" 2>/dev/null || echo current)
        if [ "$scope" = "current" ]; then scope=all; else scope=current; fi
        echo "$scope" > "$state_file"
        if [ "$scope" = "all" ]; then
            label=" Claude Sessions - all projects / last ${DAYS}d "
            header="Enter: focus or resume / ctrl-a: current dir only"
        else
            label=" Claude Sessions - $(basename "$CWD") "
            header="Enter: focus or resume / ctrl-a: all projects last ${DAYS}d"
        fi
        echo "reload(bash $SCRIPT_PATH $CALLER_PANE --list $scope)+change-border-label($label)+change-header($header)"
        exit 0
        ;;
esac

# --- 一覧を出して選ばせる ---------------------------------------------------
STATE_FILE=$(mktemp "${TMPDIR:-/tmp}/claude-resume-scope.XXXXXX")
trap 'rm -f "$STATE_FILE"' EXIT
echo current > "$STATE_FILE"

SESSIONS=$(python3 "$LIST_SCRIPT" --scope current --cwd "$CWD" --days "$DAYS")
if [ -z "$SESSIONS" ]; then
    # このディレクトリに履歴が無ければ最初から全プロジェクト表示にする
    echo all > "$STATE_FILE"
    SESSIONS=$(python3 "$LIST_SCRIPT" --scope all --cwd "$CWD" --days "$DAYS")
    [ -z "$SESSIONS" ] && { tmux display-message "No Claude sessions found"; exit 0; }
fi

if [ "$(cat "$STATE_FILE")" = "all" ]; then
    INIT_LABEL=" Claude Sessions - all projects / last ${DAYS}d "
    INIT_HEADER="Enter: focus or resume / ctrl-a: current dir only"
else
    INIT_LABEL=" Claude Sessions - $(basename "$CWD") "
    INIT_HEADER="Enter: focus or resume / ctrl-a: all projects last ${DAYS}d"
fi

SELECTED=$(printf '%s\n' "$SESSIONS" | fzf --tmux 92%,88% \
    --ansi \
    --delimiter="$TAB" \
    --with-nth=1 \
    --header="$INIT_HEADER" \
    --bind="ctrl-a:transform:bash $SCRIPT_PATH $CALLER_PANE --toggle $STATE_FILE" \
    --preview="python3 $LIST_SCRIPT --recap {5}" \
    --preview-window=right:52%:wrap \
    --no-sort \
    --border=rounded \
    --border-label="$INIT_LABEL" \
    --border-label-pos=2 \
) || exit 0

[ -z "$SELECTED" ] && exit 0
SESSION_ID=$(printf '%s' "$SELECTED" | cut -d"$TAB" -f2)
SESS_CWD=$(printf '%s' "$SELECTED" | cut -d"$TAB" -f3)
PANE_ID=$(printf '%s' "$SELECTED" | cut -d"$TAB" -f4)
[ -z "$SESSION_ID" ] && exit 0

# --- 起動中セッション: その pane にフォーカス -------------------------------
if [ -n "$PANE_ID" ] && tmux list-panes -a -F '#{pane_id}' | grep -qx -- "$PANE_ID"; then
    TSESSION=$(tmux display-message -p -t "$PANE_ID" '#{session_name}')
    TWINDOW=$(tmux display-message -p -t "$PANE_ID" '#{window_id}')
    tmux switch-client -t "$TSESSION" 2>/dev/null || true
    tmux select-window -t "$TWINDOW"
    tmux select-pane -t "$PANE_ID"
    exit 0
fi

# --- 終了済みセッション: そのセッションの cwd で resume ---------------------
[ -d "$SESS_CWD" ] || SESS_CWD="$CWD"
CURRENT_CMD=$(tmux display-message -t "$CALLER_PANE" -p '#{pane_current_command}')
if echo "$CURRENT_CMD" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    # 呼び出し元paneでClaude Codeが動作中なら右に新paneを作る
    tmux split-window -h -t "$CALLER_PANE" -c "$SESS_CWD" "claude --resume $SESSION_ID"
elif [ "$SESS_CWD" = "$CWD" ]; then
    tmux send-keys -t "$CALLER_PANE" "claude --resume $SESSION_ID" Enter
else
    tmux send-keys -t "$CALLER_PANE" "cd $SESS_CWD && claude --resume $SESSION_ID" Enter
fi
