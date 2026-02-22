#!/usr/bin/env bash
# 新規ウィンドウ作成: workmux add（git リポジトリ内） or 通常 new-window（フォールバック）
# Claudeメインのワークフロー向け

PANE_PATH="$1"
cd "$PANE_PATH" 2>/dev/null || cd ~

# git リポジトリ内なら wma で worktree + cc team を自動起動
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fish -c 'wma' 2>/dev/null && exit 0
fi

# フォールバック: 通常の new-window
tmux new-window -c "$PANE_PATH"
