---
name: create-agent
description: 新規エージェントのテンプレートを生成する。専門タスク用のサブエージェントを手動で追加したい時に使用。公式/agentsコマンドの補助。
allowed-tools: Read, Write, Bash(mkdir *)
argument-hint: "<agent-name> [user|project]"
disable-model-invocation: true
---

# エージェント作成

> 対話形式で作成する場合は公式コマンド `/agents` を使用

## 引数

| 引数 | 説明 | デフォルト |
|------|------|-----------|
| `$0` | エージェント名（kebab-case） | 必須 |
| `$1` | スコープ | `project` |

**出力先:**
- `user` → `~/.claude/agents/$0.md`
- `project` → `.claude/agents/$0.md`

## 実行手順

1. `mkdir -p` でディレクトリ作成
2. 以下のテンプレートでエージェントファイルを生成
3. ユーザーに内容確認を求める

## テンプレート

~~~yaml
---
name: [エージェント名]
description: [用途を説明。proactive使用時は「〜時に自動起動」と明記]
tools: Read, Grep, Glob
model: sonnet
---

# [エージェント名]

[役割を1-2文で説明]

## 起動トリガー
- [いつ使用されるか]

## 主な能力
- [何ができるか]

## 実行プロセス

### 1. [フェーズ1]
- [ステップ]

### 2. [フェーズ2]
- [ステップ]

## 出力形式
[出力テンプレート]
~~~

## ビルトインエージェント

| 名前 | 用途 |
|------|------|
| Explore | 読み取り専用の高速検索 |
| Plan | プランモードでのリサーチ |
| general-purpose | 複雑なマルチステップタスク |

## 使用例

```bash
/create-agent code-reviewer
/create-agent my-helper user
```

## 参考

- [Sub-agents公式ドキュメント](https://code.claude.com/docs/en/sub-agents)
