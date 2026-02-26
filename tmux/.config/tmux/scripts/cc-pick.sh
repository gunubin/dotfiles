#!/bin/bash
# cc-pick をカレントディレクトリで実行するラッパー
# tmux popup から呼び出される
# ※ディレクトリは tmux display-popup -d "#{pane_current_path}" で設定済み

npx @gunubin/cc-pick@latest
status=$?
if [ $status -ne 0 ]; then
  echo ""
  echo "cc-pick exited with code $status"
  echo "Press Enter to close..."
  read -r
fi
