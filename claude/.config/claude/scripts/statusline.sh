#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
USED=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | xargs printf "%.0f")
SESSION_ID=$(echo "$input" | jq -r '.session_id')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path')

# タイトル取得（summary → firstPrompt）
TITLE=""
if [ -n "$TRANSCRIPT_PATH" ] && [ "$TRANSCRIPT_PATH" != "null" ]; then
    INDEX_PATH="$(dirname "$TRANSCRIPT_PATH")/sessions-index.json"
    if [ -f "$INDEX_PATH" ]; then
        TITLE=$(jq -r --arg sid "$SESSION_ID" '.entries[] | select(.sessionId == $sid) | .summary // empty' "$INDEX_PATH" 2>/dev/null)
        if [ -z "$TITLE" ]; then
            TITLE=$(jq -r --arg sid "$SESSION_ID" '.entries[] | select(.sessionId == $sid) | .firstPrompt // empty' "$INDEX_PATH" 2>/dev/null | sed 's/<[^>]*>//g' | tr '\n' ' ')
        fi
    fi
fi
# 30文字に切り詰め
TITLE=$(echo "$TITLE" | head -c 30 | sed 's/[[:space:]]*$//')
[ ${#TITLE} -ge 30 ] && TITLE="${TITLE}..."

# 最後のプロンプト取得
LAST_PROMPT=""
if [ -f ~/.claude/prompts/history.tsv ]; then
    LAST_PROMPT=$(grep "^${SESSION_ID}	" ~/.claude/prompts/history.tsv | tail -1 | cut -f2- | tr '\n' ' ')
fi
# 30文字に切り詰め
LAST_PROMPT=$(echo "$LAST_PROMPT" | head -c 30 | sed 's/[[:space:]]*$//')
[ ${#LAST_PROMPT} -ge 30 ] && LAST_PROMPT="${LAST_PROMPT}..."

echo "[$MODEL] ${USED}% | ${TITLE}"
echo "> ${LAST_PROMPT}"
