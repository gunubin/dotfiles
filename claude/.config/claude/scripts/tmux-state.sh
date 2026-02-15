#!/bin/bash
# tmux-state.sh - Claude Code hook: tmux ウィンドウ名に状態アイコンを反映
# pane単位で状態管理し、アクティブpaneの状態のみwindow tabに表示する
#
# アイコンをカスタマイズする場合はここを変更:
ICON_IDLE="󰭻"      # 入力待ち (nf-md-message_processing_outline)
ICON_WORKING="󰑮"   # 処理中 (nf-md-play_circle_outline)

# tmux 外では何もしない
[ -z "$TMUX" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# stdin から hook の JSON を読み取る
input=$(cat)
event=$(echo "$input" | jq -r '.hook_event_name // "unknown"' 2>/dev/null)

PANE_ID=$(tmux display-message -p '#{pane_id}')
WINDOW_ID=$(tmux display-message -p '#{window_id}')
IS_ACTIVE=$(tmux display-message -p '#{pane_active}')
DIR_NAME=$("$SCRIPT_DIR/tmux-project-name.sh" "$(tmux display-message -p '#{pane_current_path}')")

STATE_DIR="/tmp/claude-tmux"
PANE_FILE="$STATE_DIR/pane-${PANE_ID}"
ORIG_FILE="$STATE_DIR/orig-${WINDOW_ID}"
REFS_FILE="$STATE_DIR/refs-${WINDOW_ID}"
AUTORENAME_FILE="$STATE_DIR/autorename-${WINDOW_ID}"

# 現在のウィンドウの実効 automatic-rename 状態を取得
get_autorename() {
    local val
    val=$(tmux show-window-options -v automatic-rename 2>/dev/null)
    if [ -z "$val" ]; then
        val=$(tmux show-options -gv automatic-rename 2>/dev/null)
    fi
    echo "${val:-on}"
}

# アクティブpaneの場合のみウィンドウ名を更新
update_window_if_active() {
    [ "$IS_ACTIVE" = "1" ] && [ -f "$PANE_FILE" ] && tmux rename-window "$(cat "$PANE_FILE")"
}

# このウィンドウの孤立paneファイルをクリーンアップ
cleanup_orphaned_panes() {
    [ -f "$REFS_FILE" ] || return
    local tmp="${REFS_FILE}.tmp"
    > "$tmp"
    while IFS= read -r pane_id; do
        [ -z "$pane_id" ] && continue
        if tmux display-message -t "$pane_id" -p '#{pane_id}' >/dev/null 2>&1; then
            echo "$pane_id" >> "$tmp"
        else
            rm -f "$STATE_DIR/pane-${pane_id}"
        fi
    done < "$REFS_FILE"
    mv "$tmp" "$REFS_FILE"
    # 孤立pane除去後にrefsが空なら、汚染されたorig/autorenameも削除
    if [ ! -s "$REFS_FILE" ]; then
        rm -f "$ORIG_FILE" "$REFS_FILE" "$AUTORENAME_FILE"
    fi
}

case "$event" in
    SessionStart)
        mkdir -p "$STATE_DIR"
        # 孤立ファイルをクリーンアップ
        cleanup_orphaned_panes
        # 元のウィンドウ名と automatic-rename 状態を保存（このwindowで初回のみ）
        if [ ! -f "$ORIG_FILE" ]; then
            tmux display-message -p '#W' > "$ORIG_FILE"
            get_autorename > "$AUTORENAME_FILE"
        fi
        # このpaneを登録
        grep -qxF "$PANE_ID" "$REFS_FILE" 2>/dev/null || echo "$PANE_ID" >> "$REFS_FILE"
        # pane状態を保存
        echo "${ICON_IDLE} ${DIR_NAME}" > "$PANE_FILE"
        update_window_if_active
        ;;
    UserPromptSubmit)
        echo "${ICON_WORKING} ${DIR_NAME}" > "$PANE_FILE"
        update_window_if_active
        ;;
    Stop)
        echo "${ICON_IDLE} ${DIR_NAME}" > "$PANE_FILE"
        update_window_if_active
        ;;
    SessionEnd)
        rm -f "$PANE_FILE"
        # paneをrefsから除去
        if [ -f "$REFS_FILE" ]; then
            grep -vxF "$PANE_ID" "$REFS_FILE" > "${REFS_FILE}.tmp"
            mv "${REFS_FILE}.tmp" "$REFS_FILE"
        fi
        # このwindowにClaude paneがもうない場合、元の状態を復元
        if [ ! -s "$REFS_FILE" ]; then
            # automatic-rename が on だった場合は再有効化（名前はtmuxが自動設定）
            if [ -f "$AUTORENAME_FILE" ] && [ "$(cat "$AUTORENAME_FILE")" = "on" ]; then
                tmux set-window-option automatic-rename on
            elif [ -f "$ORIG_FILE" ]; then
                # automatic-rename が off だった場合は元の名前を復元
                tmux rename-window "$(cat "$ORIG_FILE")"
            fi
            rm -f "$ORIG_FILE" "$REFS_FILE" "$AUTORENAME_FILE"
        elif [ "$IS_ACTIVE" = "1" ]; then
            # アクティブpaneのClaudeが終了 → プロジェクト名を表示
            tmux rename-window "$("$SCRIPT_DIR/tmux-project-name.sh" "$(tmux display-message -p '#{pane_current_path}')")"
        fi
        ;;
esac

exit 0
