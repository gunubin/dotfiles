---
name: send-prompt
description: |
  別のtmux paneで実行中のClaude Codeにプロンプトを送信する。
  「他のpaneに指示を送りたい」「別のClaude Codeに依頼したい」時に使用。
allowed-tools: Bash, Read
argument-hint: "<pane-id> <prompt>"
disable-model-invocation: true
---

# send-prompt

## 引数

| 引数 | 説明 |
|------|------|
| `$0` | pane ID（数字部分のみ。例: `60`） |
| `$1...` | 送信するプロンプトテキスト（残り全部） |

## 実行手順

1. **引数パース**
   - `$0` を pane ID として取得（数字のみ許可）
   - 残りを結合してプロンプトテキストとする
   - どちらかが空ならエラーメッセージを出して終了

2. **JSON 確認**: `$HOME/.claude/pane-state.json` を Read で読む
   - ファイルが存在しない → 「pane-state.json が見つかりません。対象 pane で Claude Code が起動していることを確認してください」
   - `%{ID}` のエントリがない → 「pane %{ID} に Claude Code セッションが見つかりません」と表示し、存在するエントリ一覧を表示
3. **送信**: 以下の Bash コマンドを実行
   ```bash
   tmux send-keys -t "%{ID}" -l -- '{プロンプトテキスト}'
   sleep 0.3
   tmux send-keys -t "%{ID}" Enter
   ```
   - プロンプト内のシングルクォートは `'\''` にエスケープすること

4. **結果報告**: 「pane %{ID} ({dir}) にプロンプトを送信しました」と報告

## 注意事項

- pane ID は `%` なしの数字で指定する（ユーザーが `%` 付きで渡した場合は `%` を除去する）
- 処理中でもそのまま送信する（確認不要）
