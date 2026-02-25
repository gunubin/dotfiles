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
     ls -t ~/.claude/dialogues/cc-debate-*.md | grep -v '\-pro\.md$' | grep -v '\-con\.md$' | head -1
     ```
     ファイル名からセッション ID を抽出する（`cc-debate-` から `.md` を除いた部分）
   - ファイルが見つからない → エラー「アクティブなディベートセッションが見つかりません」

2. **セッションファイル読み込み**: `~/.claude/dialogues/{session-id}.md` を Read で読む

3. **YAML フロントマターから状態取得**
   - `status`: セッション状態
   - `current_round`: 完了済みラウンド数（両者が書き終わったラウンドのカウント）
   - `max_rounds`: 最大ラウンド数
   - `pane_moderator`: モデレーターの pane ID
   - `pane_pro`: 賛成派の pane ID
   - `pane_con`: 反対派の pane ID

4. **終了チェック**（以下のいずれかに該当する場合）
   - `status` が `active` でない → 「このセッションは既に終了しています（status: {status}）」
   - 賛成派ファイル（`-pro.md`）または反対派ファイル（`-con.md`）の最後の `## Round` セクション内に `[CONCLUDED]` が含まれている → 合意による終了

5. **相手側の完了チェック**
   - 次のラウンド番号を算出: `next_round = current_round + 1`
   - 賛成派ファイル `~/.claude/dialogues/{session-id}-pro.md` 内に `## Round {next_round}` が存在するか確認
   - 反対派ファイル `~/.claude/dialogues/{session-id}-con.md` 内に `## Round {next_round}` が存在するか確認
   - **片方のみ存在**（相手がまだ書いていない）→ 結果報告「Round {next_round} の主張を追記しました。相手側の完了を待っています。」→ **ここで終了。送信はしない。**
   - **両方存在** → 以下のステップ6に進む

6. **ラウンド完了処理**（両者が書き終わった場合）
   - `current_round` をインクリメント（Bash）:
     ```bash
     sed -i '' 's/^current_round: {N}$/current_round: {N+1}/' ~/.claude/dialogues/{session-id}.md
     ```
   - **ラウンド上限チェック**: `current_round + 1 >= max_rounds` の場合 → 終了処理へ（ステップ7）
   - **継続の場合** → ステップ8へ

7. **終了処理**
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
     tmux send-keys -t "{pane_moderator}" -l -- '~/.claude/dialogues/{session-id}.md のディベートが終了しました。メインファイル ~/.claude/dialogues/{session-id}.md と賛成派ファイル ~/.claude/dialogues/{session-id}-pro.md と反対派ファイル ~/.claude/dialogues/{session-id}-con.md の3つを Read で全文読み、賛成派と反対派の主張を公平にまとめてください。主要な論点、各派の強い主張、共通点・相違点を整理してください。' && sleep 0.3 && tmux send-keys -t "{pane_moderator}" Enter
     ```
   - プロンプト内のシングルクォートは `'\''` にエスケープすること
   - 結果報告: 「ディベートセッション {session-id} が終了しました（理由: {合意/ラウンド上限}）。モデレーター pane {pane_moderator} にまとめ依頼を送信しました」
   - **ここで終了。それ以上の送信なし。**

8. **次ラウンド送信**（両者に同時送信。**2つの Bash コマンドを並列実行すること**）
   - `$HOME/.claude/pane-state.json` を Read で両 pane の存在を確認
     - エントリがない → 「pane {ID} に Claude Code セッションが見つかりません」
   - 次ラウンド番号: `{N+2}`（= current_round + 2。current_round はインクリメント済み）

   賛成派に送信（Bash。**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
   ```bash
   tmux send-keys -t "{pane_pro}" -l -- '~/.claude/dialogues/{session-id}.md のディベート、Round {N+1} が完了しました。メインファイルを Read で読み、相手のファイル ~/.claude/dialogues/{session-id}-con.md を Read で確認し、賛成派として自分のファイル ~/.claude/dialogues/{session-id}-pro.md に Round {N+2} の主張を追記して /cc-debate-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_pro}" Enter
   ```

   反対派に送信（Bash。**必ず1つの Bash コマンドとして `&&` で繋いで実行すること**）:
   ```bash
   tmux send-keys -t "{pane_con}" -l -- '~/.claude/dialogues/{session-id}.md のディベート、Round {N+1} が完了しました。メインファイルを Read で読み、相手のファイル ~/.claude/dialogues/{session-id}-pro.md を Read で確認し、反対派として自分のファイル ~/.claude/dialogues/{session-id}-con.md に Round {N+2} の主張を追記して /cc-debate-reply {session-id} を実行してください。' && sleep 0.3 && tmux send-keys -t "{pane_con}" Enter
   ```

   - プロンプト内のシングルクォートは `'\''` にエスケープすること
   - 結果報告: 「Round {N+2} のプロンプトを賛成派・反対派の両方に送信しました」

## 注意事項

- このスキルは主張の追記を行わない。ファイルへの主張追記はスキル実行前に通常のClaude Code操作で行うこと
- `sed` でフロントマターを更新するため Write ツールは不要
- 終了時はモデレーター pane に3ファイル（メイン・pro・con）のまとめ依頼を送信する
- **ファイル分離**: 賛成派は `-pro.md`、反対派は `-con.md` にのみ書き込む。完了チェックは各ファイル内の `## Round N` の存在で判定する
- **同期ポイント**: 先に書き終わった側は「待ち」になり、後から書き終わった側が次ラウンドのトリガーになる
- 両者がほぼ同時に完了した場合、2回トリガーされる可能性があるが、sed のインクリメントは exact match なので片方のみ成功する。重複送信のリスクは低く、影響も軽微
