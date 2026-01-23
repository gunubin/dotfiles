#!/bin/bash
# セッション評価スクリプト - 継続学習システム
#
# Claude Codeセッション終了時に実行され、再利用可能なパターンを抽出する
#
# 使用方法: Stopフックとして設定
# 環境変数: CLAUDE_TRANSCRIPT_PATH - セッショントランスクリプトのパス

set -e

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
LEARNED_SKILLS_PATH="${HOME}/.claude/skills/learned"

# 設定読み込み
if [ -f "$CONFIG_FILE" ]; then
    MIN_SESSION_LENGTH=$(jq -r '.min_session_length // 10' "$CONFIG_FILE")
else
    MIN_SESSION_LENGTH=10
fi

# 学習スキル保存先ディレクトリを作成
mkdir -p "$LEARNED_SKILLS_PATH"

# トランスクリプトパスの確認
if [ -z "$CLAUDE_TRANSCRIPT_PATH" ]; then
    echo "[継続学習] トランスクリプトパスが設定されていません"
    exit 0
fi

if [ ! -f "$CLAUDE_TRANSCRIPT_PATH" ]; then
    echo "[継続学習] トランスクリプトファイルが見つかりません: $CLAUDE_TRANSCRIPT_PATH"
    exit 0
fi

# セッションメッセージ数をカウント
MESSAGE_COUNT=$(jq '[.[] | select(.role == "user")] | length' "$CLAUDE_TRANSCRIPT_PATH" 2>/dev/null || echo "0")

echo "[継続学習] セッションメッセージ数: $MESSAGE_COUNT"

# 最小セッション長のチェック
if [ "$MESSAGE_COUNT" -lt "$MIN_SESSION_LENGTH" ]; then
    echo "[継続学習] セッションが短すぎます（最小: $MIN_SESSION_LENGTH）。スキップします。"
    exit 0
fi

echo "[継続学習] パターン検出を実行中..."
echo "[継続学習] 学習スキル保存先: $LEARNED_SKILLS_PATH"

# パターン検出のロジック（Claudeが実際に分析を行う）
# ここでは基本的な構造のみ提供
# 実際の抽出はClaude Codeが/learnコマンドで対話的に行う

echo "[継続学習] セッション評価完了"
echo "[継続学習] '/learn' コマンドでパターンを手動抽出できます"
