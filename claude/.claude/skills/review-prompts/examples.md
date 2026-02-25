# プロンプト例

## Skills - 良い例

```yaml
---
name: deploy-staging
description: ステージング環境へのデプロイを実行。テスト完了後のデプロイ依頼時に使用。
allowed-tools: Bash(npm run deploy:staging), Bash(git *)
disable-model-invocation: true
---

# /deploy-staging

ステージング環境へのデプロイを実行する。

## 前提条件
- すべてのテストがパス済み
- mainブランチにマージ済み

## 実行手順
1. 最新のmainをプル
2. ビルド実行
3. ステージングへデプロイ
4. デプロイ後の確認

## 出力
デプロイ結果のサマリーを表示。
```

**良い点**:
- `disable-model-invocation: true` で副作用のある操作を保護
- `allowed-tools` が必要最小限
- 明確な前提条件と手順
- 簡潔で読みやすい

---

## Skills - 悪い例

```yaml
---
name: do_stuff
description: いろいろやる
allowed-tools: Bash
---

# スタッフ

なんでもやります。
```

**問題点**:
- 命名がkebab-caseでない
- descriptionが曖昧
- `Bash`が無制限で危険
- 目的が不明確
- 使用例がない

---

## Commands - 良い例

```yaml
---
description: PRレビューコメントを分析し対応方針を整理
allowed-tools: Bash(gh pr view *), Read, Grep
---

# /analyze-pr-comments

PRのレビューコメントを取得し、以下を整理:

## 分析内容
1. **必須対応**: 修正が必要なコメント
2. **任意対応**: 改善提案
3. **質問**: 回答が必要なコメント

## 使用方法
\`\`\`
/analyze-pr-comments 123
\`\`\`

## 出力形式
- カテゴリ別にグループ化
- 優先度順にソート
- 対応案を提示
```

---

## Agents - 良い例

```yaml
---
name: test-analyzer
description: テスト失敗の原因分析。テストエラー発生時に自動起動。
tools: Read, Grep, Glob, Bash(npm test *)
model: sonnet
---

# テストアナライザー

テスト失敗時の原因分析と修正提案を行うスペシャリスト。

## 起動トリガー
- テストが失敗した時
- CI/CDパイプラインがテストで止まった時

## 分析プロセス

### 1. 失敗テストの特定
- エラーメッセージの解析
- スタックトレースの確認

### 2. 原因の特定
- 関連コードの調査
- 最近の変更との関連

### 3. 修正提案
- 具体的な修正案
- 回帰テストの追加提案

## 出力形式

\`\`\`markdown
## 🔴 テスト失敗分析

### 失敗テスト
- `test/xxx.test.ts:42` - [テスト名]

### 原因
[原因の説明]

### 修正提案
\`\`\`diff
- 変更前
+ 変更後
\`\`\`
\`\`\`
```

---

## Rules - 良い例

```markdown
# TypeScript コーディング規約

## 型定義

### 必須
- すべての関数に戻り値の型を明示
- `any`の使用は禁止、必要時は`unknown`
- インターフェースは`I`プレフィックスなし

### 推奨
- ユニオン型よりdiscriminated union
- 型ガードを積極的に活用

## 例

✅ 良い例:
\`\`\`typescript
function getUser(id: string): User | null {
  // ...
}
\`\`\`

❌ 悪い例:
\`\`\`typescript
function getUser(id: any) {
  // ...
}
\`\`\`
```

---

## アンチパターン一覧

| パターン | 問題点 | 改善案 |
|---------|--------|--------|
| `Bash`を無制限に許可 | 任意コマンド実行可能 | 必要なコマンドのみ許可 |
| descriptionが1単語 | 自動判断が困難 | 用途とトリガーを明記 |
| 500行超のSKILL.md | コンテキスト過負荷 | 補足ファイルに分割 |
| 汎用的すぎる名前 | 意図が不明確 | 動詞+目的語の形式 |
| 出力形式未定義 | 結果が不安定 | 明確なフォーマット定義 |
