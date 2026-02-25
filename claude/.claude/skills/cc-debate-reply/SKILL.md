---
name: cc-debate-reply
description: |
  cc-debateディベートセッションの次ラウンドを送信する。
  主張をファイルに追記した後に実行する。
allowed-tools: Bash, Read
argument-hint: "<session-id>"
---

# cc-debate-reply

## 引数

| 引数 | 説明 |
|------|------|
| `<session-id>` | セッション ID（省略可。省略時は最新のディベートセッションファイルを使用） |

## 前提条件

- `$HOME/.claude/pane-state.json` が存在すること。このファイルは `~/.claude/scripts/tmux-state.sh` hook により自動管理される（SessionStart/UserPromptSubmit/PreToolUse/Stop/SessionEnd イベントで更新）。対象 pane で Claude Code が起動していれば自動的にエントリが作成される。

## 実行手順

1. **引数パース**
   - `<session-id>` が指定されていればそれを使用
   - 省略時は最新のセッションファイルを特定（Bash）:
     ```bash
     ls -t ~/.claude/dialogues/cc-debate-*.md | head -1
     ```
     ファイル名からセッション ID を抽出する（`cc-debate-` から `.md` を除いた部分）
   - ファイルが見つからない → エラー「アクティブなディベートセッションが見つかりません」

2. **セッションファイル読み込み**: `~/.claude/dialogues/{session-id}.md` を Read で読む

3. **YAML フロントマターから状態取得**
   - `status`: セッション状態
   - `current_round`: cc-debate-reply の実行回数（`## Round N` のヘッダー番号とは独立した内部カウンター）
   - `max_rounds`: 最大ラウンド数
   - `pane_moderator`: モデレーターの pane ID
   - `pane_pro`: 賛成派の pane ID
   - `pane_con`: 反対派の pane ID

4. **終了チェック**（以下のいずれかに該当する場合）
   - `status` が `active` でない → 「このセッションは既に終了しています（status: {status}）」
   - ファイル内の最後の `## Round` セクション内に `[CONCLUDED]` が含まれている → 合意による終了
   - `current_round >= max_rounds` → ラウンド上限による終了

5. **終了処理**（上記チェックに該当した場合）
   - `[CONCLUDED]` の場合: フロントマターの status を更新（Bash）
     ```bash
     sed -i '' 's/^status: active$/status: concluded/' ~/.claude/dialogues/{session-id}.md
     ```
   - ラウンド上限の場合: フロントマターの status を更新（Bash）
     ```bash
     sed -i '' 's/^status: active$/status: timeout/' ~/.claude/dialogues/{session-id}.md
     ```
   - **モデレーター pane にまとめ依頼を送信**（Bash。**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
     ```bash
     tmux send-keys -t "{pane_moderator}" -l -- '~/.claude/dialogues/{session-id}.md のディベートが終了しました。ファイルを Read で全文読み、賛成派と反対派の主張を公平にまとめてください。主要な論点、各派の強い主張、共通点・相違点を整理してください。' && sleep 0.3 && tmux send-keys -t "{pane_moderator}" Enter
     ```
   - プロンプト内のシングルクォートは `'\''` にエスケープすること
   - 結果報告: 「ディベートセッション {session-id} が終了しました（理由: {合意/ラウンド上限}）。モデレーター pane {pane_moderator} にまとめ依頼を送信しました」
   - **ここで終了。それ以上の送信なし。**

6. **継続処理**（終了条件に該当しない場合）
   - `current_round` をインクリメント（Bash）:
     ```bash
     sed -i '' 's/^current_round: {N}$/current_round: {N+1}/' ~/.claude/dialogues/{session-id}.md
     ```
   - 送信先 pane 決定:
     - 自分の pane ID を取得（Bash: `echo $TMUX_PANE`）
     - `$TMUX_PANE` が `pane_pro` と一致 → 送信先は `pane_con`（次は反対派のターン）
     - `$TMUX_PANE` が `pane_con` と一致 → 送信先は `pane_pro`（次は賛成派のターン）
     - どちらにも一致しない → エラー「このセッションの参加者ではありません」
   - `$HOME/.claude/pane-state.json` を Read で送信先 pane の存在を確認
     - エントリがない → 「送信先 pane {ID} に Claude Code セッションが見つかりません」

   - **送信先が pane_con（反対派）の場合**（Bash。**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
     ```bash
     tmux send-keys -t "{pane_con}" -l -- '~/.claude/dialogues/{session-id}.md のディベート、賛成派の主張が届きました。ファイルを Read で読み、反対派として Round {N+1} の反論を追記して /cc-debate-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_con}" Enter
     ```

   - **送信先が pane_pro（賛成派）の場合**（Bash。**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
     ```bash
     tmux send-keys -t "{pane_pro}" -l -- '~/.claude/dialogues/{session-id}.md のディベート、反対派の主張が届きました。ファイルを Read で読み、賛成派として Round {N+1} の反論を追記して /cc-debate-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_pro}" Enter
     ```

   - プロンプト内のシングルクォートは `'\''` にエスケープすること
   - 結果報告: 「Round {N+1} のプロンプトを pane {送信先} に送信しました」

## 注意事項

- このスキルは主張の追記を行わない。ファイルへの主張追記はスキル実行前に通常のClaude Code操作で行うこと
- `sed` でフロントマターを更新するため Write ツールは不要
- 終了時はモデレーター pane にまとめ依頼を送信する（cc-chat-reply と異なる点）
