---
name: cc-chat-reply
description: |
  cc-chat対話セッションの次ラウンドを送信する。
  対話セッション中に応答をファイルに追記した後に実行する。
allowed-tools: Bash, Read
argument-hint: "<session-id>"
---

# cc-chat-reply

## 引数

| 引数 | 説明 |
|------|------|
| `<session-id>` | セッション ID（省略可。省略時は最新のセッションファイルを使用） |

## 前提条件

- `$HOME/.claude/pane-state.json` が存在すること。このファイルは `~/.claude/scripts/tmux-state.sh` hook により自動管理される（SessionStart/UserPromptSubmit/PreToolUse/Stop/SessionEnd イベントで更新）。対象 pane で Claude Code が起動していれば自動的にエントリが作成される。

## 実行手順

1. **引数パース**
   - `<session-id>` が指定されていればそれを使用
   - 省略時は最新のセッションファイルを特定（Bash）:
     ```bash
     ls -t ~/.claude/dialogues/cc-chat-*.md | head -1
     ```
     ファイル名からセッション ID を抽出する（`cc-chat-` から `.md` を除いた部分）
   - ファイルが見つからない → エラー「アクティブな対話セッションが見つかりません」

2. **セッションファイル読み込み**: `~/.claude/dialogues/{session-id}.md` を Read で読む

3. **YAML フロントマターから状態取得**
   - `status`: セッション状態
   - `current_round`: cc-chat-reply の実行回数（`## Round N` のヘッダー番号とは独立した内部カウンター）
   - `max_rounds`: 最大ラウンド数
   - `pane_a`: Pane A の ID
   - `pane_b`: Pane B の ID

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
   - 結果報告: 「対話セッション {session-id} が終了しました（理由: {合意/ラウンド上限}）」
   - **送信はしない。ここで終了。**

6. **継続処理**（終了条件に該当しない場合）
   - `current_round` をインクリメント（Bash）:
     ```bash
     sed -i '' 's/^current_round: {N}$/current_round: {N+1}/' ~/.claude/dialogues/{session-id}.md
     ```
   - 送信先 pane 決定:
     - 自分の pane ID を取得（Bash: `echo $TMUX_PANE`）
     - `$TMUX_PANE` が `pane_a` と一致 → 送信先は `pane_b`
     - `$TMUX_PANE` が `pane_b` と一致 → 送信先は `pane_a`
     - どちらにも一致しない → エラー「このセッションの参加者ではありません」
   - `$HOME/.claude/pane-state.json` を Read で送信先 pane の存在を確認
     - エントリがない → 「送信先 pane {ID} に Claude Code セッションが見つかりません」
   - 送信（Bash。**以下3行は必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
     ```bash
     tmux send-keys -t "{送信先pane}" -l -- '~/.claude/dialogues/{session-id}.md の対話セッション Round {N+1} です。ファイルを Read で読み、参加ルールに従って応答を追記し、/cc-chat-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{送信先pane}" Enter
     ```
     - プロンプト内のシングルクォートは `'\''` にエスケープすること
   - 結果報告: 「Round {N+1} のプロンプトを pane {送信先} に送信しました」

## 注意事項

- このスキルは応答の追記を行わない。ファイルへの応答追記はスキル実行前に通常のClaude Code操作で行うこと
- `sed` でフロントマターを更新するため Write ツールは不要
