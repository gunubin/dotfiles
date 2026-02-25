# 詳細チェックリスト

## Skills

### Frontmatter必須項目
| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | 推奨 | 省略時はディレクトリ名を使用 |
| `description` | 推奨 | Claudeの自動判断に使用 |
| `argument-hint` | 任意 | オートコンプリート時のヒント |
| `disable-model-invocation` | 任意 | trueでユーザー専用 |
| `user-invocable` | 任意 | falseで/メニュー非表示 |
| `allowed-tools` | 任意 | 許可するツールリスト |
| `model` | 任意 | 使用モデル指定 |
| `context` | 任意 | `fork`でサブエージェント実行 |
| `agent` | 任意 | context: fork時のエージェント |
| `hooks` | 任意 | スキル固有フック |

### 変数置換
| 変数 | 説明 |
|------|------|
| `$ARGUMENTS` | 全引数 |
| `$ARGUMENTS[N]` | N番目の引数（0始まり） |
| `$0`, `$1`, etc. | 引数のショートハンド |
| `${CLAUDE_SESSION_ID}` | セッションID |
| `!\`command\`` | 動的コンテキスト注入 |

## Commands

- `.claude/commands/<name>.md` に配置
- Skillsと同じfrontmatter対応
- 同名のSkillがあればSkill優先

## Agents

### 必須Frontmatter
| フィールド | 説明 |
|-----------|------|
| `name` | エージェント名 |
| `description` | Task toolでの説明 |
| `tools` | 使用可能ツール |
| `model` | 使用モデル |

### 推奨構造
```markdown
---
name: agent-name
description: 説明文
tools: Tool1, Tool2
model: sonnet
---

# エージェント名

## 起動トリガー
- いつ使用されるか

## 主な能力
- 何ができるか

## 手法/プロセス
- どのように実行するか

## 成果物フォーマット
- 出力形式

## コア原則
- 守るべきルール
```

## Rules

### 用途
- コンテキストとして常に読み込まれる指針
- プロジェクト固有のコーディング規約
- エージェントのオーケストレーション

### 推奨構造
```markdown
# [ルール名]

## 概要
[ルールの目的]

## ガイドライン
- 具体的なルール1
- 具体的なルール2

## 例
[良い例/悪い例]
```

## 品質基準

### ⭐⭐⭐⭐⭐ Excellent
- すべてのベストプラクティス準拠
- 明確で具体的な記述
- 適切なセキュリティ設定
- 再利用性が高い

### ⭐⭐⭐⭐☆ Good
- ほぼベストプラクティス準拠
- 軽微な改善点あり
- セキュリティ問題なし

### ⭐⭐⭐☆☆ Average
- 基本機能は動作
- 改善の余地あり
- ドキュメント不足

### ⭐⭐☆☆☆ Below Average
- 問題点が複数
- 構造が不明確
- セキュリティ懸念あり

### ⭐☆☆☆☆ Poor
- 大幅な修正が必要
- 機能しない可能性
- セキュリティリスク
