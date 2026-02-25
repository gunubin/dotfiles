---
name: duo-ask-reply
description: |
  duo-askのQ&Aセッションで応答を相手paneに転送する。
  回答/追加質問をファイルに追記した後に実行する。
allowed-tools: Bash, Read
argument-hint: "<session-id>"
---

# duo-ask-reply

## 引数

| 引数 | 説明 |
|------|------|
| `<session-id>` | セッション ID（省略可。省略時は最新の Q&A セッションファイルを使用） |

## 前提条件

- `$HOME/.claude/pane-state.json` が存在すること。このファイルは `~/.claude/scripts/tmux-state.sh` hook により自動管理される（SessionStart/UserPromptSubmit/PreToolUse/Stop/SessionEnd イベントで更新）。対象 pane で Claude Code が起動していれば自動的にエントリが作成される。

## 実行手順

1. **引数パース**
   - `<session-id>` が指定されていればそれを使用
   - 省略時は最新のセッションファイルを特定（Bash）:
     ```bash
     ls -t ~/.claude/dialogues/qa-*.md | head -1
     ```
     ファイル名からセッション ID を抽出する（`qa-` から `.md` を除いた部分）
   - ファイルが見つからない → エラー「アクティブな Q&A セッションが見つかりません」

2. **セッションファイル読み込み**: `~/.claude/dialogues/{session-id}.md` を Read で読む

3. **YAML フロントマターから状態取得**
   - `status`: セッション状態
   - `current_round`: duo-ask-reply の実行回数（`## Round N` のヘッダー番号とは独立した内部カウンター）
   - `max_rounds`: 最大ラウンド数
   - `pane_a`: Pane A（質問者）の ID
   - `pane_b`: Pane B（回答者）の ID

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
   - 結果報告: 「Q&A セッション {session-id} が終了しました（理由: {解決済み/ラウンド上限}）」
   - **送信はしない。ここで終了。**

6. **継続処理**（終了条件に該当しない場合）
   - `current_round` をインクリメント（Bash）:
     ```bash
     sed -i '' 's/^current_round: {N}$/current_round: {N+1}/' ~/.claude/dialogues/{session-id}.md
     ```
   - 送信先 pane 決定:
     - 自分の pane ID を取得（Bash: `echo $TMUX_PANE`）
     - `$TMUX_PANE` が `pane_a` と一致 → 自分は質問者。送信先は `pane_b`（回答者）
     - `$TMUX_PANE` が `pane_b` と一致 → 自分は回答者。送信先は `pane_a`（質問者）
     - どちらにも一致しない → エラー「このセッションの参加者ではありません」
   - `$HOME/.claude/pane-state.json` を Read で送信先 pane の存在を確認
     - エントリがない → 「送信先 pane {ID} に Claude Code セッションが見つかりません」

   - **Pane B（回答者）が実行した場合** → Pane A（質問者）に送信（Bash。**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
     ```bash
     tmux send-keys -t "{pane_a}" -l -- '~/.claude/dialogues/{session-id}.md のQ&Aセッション、回答が届きました。ファイルを Read で読み、追加質問があれば追記して /duo-ask-reply {session-id} を実行、不明点が解消されたら [CONCLUDED] を含めて追記し /duo-ask-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_a}" Enter
     ```

   - **Pane A（質問者）が実行した場合** → Pane B（回答者）に送信（Bash。**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
     ```bash
     tmux send-keys -t "{pane_b}" -l -- '~/.claude/dialogues/{session-id}.md のQ&Aセッション、追加質問が届きました。ファイルを Read で読み、回答を追記して /duo-ask-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_b}" Enter
     ```

   - プロンプト内のシングルクォートは `'\''` にエスケープすること
   - 結果報告: 「{回答/追加質問} を pane {送信先} に送信しました」

## 注意事項

- このスキルは応答の追記を行わない。ファイルへの応答追記はスキル実行前に通常のClaude Code操作で行うこと
- `sed` でフロントマターを更新するため Write ツールは不要
- duo-reply とは異なり、ロール（質問者/回答者）に応じてメッセージ内容が変わる
