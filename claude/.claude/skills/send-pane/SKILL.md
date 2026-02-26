---
name: send-pane
description: |
  タスクを実行し、結果を別のtmux paneのClaude Codeに送信する。
  「レビューして結果を送りたい」「テスト書いて結果を渡したい」時に使用。
allowed-tools: Bash, Read, Write, Grep, Glob, Task
argument-hint: "<pane-id> <タスク指示>"
disable-model-invocation: false
---

# send-pane

## 引数

| 引数 | 説明 |
|------|------|
| `$0` | pane ID（必須。数字部分のみ。例: `60`） |
| `$1...` | 実行するタスクの指示（残り全部。例: `レビューして`、`テスト書いて`） |

## 実行手順

1. **引数パース**
   - `$0` が数字なら pane ID、残りをタスク指示とする
   - `$0` が数字でなければ、全引数をタスク指示とし、pane ID は前回と同じものを使う
   - 前回の送信先がない場合はエラー「送信先 pane ID を指定してください」
   - タスク指示が空ならエラー「タスク指示を指定してください」
   - pane ID の `%` は除去する

2. **JSON 確認**: `$HOME/.claude/pane-state.json` を Read で読む
   - ファイルが存在しない → 「pane-state.json が見つかりません。対象 pane で Claude Code が起動していることを確認してください」
   - `%{ID}` のエントリがない → 「pane %{ID} に Claude Code セッションが見つかりません」と表示し、存在するエントリ一覧を表示

3. **タスク実行**
   - ユーザーのタスク指示に従い、自分の pane で実際にタスクを実行する
   - 例: 「レビューして」→ git diff を確認してコードレビューを行う
   - 例: 「テスト書いて」→ コードを読んでテストを書く
   - タスクの内容に応じて適切なツール（Read, Grep, Glob, Task 等）を使う

4. **結果ファイル作成**
   - `mkdir -p ~/.claude/dialogues`（Bash）
   - ファイル名生成（Bash）:
     ```bash
     echo "send-pane-$(date +%Y%m%d-%H%M%S)-$(head -c2 /dev/urandom | xxd -p | head -c4)"
     ```
   - 結果を `~/.claude/dialogues/{filename}.md` に Write で書き出す
   - ファイルの形式:
     ```markdown
     # タスク結果: {タスク指示の要約}

     > 送信元: pane {自分のpane ID}
     > 実行日時: {日時}

     ## 結果

     {タスクの実行結果をここに記載}
     ```

5. **概要を作成**
   - タスク結果を1-2文で要約する

6. **相手 pane に送信**: 以下の Bash コマンドを実行
   ```bash
   tmux send-keys -t "%{ID}" -l -- '{概要}。詳細は ~/.claude/dialogues/{filename}.md を読んでください。' && sleep 0.3 && tmux send-keys -t "%{ID}" Enter
   ```
   - プロンプト内のシングルクォートは `'\''` にエスケープすること

7. **結果報告**: 以下を報告
   - 実行したタスクの概要
   - 結果ファイル: `~/.claude/dialogues/{filename}.md`
   - 送信先 pane: `%{ID}`
   - 「結果を pane %{ID} に送信しました」

## 注意事項

- pane ID は `%` なしの数字で指定する（ユーザーが `%` 付きで渡した場合は `%` を除去する）
- タスク実行がメイン。結果の送信はタスク完了後に行う
- 結果ファイルには十分な詳細を含め、相手が文脈を理解できるようにする
- 送信するプロンプトは簡潔な概要にとどめ、詳細はファイル参照とする
