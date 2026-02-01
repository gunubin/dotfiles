---
name: create-skill
description: 新規スキルのSKILL.mdテンプレートを生成しディレクトリを作成する。「スキルを作りたい」「新しいコマンドを追加したい」時に使用。
allowed-tools: Read, Write, Bash(mkdir *)
argument-hint: "<skill-name> [user|project]"
disable-model-invocation: true
---

# スキル作成

## 引数

| 引数 | 説明 | デフォルト |
|------|------|-----------|
| `$0` | スキル名（kebab-case） | 必須 |
| `$1` | スコープ | `project` |

**出力先:**
- `user` → `~/.claude/skills/$0/SKILL.md`
- `project` → `.claude/skills/$0/SKILL.md`

## 実行手順

1. `mkdir -p` でディレクトリ作成
2. 以下のテンプレートで `SKILL.md` を生成
3. ユーザーに内容確認を求める

## テンプレート

~~~yaml
---
name: [スキル名]
description: [50-150文字で用途・トリガーを説明]
allowed-tools: [必要最小限のツール]
argument-hint: "[引数のヒント]"
# disable-model-invocation: true  # 副作用ありなら有効化
---

# [スキル名]

## 目的
[1-2文で説明]

## 実行手順
1. [ステップ1]
2. [ステップ2]

## 出力形式
[出力テンプレート]

## 使用例
/[スキル名] [引数例]
~~~

## 使用例

```bash
/create-skill deploy-staging
/create-skill my-tool user
```

## 参考

- [Skills公式ドキュメント](https://code.claude.com/docs/en/skills)
