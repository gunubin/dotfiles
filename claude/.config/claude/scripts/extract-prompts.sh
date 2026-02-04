#!/bin/bash
# Claude Code プロンプト抽出スクリプト
#
# 使い方:
#   ~/.claude/scripts/extract-prompts.sh           # 前回実行からの差分
#   ~/.claude/scripts/extract-prompts.sh --all     # 全期間（初回用）
#   ~/.claude/scripts/extract-prompts.sh --since 2026-01-01   # 指定日以降
#   ~/.claude/scripts/extract-prompts.sh --days 7  # 過去N日間
#
# 前回実行からの差分を取得し、AIで課題や発見を抽出してObsidianに保存
# 保存形式: 週ごと（月曜始まり）、年ディレクトリ

# Note: set -e を使わない（jqが空結果を返す、パイプラインで終了コードが変わるなどの問題を避けるため）

# === 設定 ===
OBSIDIAN_BASE="$HOME/Documents/notes/020_Ideas/Claude Prompts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAST_RUN_FILE="$SCRIPT_DIR/.last-extract-time"
TMP_DIR="/tmp/claude-prompts-$$"

# === 引数処理 ===
SINCE_DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      # 全期間: 2020年1月1日から（十分古い日付）
      SINCE_DATE="2020-01-01T00:00:00"
      shift
      ;;
    --since)
      # 指定日以降（日付形式バリデーション）
      if [[ ! "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "エラー: 日付はYYYY-MM-DD形式で指定してください（例: 2026-01-01）"
        exit 1
      fi
      SINCE_DATE="${2}T00:00:00"
      shift 2
      ;;
    --days)
      # 過去N日間
      SINCE_DATE=$(date -v-${2}d +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d "${2} days ago" +%Y-%m-%dT%H:%M:%S)
      shift 2
      ;;
    -h|--help)
      echo "使い方:"
      echo "  $0           # 前回実行からの差分"
      echo "  $0 --all     # 全期間（初回用）"
      echo "  $0 --since 2026-01-01   # 指定日以降"
      echo "  $0 --days 7  # 過去N日間"
      exit 0
      ;;
    *)
      echo "不明なオプション: $1"
      echo "$0 --help でヘルプを表示"
      exit 1
      ;;
  esac
done

