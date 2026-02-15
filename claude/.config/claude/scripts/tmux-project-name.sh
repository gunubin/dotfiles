#!/bin/bash
# tmux-project-name.sh - パスからプロジェクト名を検出
# 1. git リポジトリならそのルート名
# 2. マーカーファイルで親方向に走査
# 3. フォールバック: ディレクトリ名
#
# Usage: tmux-project-name.sh <path>

MARKERS="Makefile package.json Cargo.toml pyproject.toml go.mod Gemfile"

dir="${1:?Usage: tmux-project-name.sh <path>}"

# 1. git リポジトリならそのルート名
git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$git_root" ]; then
    basename "$git_root"
    exit 0
fi

# 2. マーカーファイルで親方向に走査（$HOME で打ち止め）
current="$dir"
while [ "$current" != "$HOME" ] && [ "$current" != "/" ]; do
    for marker in $MARKERS; do
        if [ -e "$current/$marker" ]; then
            basename "$current"
            exit 0
        fi
    done
    current=$(dirname "$current")
done

# 3. フォールバック: カレントディレクトリ名
basename "$dir"
