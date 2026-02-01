---
topic: Claude Code Skills プロンプト設計
date: 2026-02-01
depth: standard
sources: 12
---

# Claude Code Skills プロンプト 知識アップデート

## 概要

Claude Code の Skills は、プロンプトベースの動的コンテキスト注入システム。SKILL.md ファイルに YAML フロントマターと Markdown 指示を記述することで、Claude の能力を拡張する。2026年1月時点で v2.1.29 まで進化し、`context: fork` によるサブエージェント実行や、スクリプトバンドルなど高度な機能が追加されている。

## 主要な発見

### 1. Progressive Disclosure（段階的開示）が設計の核心

Skills の設計原理は「必要な時に必要な情報だけをロード」する Progressive Disclosure。

- **第1層**: フロントマター（name, description）のみが常時コンテキストに存在
- **第2層**: スキル呼び出し時に SKILL.md 全体がロード
- **第3層**: 実行時に必要に応じてスクリプトや参照ファイルをロード

これによりコンテキストの肥大化を防ぎつつ、事実上無制限の情報をスキルに含められる。

- **ソース**: [Claude Agent Skills: A First Principles Deep Dive](https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/)

### 2. スキル選択はLLMの推論に完全依存

スキルの選択にはアルゴリズム的なマッチングは使われない。Claude がシステムプロンプト内のスキル説明文を読み、ユーザー意図とマッチングする。

キーポイント:
- 埋め込みベクトルやキーワードマッチングは存在しない
- `description` フィールドがスキル選択の決め手
- ユーザーが自然に使う言葉を description に含めることが重要

- **ソース**: [Inside Claude Code Skills: Structure, prompts, invocation](https://mikhail.io/2025/10/claude-code-skills/)

### 3. SKILL.md の推奨構造

```yaml
---
name: skill-name
description: このスキルの目的と使用タイミング
argument-hint: [arguments]
disable-model-invocation: false
allowed-tools: Read, Grep, Bash(specific-command *)
context: fork  # 任意: サブエージェントで実行
agent: Explore  # context: fork 時のエージェント指定
---

## 目的
このスキルが何をするか

## 前提条件
必要な環境・ツール

## 手順
1. ステップ1
2. ステップ2

## 出力形式
期待される出力

## エラーハンドリング
問題発生時の対処
```

- **ソース**: [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)

### 4. Two-Message Injection戦略

スキルはUIと推論で異なるメッセージを注入:
- **Message 1** (`isMeta: false`): UIに表示されるスキル呼び出し通知
- **Message 2** (`isMeta: true`): ユーザーには非表示だがClaudeの推論に送信される詳細指示

これによりUIの煩雑さを避けつつ、詳細な指示を渡せる。

- **ソース**: [Claude Agent Skills: A First Principles Deep Dive](https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/)

### 5. context: fork でサブエージェント実行

複雑なタスクやノイズの多いタスクは `context: fork` で分離実行:

```yaml
---
name: deep-research
description: トピックを徹底的に調査
context: fork
agent: Explore
---

$ARGUMENTS について調査:
1. Glob と Grep で関連ファイルを検索
2. コードを読み分析
3. ファイル参照付きで知見をまとめる
```

利用可能なビルトインエージェント:
- `Explore`: 読み取り専用のコードベース探索
- `Plan`: 計画立案
- `general-purpose`: 汎用（デフォルト）
- カスタムエージェント: `.claude/agents/` に定義

**注意**: `context: fork` はタスク指示がないと意味がない。ガイドラインだけのスキルには不向き。

- **ソース**: [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)

### 6. 動的コンテキスト注入 `!`command``

シェルコマンドの出力をスキル送信前に埋め込める:

```yaml
---
name: pr-summary
description: PRの変更をサマリー
context: fork
agent: Explore
---

## PRコンテキスト
- PR差分: !`gh pr diff`
- PRコメント: !`gh pr view --comments`

## タスク
このPRをサマリーしてください
```

これは前処理であり、Claude が実行するのではない。

- **ソース**: [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)

## 最新の変更点

- **v2.1.29** (2026/01/31): 最新のシステムプロンプト、110+のプロンプト文字列を含むモジュラー構造
- **Skills と Slash Commands の統合**: `.claude/commands/` と `.claude/skills/` が統合され、Skills が推奨に
- **ultrathink キーワード**: スキル内に "ultrathink" を含めると Extended Thinking が有効化
- **`context: fork` のバグ**: 2026年1月時点で Skill ツール経由の呼び出しで `context: fork` が無視される問題が報告されている

- **ソース**: [GitHub - Piebald-AI/claude-code-system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts)

## ベストプラクティス

### SKILL.md 作成のコツ

1. **description を最適化**: ユーザーが自然に言う言葉を含める
2. **500行以下に抑える**: 詳細は別ファイルに分離
3. **`{baseDir}` 変数を使用**: ハードコードパスを避ける
4. **スクリプトをバンドル**: 決定論的な処理は Python/Shell スクリプトで

### 呼び出し制御

| フロントマター | ユーザー呼び出し | Claude呼び出し | 用途 |
|---------------|----------------|---------------|-----|
| (デフォルト) | Yes | Yes | 汎用スキル |
| `disable-model-invocation: true` | Yes | No | deploy, commit など副作用のあるもの |
| `user-invocable: false` | No | Yes | バックグラウンド知識 |

### ツール制限

```yaml
allowed-tools: Read, Grep, Glob  # 読み取り専用モード
allowed-tools: Bash(git add:*), Bash(git commit:*)  # 特定コマンドのみ
```

## 注意点・落とし穴

1. **セキュリティリスク**: スキルはプロンプトインジェクションの攻撃ベクトルになりうる。信頼できるスキルのみ使用すること
2. **description が長すぎると選択されにくい**: シンプルで明確な description を
3. **多すぎるスキル**: デフォルト15,000文字のバジェット内で description がロードされる。超過すると一部が除外される
4. **context: fork の制限**: タスク指示のない「ガイドライン」スキルには不向き

## CLAUDE.md との使い分け

| 項目 | CLAUDE.md | Skills |
|------|-----------|--------|
| 目的 | 常時適用の指示 | タスク特化の指示 |
| ロードタイミング | 会話開始時 | 必要時のみ |
| 推奨行数 | 最小限（50-200指示） | 500行以下 |
| スクリプト | 不可 | バンドル可能 |

研究によると、Claude は150-200の指示を一貫して従える限界があり、CLAUDE.md は汎用的な指示に絞るべき。

## 参考リンク

- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Inside Claude Code Skills: Structure, prompts, invocation](https://mikhail.io/2025/10/claude-code-skills/)
- [Claude Agent Skills: A First Principles Deep Dive](https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/)
- [GitHub - Piebald-AI/claude-code-system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts)
- [CLAUDE.md: Best Practices Learned from Optimizing Claude Code](https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/)
- [Claude Code: Best practices for agentic coding](https://www.anthropic.com/engineering/claude-code-best-practices)
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [Claude Code Agents Directory](https://www.claudecodeagents.com/)
- [GitHub - anthropics/skills](https://github.com/anthropics/skills)
- [Claude Skills and CLAUDE.md: a practical 2026 guide for teams](https://www.gend.co/blog/claude-skills-claude-md-guide)
