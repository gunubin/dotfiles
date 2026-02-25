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
description: |
  [何をするか] + [いつ使うか]
  ※descriptionでスキル選択が決まる。トリガー条件を必ず含める
allowed-tools: [必要最小限のツール]
argument-hint: "[引数のヒント]"
# disable-model-invocation: true  # 副作用ありなら有効化
---

# [スキル名]

## 目的
[1-2文。Claudeが既に知っていることは省略]

## 実行手順
1. [ステップ]

## リソース構成（複雑なスキルのみ）
```
skill-name/
├── SKILL.md          # 必須：指示本体
├── scripts/          # 任意：繰り返し実行するコード
├── references/       # 任意：必要時に読む参照ドキュメント
└── assets/           # 任意：出力用テンプレート・画像等
```

## 出力形式
[出力テンプレート]

## 使用例
/[スキル名] [引数例]
~~~

## 設計原則

| 原則 | 説明 |
|------|------|
| **簡潔に** | Claudeは賢い。既知の情報は書かない |
| **トリガー明示** | descriptionに「いつ使うか」を必ず含める |
| **500行以下** | 超える場合は `references/` に分割 |
| **不要物を作らない** | README.md, CHANGELOG.md 等は不要 |

## 使用例

```bash
/create-skill deploy-staging
/create-skill my-tool user
```

## 参考

- [Skills公式ドキュメント](https://code.claude.com/docs/en/skills)
