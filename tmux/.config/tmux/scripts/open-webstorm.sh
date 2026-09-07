#!/bin/sh
# tmuxのステータスバー/メニューから、指定paneのプロジェクトをWebStormで開く
# 使い方: open-webstorm.sh <pane_current_path>
LOG=/tmp/open-webstorm.log

dir="$1"
echo "$(date '+%F %T') called with: '$dir'" >>"$LOG"

if [ ! -d "$dir" ]; then
    echo "  -> not a directory, abort" >>"$LOG"
    exit 1
fi

cd "$dir" || exit 1
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "  -> opening: $root" >>"$LOG"
open -na WebStorm --args "$root" >>"$LOG" 2>&1
# open -n は既存インスタンスへ転送するだけでフォーカスが移らないことがあるため明示的に前面化
open -a WebStorm >>"$LOG" 2>&1
