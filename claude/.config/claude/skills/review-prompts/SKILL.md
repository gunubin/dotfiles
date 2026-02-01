---
name: review-prompts
description: Claude Codeのskills, commands, rules, agentsのプロンプトをレビュー・改善提案する。プロンプト品質の監査や新規作成時の検証に使用。
allowed-tools: Read, Glob, Grep
argument-hint: "[skills|commands|rules|agents|all|<file-path>]"
---

# プロンプトレビュー

## 実行手順

### Step 1: 対象ファイルの特定

**引数 `$ARGUMENTS` に基づいて検索**:

| 引数 | 検索パス |
|------|----------|
| `skills` | `~/.claude/skills/**/SKILL.md`, `.claude/skills/**/SKILL.md` |
| `commands` | `~/.claude/commands/*.md`, `.claude/commands/*.md` |
| `rules` | `~/.claude/rules/*.md`, `.claude/rules/*.md` |
| `agents` | `~/.claude/agents/*.md`, `.claude/agents/*.md` |
| `all` | 上記すべて |
| `<file-path>` | 指定されたファイル |

### Step 2: 各ファイルをレビュー

**Frontmatterチェック**:
- `name`: kebab-case、64文字以内
- `description`: 50-150文字、用途・トリガー明記
- `allowed-tools`: 必要最小限か
- `disable-model-invocation`: 副作用ありならtrue

**内容チェック**:
- 目的が1文で説明可能か
- 出力フォーマット定義あるか
- 使用例があるか
- 500行以下か

**セキュリティチェック**:
- `Bash`が無制限でないか
- 機密情報アクセスなし

詳細は [checklist.md](checklist.md) 参照。

### Step 3: 結果出力

```markdown
## レビュー結果: `<ファイル名>`

### 良い点
- [具体的な良い点]

### 改善提案
1. **[カテゴリ]**: [問題] → [改善案]

### スコア
| 項目 | 評価 |
|------|------|
| 構造 | A/B/C/D |
| 命名 | A/B/C/D |
| 機能設計 | A/B/C/D |
| セキュリティ | A/B/C/D |
```

## 補足資料

- [checklist.md](checklist.md) - 詳細チェックリスト
- [examples.md](examples.md) - 良い例・悪い例

## 使用例

```bash
/review-prompts all                    # 全レビュー
/review-prompts skills                 # スキルのみ
/review-prompts ~/.claude/agents/planner.md  # 特定ファイル
```
