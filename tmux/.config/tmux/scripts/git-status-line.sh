#!/bin/sh
# git-status-line.sh — tmux status-left 用の git 情報を一括出力
# 出力: "branch*↑N" （gitリポジトリ内）または空文字列（リポジトリ外）
# rev-parse / diff / unpushed を1プロセスに統合し、#() キャッシュで効率化
cd "$1" 2>/dev/null || exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

# dirty check
DIRTY=""
git diff --quiet 2>/dev/null || DIRTY="*"

# unpushed commits
CNT=$(git rev-list @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ')
if [ -z "$CNT" ] || [ "$CNT" = "0" ]; then
  if git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
    CNT=$(git rev-list "origin/$BRANCH..HEAD" 2>/dev/null | wc -l | tr -d ' ')
  fi
fi
UNPUSHED=""
[ -n "$CNT" ] && [ "$CNT" != "0" ] && UNPUSHED="↑${CNT}"

printf '%s%s%s' "$BRANCH" "$DIRTY" "$UNPUSHED"
