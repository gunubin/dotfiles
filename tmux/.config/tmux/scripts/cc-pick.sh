#!/bin/bash
# cc-pick をgitルートで実行するラッパー
# tmux popup から呼び出される
# ※ディレクトリは tmux display-popup -d で設定済み

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 1
npx @gunubin/cc-pick
status=$?
if [ $status -ne 0 ]; then
  echo ""
  echo "cc-pick exited with code $status"
  echo "Press Enter to close..."
  read -r
fi