# === 関数: 日付から週番号とファイル名を取得 ===
get_week_file() {
  local date_str="$1"  # YYYY-MM-DD形式

  # 日付形式のバリデーション
  if [[ ! "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: Invalid date format: $date_str" >&2
    return 1
  fi

  # macOSのdateコマンドで週番号（月曜始まり）を取得
  # %V = ISO週番号, %u = 曜日（1=月曜）
  local week_num=$(date -j -f "%Y-%m-%d" "$date_str" "+%V" 2>/dev/null)

  # 週の月曜日と日曜日を計算
  local day_of_week=$(date -j -f "%Y-%m-%d" "$date_str" "+%u" 2>/dev/null)
  local days_to_monday=$((day_of_week - 1))
  local days_to_sunday=$((7 - day_of_week))

  local monday=$(date -j -v-${days_to_monday}d -f "%Y-%m-%d" "$date_str" "+%m-%d" 2>/dev/null)
  local sunday=$(date -j -v+${days_to_sunday}d -f "%Y-%m-%d" "$date_str" "+%m-%d" 2>/dev/null)

  # 年をまたぐ場合の処理（週の月曜が前年の場合）
  local monday_year=$(date -j -v-${days_to_monday}d -f "%Y-%m-%d" "$date_str" "+%Y" 2>/dev/null)

  echo "${monday_year}/W${week_num}_${monday}_to_${sunday}.md"
}

# === クリーンアップ ===
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# === 初期化 ===
mkdir -p "$OBSIDIAN_BASE"
mkdir -p "$TMP_DIR"

# 開始日時を決定
if [ -n "$SINCE_DATE" ]; then
  # 引数で指定された場合
  LAST_RUN="$SINCE_DATE"
  echo "指定期間: $LAST_RUN 以降"
elif [ -f "$LAST_RUN_FILE" ]; then
  # 前回実行時刻がある場合
  LAST_RUN=$(cat "$LAST_RUN_FILE")
  echo "前回実行: $LAST_RUN"
else
  # 初回実行: 全期間取得
  LAST_RUN="2020-01-01T00:00:00"
  echo "初回実行: 全期間を取得"
fi
echo "抽出開始..."

# === プロンプト収集 ===
# Note: サブシェル問題を避けるため、findの結果をファイルに出力してから処理
find ~/.claude/projects -name "*.jsonl" -type f 2>/dev/null > "$TMP_DIR/logfiles.txt"

while read logfile; do
  # ファイルの更新時刻を確認
  file_mtime=$(stat -f %Sm -t %Y-%m-%dT%H:%M:%S "$logfile" 2>/dev/null || stat -c %y "$logfile" 2>/dev/null | cut -d'.' -f1 | tr ' ' 'T')

  if [[ "$file_mtime" > "$LAST_RUN" ]] || [[ "$file_mtime" == "$LAST_RUN" ]]; then
    # ユーザープロンプトを抽出（ノイズ除去）- 日付付きで出力
    # Note: timestampは "2026-02-02T22:56:03.048Z" 形式（UTC）
    # JSTに変換するため +9時間（32400秒）を加算
    # 1. 通常のプロンプト
    jq -r --arg last "$LAST_RUN" '
      select(.type == "user") |
      select(.isMeta != true) |
      select(.message.content | type == "string") |
      select(.message.content | startswith("<") | not) |
      select(.message.content | length > 15) |
      (.timestamp | split(".")[0]) as $clean_ts |
      select($clean_ts > $last) |
      (.timestamp | split(".")[0] | strptime("%Y-%m-%dT%H:%M:%S") | mktime + 32400 | strftime("%Y-%m-%d")) as $local_date |
      "\($local_date)|\(.message.content | gsub("\n"; " ") | .[0:300])"
    ' "$logfile" 2>/dev/null >> "$TMP_DIR/raw.txt"

    # 2. AskUserQuestionの回答（質問と回答のペアを抽出）
    jq -r --arg last "$LAST_RUN" '
      select(.type == "user") |
      select(.message.content | type == "array") |
      (.timestamp | split(".")[0]) as $clean_ts |
      select($clean_ts > $last) |
      (.timestamp | split(".")[0] | strptime("%Y-%m-%dT%H:%M:%S") | mktime + 32400 | strftime("%Y-%m-%d")) as $local_date |
      .message.content[] |
      select(.type == "tool_result") |
      select(.content | type == "string") |
      select(.content | startswith("User has answered your questions:")) |
      (.content | gsub("User has answered your questions: "; "") | gsub("\\. You can now continue.*"; "")) as $qa_content |
      select($qa_content | length > 5) |
      "\($local_date)|[Q&A] \($qa_content)"
    ' "$logfile" 2>/dev/null >> "$TMP_DIR/raw.txt"
  fi
done < "$TMP_DIR/logfiles.txt"

# 重複除去
sort -u "$TMP_DIR/raw.txt" > "$TMP_DIR/unique.txt"

PROMPT_COUNT=$(wc -l < "$TMP_DIR/unique.txt" | tr -d ' ')
echo "抽出されたプロンプト数: $PROMPT_COUNT"

if [ "$PROMPT_COUNT" -eq 0 ]; then
  echo "新しいプロンプトはありません"
  # 現在時刻を記録
  date +%Y-%m-%dT%H:%M:%S > "$LAST_RUN_FILE"
  exit 0
fi

# === 週ごとにファイルを振り分け（bash 3.2互換: 一時ファイルベース） ===
echo "週ごとにグループ化中..."

while IFS='|' read -r date_part prompt_text; do
  if [ -n "$date_part" ] && [ -n "$prompt_text" ]; then
    week_file=$(get_week_file "$date_part")
    # 安全なファイル名に変換（/を_に）
    safe_filename=$(echo "$week_file" | tr '/' '_')

    # 週ファイル名を記録
    echo "$week_file" >> "$TMP_DIR/week_files.txt"

    # プロンプトを週ごとのファイルに追記
    echo "[$date_part] $prompt_text" >> "$TMP_DIR/week_${safe_filename}"
  fi
done < "$TMP_DIR/unique.txt"

# ユニークな週ファイル一覧
sort -u "$TMP_DIR/week_files.txt" > "$TMP_DIR/week_files_unique.txt"

# === 各週ファイルに対してAI判定と保存 ===
while read week_file; do
  safe_filename=$(echo "$week_file" | tr '/' '_')
  prompts_file="$TMP_DIR/week_${safe_filename}"

  if [ ! -f "$prompts_file" ]; then
    continue
  fi

  prompts_for_week=$(cat "$prompts_file")

  # ディレクトリ作成
  output_path="$OBSIDIAN_BASE/$week_file"
  output_dir=$(dirname "$output_path")
  mkdir -p "$output_dir"

  echo ""
  echo "=== 処理中: $week_file ==="

  # AI判定
  AI_RESULT=$(cat <<EOF | claude --print --model haiku
以下はClaude Codeへのプロンプト一覧です。
課題や発見（困りごと、感情、要望、質問、試行錯誤）を抽出してください。
単なる指示（「修正して」「続けて」等）は除外してください。

---
$prompts_for_week
---

出力形式（Markdown）:
## 課題と発見

- 〇〇
- 〇〇

該当するものがなければ「該当なし」と出力してください。
EOF
)

  # 保存
  if [ -f "$output_path" ]; then
    # 既存ファイルに追記
    echo "" >> "$output_path"
    echo "---" >> "$output_path"
    echo "" >> "$output_path"
    echo "## $(date +%Y-%m-%d' '%H:%M) 抽出分" >> "$output_path"
    echo "" >> "$output_path"
    echo "$AI_RESULT" >> "$output_path"
  else
    # 新規作成
    # ファイル名からWeek情報を抽出
    week_info=$(basename "$week_file" .md)
    cat > "$output_path" << EOF
# Claude Code プロンプト $week_info

$AI_RESULT
EOF
  fi

  echo "保存先: $output_path"
  echo ""
  echo "--- 抽出結果 ---"
  echo "$AI_RESULT"
done < "$TMP_DIR/week_files_unique.txt"

# 現在時刻を記録
date +%Y-%m-%dT%H:%M:%S > "$LAST_RUN_FILE"

echo ""
echo "=== 完了 ==="
