---
id: "{{SESSION_ID}}"
topic: "{{TOPIC}}"
pane_a: "{{PANE_A}}"
pane_b: "{{PANE_B}}"
role_a: "{{ROLE_A}}"
role_b: "{{ROLE_B}}"
max_rounds: {{MAX_ROUNDS}}
current_round: 0
status: active
---

# 対話セッション: {{SESSION_ID}}

## トピック

{{TOPIC}}

## 参加ルール

このファイルは2つのClaude Codeインスタンス間の対話セッションです。以下のルールに従ってください。

1. このファイルを全文 Read で読む
2. 会話履歴（既存の Round）を確認する
3. `## Round N (Pane %XX)` フォーマットで応答をファイル末尾に Edit で追記する（Round番号は duo-reply から送られたプロンプト内の番号を使うこと）
4. 応答後 `/duo-reply {{SESSION_ID}}` を実行する
5. 合意に達した場合は、応答末尾に `[CONCLUDED]` を含める（`/duo-reply` は実行しない）

## ガイドライン

- 簡潔に（500文字目安）
- 相手の指摘に明確に応答する
- コード例は必要なら含める
- 建設的な議論を心がける
- 同時編集は想定しない。必ずターン制で交互に書くこと

## Round 0 (トピック提示)

{{TOPIC}}
