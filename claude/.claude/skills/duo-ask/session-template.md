---
id: "{{SESSION_ID}}"
topic: "{{QUESTIONS}}"
context: "{{CONTEXT}}"
pane_a: "{{PANE_A}}"
pane_b: "{{PANE_B}}"
max_rounds: {{MAX_ROUNDS}}
current_round: 0
status: active
---

# Q&Aセッション: {{SESSION_ID}}

## ロール

- **Pane A ({{PANE_A}})**: 質問者
- **Pane B ({{PANE_B}})**: 回答者{{CONTEXT_DISPLAY}}

## 参加ルール

### 回答者 (Pane B) のルール

1. このファイルを全文 Read で読む
2. 質問内容を確認する
3. 必要に応じて WebSearch / WebFetch / コード調査で情報収集する
4. `## Round N - 回答 (Pane %XX)` フォーマットで回答をファイル末尾に Edit で追記する
5. 回答後 `/duo-ask-reply {{SESSION_ID}}` を実行する

### 質問者 (Pane A) のルール

1. このファイルを全文 Read で読み、回答を確認する
2. 追加質問がある場合: `## Round N - 質問 (Pane %XX)` フォーマットで追記し `/duo-ask-reply {{SESSION_ID}}` を実行する
3. 不明点が解消された場合: `## Round N - 完了 (Pane %XX)` に `[CONCLUDED]` を含めて追記し `/duo-ask-reply {{SESSION_ID}}` を実行する

## ガイドライン

- 回答者: 正確で具体的な回答を心がける。不明な場合はウェブ検索等で調査する
- 質問者: 回答を踏まえて深掘りまたは別の観点から質問する
- 簡潔に（各回答・質問とも500文字目安）
- 同時編集は想定しない。必ずターン制で交互に書くこと

## Round 0 - 質問 ({{PANE_A}})

{{QUESTIONS}}
