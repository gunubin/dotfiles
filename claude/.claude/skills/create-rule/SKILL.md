---
name: create-rule
description: 新規ルールファイルのテンプレートを生成する。コーディング規約、設計方針、ワークフローなどのガイドラインを追加したい時に使用。
allowed-tools: Read, Write, Bash(mkdir *)
argument-hint: "<rule-name> [user|project]"
disable-model-invocation: true
---

# ルール作成

## 引数

| 引数 | 説明 | デフォルト |
|------|------|-----------|
| `$0` | ルール名（kebab-case） | 必須 |
| `$1` | スコープ | `project` |

**出力先:**
- `user` → `~/.claude/rules/$0.md`
- `project` → `.claude/rules/$0.md`

## 実行手順

1. `mkdir -p` でディレクトリ作成
2. 以下のテンプレートでルールファイルを生成
3. ユーザーに内容確認を求める

## テンプレート

~~~markdown
# [ルール名]

## 概要
[目的を1-2文で説明]

## ガイドライン

### 必須
- [必ず守るべきルール]

### 推奨
- [推奨プラクティス]

### 禁止
- [避けるべきパターン]

## 例

### 良い例
[コード例]

### 悪い例
[コード例]
~~~

## ルールの種類

| 種類 | 例 |
|------|-----|
| コーディング規約 | `typescript-style.md` |
| アーキテクチャ | `architecture.md` |
| セキュリティ | `security.md` |
| ワークフロー | `git-workflow.md` |

## 使用例

```bash
/create-rule typescript-style
/create-rule my-conventions user
```
