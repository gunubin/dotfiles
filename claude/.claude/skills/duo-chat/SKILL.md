---
name: duo-chat
description: |
  別のtmux paneのClaude Codeとピンポン式の対話セッションを開始する。
  コードレビュー、設計議論など2インスタンス間の対話に使用。
allowed-tools: Bash, Read, Write
argument-hint: "<pane-id> \"<topic>\" [--role-a <role>] [--role-b <role>] [--max-rounds <N>]"
disable-model-invocation: true
---

# duo-chat

## 引数

| 引数 | 説明 |
|------|------|
| `<pane-id>` | 相手の pane ID（数字部分のみ。例: `60`） |
| `"<topic>"` | 対話トピック（引用符で囲む） |
| `--role-a <role>` | 自分（Pane A）のロール名（省略可。デフォルト: なし） |
| `--role-b <role>` | 相手（Pane B）のロール名（省略可。デフォルト: なし） |
| `--max-rounds <N>` | 最大ラウンド数（省略可。デフォルト: `10`） |

## 前提条件

- `$HOME/.claude/pane-state.json` が存在すること。このファイルは `~/.claude/scripts/tmux-state.sh` hook により自動管理される（SessionStart/UserPromptSubmit/PreToolUse/Stop/SessionEnd イベントで更新）。対象 pane で Claude Code が起動していれば自動的にエントリが作成される。

## 実行手順

1. **引数パース**
   - `<pane-id>`: 必須。数字のみ。`%` 付きで渡された場合は `%` を除去する
   - `"<topic>"`: 必須。引用符内のテキスト、または残りの引数をトピックとする
   - `--role-a`, `--role-b`: 任意。指定がなければ空文字列
   - `--max-rounds`: 任意。デフォルト `10`
   - pane ID が空 → エラー「相手の pane ID を指定してください」
   - topic が空 → エラー「対話トピックを指定してください」

2. **JSON 確認**: `$HOME/.claude/pane-state.json` を Read で読む
   - ファイルが存在しない → 「pane-state.json が見つかりません。対象 pane で Claude Code が起動していることを確認してください」
   - `%{ID}` のエントリがない → 「pane %{ID} に Claude Code セッションが見つかりません」と表示し、存在するエントリ一覧を表示

3. **セッション準備**
   - `$TMUX_PANE` 環境変数で自分の pane ID を取得（Bash: `echo $TMUX_PANE`）
   - セッション ID 生成（Bash）:
     ```bash
     echo "duo-$(date +%Y%m%d-%H%M%S)-$(head -c2 /dev/urandom | xxd -p | head -c4)"
     ```
   - `mkdir -p ~/.claude/dialogues`（Bash）

4. **セッションファイル作成**
   - `claude/.claude/skills/duo-chat/session-template.md` を Read で読む（このファイルのスキルディレクトリ内のテンプレート）
   - テンプレートの場所: このSKILL.mdと同じディレクトリの `session-template.md`
   - 以下のプレースホルダーを実際の値に置換して `~/.claude/dialogues/{session-id}.md` に Write で書き出す:
     - `{{SESSION_ID}}` → セッション ID
     - `{{TOPIC}}` → トピックテキスト
     - `{{PANE_A}}` → 自分の pane ID（`%` 付き、例: `%44`）
     - `{{PANE_B}}` → 相手の pane ID（`%` 付き、例: `%60`）
     - `{{ROLE_A}}` → role-a の値（未指定なら空文字列）
     - `{{ROLE_B}}` → role-b の値（未指定なら空文字列）
     - `{{MAX_ROUNDS}}` → max-rounds の値

5. **相手 pane にプロンプト送信**: 以下の Bash コマンドを実行（**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）
   ```bash
   tmux send-keys -t "%{ID}" -l -- '~/.claude/dialogues/{session-id}.md を Read で読んでください。あなたはPane Bです。参加ルールに従い、Round 1として応答をファイル末尾に追記し、/duo-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "%{ID}" Enter
   ```
   - プロンプト内のシングルクォートは `'\''` にエスケープすること

6. **結果報告**: 以下を報告
   - セッション ID
   - ファイルパス: `~/.claude/dialogues/{session-id}.md`
   - トピック
   - 相手 pane: `%{ID}`
   - 最大ラウンド数
   - 「相手 pane にプロンプトを送信しました。相手の応答後、自動的にあなたにも通知が届きます。」

## 注意事項

- pane ID は `%` なしの数字で指定する（ユーザーが `%` 付きで渡した場合は `%` を除去する）
- 処理中でもそのまま送信する（確認不要）
- テンプレートファイルのパスは、このスキル自体の場所（`duo-chat/`ディレクトリ）を基準に解決する
- トピック文字列は send-keys に含めない設計。send-keys で送るのは固定テンプレート文（「ファイルを Read で読んでください…」）のみ。トピックはセッションファイルに Write されるだけである
