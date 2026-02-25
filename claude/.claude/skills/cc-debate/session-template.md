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

## 参加ルール

1. このファイルを全文 Read で読む
2. これまでの議論（既存の Round）を確認する
3. `## Round N - 賛成派/反対派 (Pane %XX)` フォーマットで主張をファイル末尾に Edit で追記する
4. 追記後 `/cc-debate-reply {{SESSION_ID}}` を実行する

## ガイドライン

- 自分の立場を一貫して主張する
- 相手の主張に対して具体的に反論する
- 論拠・具体例を挙げる
- 簡潔に（500文字目安）
- 同時編集は想定しない。必ずターン制で交互に書くこと
