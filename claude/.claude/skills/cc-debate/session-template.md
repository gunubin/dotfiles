---
id: "{{SESSION_ID}}"
topic: "{{TOPIC}}"
pane_moderator: "{{PANE_MODERATOR}}"
pane_pro: "{{PANE_PRO}}"
pane_con: "{{PANE_CON}}"
max_rounds: {{MAX_ROUNDS}}
current_round: 0
status: active
---

# ディベートセッション: {{SESSION_ID}}

## トピック

{{TOPIC}}

## ロール

- **モデレーター ({{PANE_MODERATOR}})**: ディベート終了後に両者の議論をまとめる
- **賛成派 ({{PANE_PRO}})**: トピックに**賛成**の立場で議論する
- **反対派 ({{PANE_CON}})**: トピックに**反対**の立場で議論する

## ファイル構成

- **メインファイル**: `~/.claude/dialogues/{{SESSION_ID}}.md`（このファイル。メタデータ・ルール）
- **賛成派ファイル**: `~/.claude/dialogues/{{SESSION_ID}}-pro.md`（賛成派のみ書き込み）
- **反対派ファイル**: `~/.claude/dialogues/{{SESSION_ID}}-con.md`（反対派のみ書き込み）

## 参加ルール

1. このメインファイルを全文 Read で読む
2. 相手のファイルを Read で確認する（賛成派は `-con.md`、反対派は `-pro.md`）
3. **自分のファイルにのみ** `## Round N` フォーマットで主張を Edit で追記する
   - 賛成派 → `~/.claude/dialogues/{{SESSION_ID}}-pro.md` に追記
   - 反対派 → `~/.claude/dialogues/{{SESSION_ID}}-con.md` に追記
4. 追記後 `/cc-debate-reply {{SESSION_ID}}` を実行する

**重要**: 相手のファイルは **Read のみ**。書き込みは自分のファイルだけ。

## ガイドライン

- 自分の立場を一貫して主張する
- 相手の主張に対して具体的に反論する（Round 2以降）
- 論拠・具体例を挙げる
- 簡潔に（500文字目安）
- 賛成派と反対派は各ラウンド並行して書く。ファイルが分かれているため競合は発生しない
