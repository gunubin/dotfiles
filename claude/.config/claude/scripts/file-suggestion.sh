#!/bin/bash
# file-suggestion.sh - ハイブリッドファジー検索（Git変更 + mtime順）
# 優先順位: Git変更ファイル > mtime降順の全ファイル
# 依存: fd, fzf, jq

set -eu

query=$(cat | jq -r '.query')
cd "${CLAUDE_PROJECT_DIR:-.}"

{
  # 1. Git変更ファイル（staged + unstaged + untracked）— 最優先
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    git diff --name-only HEAD 2>/dev/null
    git diff --name-only --cached 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  fi

  # 2. 全ファイルをmtime降順（最近変更されたファイルが上位）
  # sed で先頭の ./ を除去してGitパスと形式を統一
  fd --type f --hidden --follow --exclude .git \
    --exec stat -f '%m %N' {} 2>/dev/null \
    | sort -rn | cut -d' ' -f2- | sed 's|^\./||'
} | awk 'NF && !seen[$0]++' | fzf --filter="$query" | head -15
