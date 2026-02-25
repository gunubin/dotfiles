---
name: cc-debate
description: |
  賛成派vs反対派のディベートを自動で実行する。tmux paneを2つ作成し、
  Claude Codeを起動して並行ディベートを行い、結果をまとめる。
allowed-tools: Bash, Read, Write
argument-hint: "\"<topic>\" [--max-rounds <N>]"
disable-model-invocation: true
---

# cc-debate

## 引数

| 引数 | 説明 |
|------|------|
| `"<topic>"` | ディベートのトピック（必須） |
| `--max-rounds <N>` | 最大ラウンド数（省略可。デフォルト: `3`。各ラウンドで賛成・反対が同時に主張） |

## 実行手順

1. **引数パース**
   - `"<topic>"`: 必須。引用符内のテキスト、または `--` オプション以外の残り引数をトピックとする
   - `--max-rounds`: 任意。デフォルト `3`（各ラウンドで賛成・反対が並行して主張するため、計6つの主張）
   - topic が空 → エラー「ディベートのトピックを指定してください」

2. **tmux pane 作成**（1つの Bash コマンドで実行）
   ```bash
   PRO_PANE=$(tmux split-window -h -P -F "#{pane_id}" -d -t "$TMUX_PANE") && \
   CON_PANE=$(tmux split-window -v -P -F "#{pane_id}" -d -t "$PRO_PANE") && \
   echo "PRO=$PRO_PANE CON=$CON_PANE"
   ```
   出力から PRO と CON の pane ID をパースする。レイアウト:
   ```
   [Moderator] [Pro ]
               [Con ]
   ```

3. **Claude Code 起動**（1つの Bash コマンドで実行）
   ```bash
   tmux send-keys -t "$PRO_PANE" "cc" Enter && \
   tmux send-keys -t "$CON_PANE" "cc" Enter
   ```

4. **pane-state.json ポーリング**（最大60秒、2秒間隔）
   ```bash
   for i in $(seq 1 30); do
     if jq -e --arg pro "$PRO_PANE" --arg con "$CON_PANE" \
       '.[$pro] and .[$con]' ~/.claude/pane-state.json 2>/dev/null; then
       echo "READY"; exit 0
     fi
     sleep 2
   done
   echo "TIMEOUT"; exit 1
   ```
   - `READY` → 続行
   - `TIMEOUT` → エラー「Claude Code の起動がタイムアウトしました。pane を手動で確認してください」

5. **セッション準備**
   - `$TMUX_PANE` 環境変数で自分の pane ID を取得（Bash: `echo $TMUX_PANE`）
   - セッション ID 生成（Bash）:
     ```bash
     echo "cc-debate-$(date +%Y%m%d-%H%M%S)-$(head -c2 /dev/urandom | xxd -p | head -c4)"
     ```
   - `mkdir -p ~/.claude/dialogues`（Bash）

6. **セッションファイル作成**（3ファイル）
   - `claude/.claude/skills/cc-debate/session-template.md` を Read で読む（このファイルのスキルディレクトリ内のテンプレート）
   - テンプレートの場所: このSKILL.mdと同じディレクトリの `session-template.md`
   - 以下のプレースホルダーを実際の値に置換して **メインファイル** `~/.claude/dialogues/{session-id}.md` に Write で書き出す:
     - `{{SESSION_ID}}` → セッション ID
     - `{{TOPIC}}` → トピックテキスト
     - `{{PANE_MODERATOR}}` → 自分の pane ID（`$TMUX_PANE`）
     - `{{PANE_PRO}}` → 賛成派の pane ID
     - `{{PANE_CON}}` → 反対派の pane ID
     - `{{MAX_ROUNDS}}` → max-rounds の値
   - **賛成派ファイル** `~/.claude/dialogues/{session-id}-pro.md` を Write で作成:
     ```markdown
     # 賛成派の主張: {session-id}

     > トピック: {topic}

     ```
   - **反対派ファイル** `~/.claude/dialogues/{session-id}-con.md` を Write で作成:
     ```markdown
     # 反対派の主張: {session-id}

     > トピック: {topic}

     ```

7. **賛成派・反対派の両方にプロンプトを同時送信**（**2つの Bash コマンドを並列実行すること**）

   賛成派（Bash）:
   ```bash
   tmux send-keys -t "{pane_pro}" -l -- '~/.claude/dialogues/{session-id}.md を Read で読んでください。あなたは賛成派です。参加ルールに従い、相手のファイル ~/.claude/dialogues/{session-id}-con.md を Read で確認し、自分のファイル ~/.claude/dialogues/{session-id}-pro.md に Round 1 として賛成の立場からの主張を追記してから /cc-debate-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_pro}" Enter
   ```

   反対派（Bash）:
   ```bash
   tmux send-keys -t "{pane_con}" -l -- '~/.claude/dialogues/{session-id}.md を Read で読んでください。あなたは反対派です。参加ルールに従い、相手のファイル ~/.claude/dialogues/{session-id}-pro.md を Read で確認し、自分のファイル ~/.claude/dialogues/{session-id}-con.md に Round 1 として反対の立場からの主張を追記してから /cc-debate-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_con}" Enter
   ```

   - プロンプト内のシングルクォートは `'\''` にエスケープすること

8. **結果報告**: 以下を報告
   - セッション ID
   - メインファイル: `~/.claude/dialogues/{session-id}.md`
   - 賛成派ファイル: `~/.claude/dialogues/{session-id}-pro.md`
   - 反対派ファイル: `~/.claude/dialogues/{session-id}-con.md`
   - トピック
   - モデレーター pane: `$TMUX_PANE`
   - 賛成派 pane: `{pane_pro}`
   - 反対派 pane: `{pane_con}`
   - 最大ラウンド数
   - 「ディベートを開始しました。賛成派・反対派が並行して主張します。終了後、自動的にまとめ依頼が届きます。」

## 注意事項

- トピック文字列は send-keys に含めない設計。send-keys で送るのは固定テンプレート文（「ファイルを Read で読んでください…」）のみ。トピックはセッションファイルに Write されるだけである
- pane-state.json のポーリングでは `jq` を使用する。Claude Code が起動して hook が発火するまで待つ
- Claude Code の起動コマンドは `cc`（fish 関数）を使用する
- 賛成派・反対派へのプロンプト送信は並列で行うこと（順次送信しない）
