#!/bin/bash
# file-suggestion.sh - ハイブリッドファジー検索（Git変更優先）
# 優先順位: Git変更ファイル > git追跡ファイル > 全ファイル
# 依存: fd, fzf, jq

set -eu

query=$(cat | jq -r '.query // empty')
cd "${CLAUDE_PROJECT_DIR:-.}"

{
  # 1. Git変更ファイル（staged + unstaged + untracked）— 最優先
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    git diff --name-only 2>/dev/null || true
    git diff --name-only --cached 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null
  fi

  # 2. 全追跡ファイル（git ls-filesはインデックス参照で高速）
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    git ls-files 2>/dev/null
  else
    # git外ではfdにフォールバック
    fd --type f --hidden --exclude .git
  fi
} | awk 'NF && !seen[$0]++' | if [ -n "$query" ]; then fzf --filter="$query" --no-sort; else cat; fi | head -15
