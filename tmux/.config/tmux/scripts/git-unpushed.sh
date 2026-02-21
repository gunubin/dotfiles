#!/bin/sh
cd "$1" 2>/dev/null || exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

# 1. upstream が設定されている場合
CNT=$(git rev-list @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ')

# 2. origin/ブランチ名 が存在する場合(一度はpushされたブランチ)
if [ -z "$CNT" ] || [ "$CNT" = "0" ]; then
  if git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
    CNT=$(git rev-list "origin/$BRANCH..HEAD" 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# upstream もリモートブランチもない場合は表示しない
[ -n "$CNT" ] && [ "$CNT" != "0" ] && printf '↑%s' "$CNT"
