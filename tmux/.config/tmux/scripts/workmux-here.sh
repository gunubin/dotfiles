#!/bin/bash
# workmux-here.sh - 現在のウィンドウを workmux 管理に変換する
# tmux keybinding から呼び出すことで cc 実行中でも使える
#
# Usage: tmux bind W run-shell "~/.config/tmux/scripts/workmux-here.sh"

set -euo pipefail

# tmux 外なら中断
[ -z "${TMUX:-}" ] && exit 0

PANE_PATH=$(tmux display-message -p '#{pane_current_path}')
OLD_WINDOW=$(tmux display-message -p '#{window_id}')

# git リポジトリチェック
if ! git -C "$PANE_PATH" rev-parse --git-dir >/dev/null 2>&1; then
    tmux display-message "workmux-here: not a git repository"
    exit 1
fi

cd "$PANE_PATH"

# 日付ベースのブランチ名を生成（wma と同じロジック）
TODAY=$(date +%Y-%m-%d)
PREFIX="feature-$TODAY"

MAX=0
for branch in $(git branch --all --list "*$PREFIX-*" 2>/dev/null | sed 's/^[* ]*//' | sed 's|.*/||'); do
    s="${branch#"$PREFIX-"}"
    s="${s:0:1}"
    code=$(printf '%d' "'$s" 2>/dev/null || echo 0)
    if [ "$code" -gt "$MAX" ]; then
        MAX=$code
    fi
done

if [ "$MAX" -eq 0 ]; then
    SUFFIX="a"
else
    NEXT=$((MAX + 1))
    SUFFIX=$(printf "\\x$(printf '%02x' "$NEXT")")
fi

BRANCH="$PREFIX-$SUFFIX"

tmux display-message "workmux-here: creating $BRANCH ..."

# workmux window を作成（未コミットの変更も移行）
if workmux add --with-changes "$BRANCH"; then
    # 元のウィンドウを閉じる
    tmux kill-window -t "$OLD_WINDOW" 2>/dev/null || true
else
    tmux display-message "workmux-here: failed to create $BRANCH"
    exit 1
fi
