---
name: review-branch
description: 並列エージェントと信頼度スコアリングでブランチ全体をレビュー。PR作成前の品質確認に使用。
allowed-tools: Bash(git:*), Glob, Grep, Read, Task
context: fork
---

# ブランチコードレビュー（並列エージェント版）

5つの専門エージェントを並列起動し、信頼度スコアリングで偽陽性を除外する高精度なコードレビュー。

## 対象範囲

```
main ────┬────────────────────────────────────────→
         │
         └── feature ── commit1 ── commit2 ── [unstaged]
             ↑                                   ↑
             └─────── レビュー対象 ───────────────┘
```

## 実行手順

### Step 1: 準備

```bash
# ベースブランチ検出
BASE=$(git rev-parse --verify main 2>/dev/null && echo main || echo master)

# 現在のブランチ名
BRANCH=$(git branch --show-current)

# コミット履歴
git log --oneline $BASE..HEAD

# 変更ファイル一覧（コミット済み + 未コミット）
git diff --name-status $BASE

# 変更サマリー作成
git diff --stat $BASE
```

### Step 2: ルールファイル収集

```bash
# CLAUDE.md の検索
find . -name "CLAUDE.md" -type f 2>/dev/null

# .claude/rules/ の検索
find .claude/rules -type f 2>/dev/null
```

収集したルールファイルのパスを `rules_files` として保持。

### Step 3: 差分取得

```bash
# mainからの全差分
git diff $BASE > /tmp/review-diff.txt
```

### Step 4: 並列レビュー（5エージェント同時起動）

**Task ツールで5つのエージェントを並列起動する**

| # | エージェント | モデル | プロンプト |
|---|-------------|--------|-----------|
| 1 | rules-auditor | sonnet | `./agents/rules-auditor.md` の手順に従い、`rules_files` と `diff` を入力として CLAUDE.md/rules 違反を検出 |
| 2 | bug-hunter | **opus** | `./agents/bug-hunter.md` の手順に従い、`diff` を入力として明らかなバグを検出 |
| 3 | git-context-analyzer | sonnet | `./agents/git-context-analyzer.md` の手順に従い、git 履歴から回帰を検出 |
| 4 | security-reviewer | sonnet | `$HOME/dotfiles/claude/.config/claude/agents/security-reviewer.md` を参照し、セキュリティ問題を検出 |
| 5 | code-comment-checker | sonnet | `./agents/code-comment-checker.md` の手順に従い、コメント指示への準拠を検証 |

**重要**: 5つのエージェントは必ず **同一メッセージ内で並列起動** すること。

各エージェントへの入力:
- 差分（`git diff $BASE` の結果）
- 変更ファイル一覧
- ルールファイル一覧（rules-auditor のみ）

### Step 5: スコア検証フェーズ

各エージェントから返された指摘に対して、Haiku で再評価を行う。

**評価プロンプト**:
```
この指摘を 0-100 で評価してください:

指摘内容: {issue.description}
ファイル: {issue.file}:{issue.line}
カテゴリ: {issue.category}

評価基準:
- 0-25: 偽陽性の可能性が高い、既存コードの問題、リンターで検出可能
- 26-50: スタイル問題、CLAUDE.md に明記なし、軽微
- 51-75: 実際の問題だが軽微、または発生頻度が低い
- 76-90: 重要な問題、対処が必要
- 91-100: 確実なバグ、または CLAUDE.md に明記されたルール違反

この差分と指摘を確認し、スコアと理由を返してください。
```

### Step 6: フィルタリング

**除外条件（80未満を除外）**:

1. スコア 80 未満の指摘
2. 以下の偽陽性パターンに該当する指摘:
   - 既存コードの問題（変更されていない行）
   - リンター/TypeScript で検出可能な問題
   - スタイルのみの問題
   - `// eslint-disable` 等で明示的に無視された箇所
   - テストコード内の軽微な問題

### Step 7: 結果出力

```markdown
## コードレビュー: `<branch-name>`

**ベース**: main ← <branch-name>
**変更**: N commits + M unstaged files
**レビュー**: 5エージェント並列実行

### 変更の概要
[コミット履歴から読み取った意図]

### 指摘事項

#### Critical（スコア 91-100）
- **`file.ts:42`** [95点]: [問題] → [修正案]
  - 検出: bug-hunter
  - 根拠: [バグの説明]

#### Important（スコア 80-90）
- **`file.ts:100`** [85点]: [問題] → [修正案]
  - 検出: rules-auditor
  - 根拠: CLAUDE.md に「...」と記載

### フィルタ済み（参考）
- 除外された指摘数: N件
- 主な除外理由: [スコア不足 / 偽陽性パターン]

### 良い点
- [良好な実装]
```

## 信頼度スコア詳細

| スコア | 意味 | アクション |
|--------|------|-----------|
| 91-100 | 確実なバグ/明示的ルール違反 | 必須修正 |
| 76-90  | 重要な問題 | 対応推奨 |
| 51-75  | 実際の問題だが軽微 | 除外（参考のみ） |
| 26-50  | スタイル問題、ルールに明記なし | 除外 |
| 0-25   | 偽陽性、既存問題 | 除外 |

## 偽陽性パターン（除外対象）

以下に該当する指摘は、スコアに関係なく除外を検討:

1. **既存コードの問題**: 変更されていない行への指摘
2. **ツール検出可能**: TypeScript、ESLint で検出できる問題
3. **スタイルのみ**: 機能に影響しないフォーマット問題
4. **明示的無視**: `eslint-disable`、`@ts-ignore` が付いている
5. **テスト内**: テストコードの品質問題（優先度を下げる）
6. **意図的な変更**: コミットメッセージで説明されている変更

## エージェント詳細

### 1. rules-auditor（sonnet）
- CLAUDE.md、`.claude/rules/` への準拠を監査
- 明示的なルール違反のみ報告
- ルールを引用できない場合は報告しない

### 2. bug-hunter（opus）
- 差分のみに集中した浅いスキャン
- 大きなバグのみ、nitpick は避ける
- 確信がない場合は報告しない

### 3. git-context-analyzer（sonnet）
- git blame/履歴を分析
- 過去のバグ修正が壊されていないか確認
- 回帰テストの観点で検証

### 4. security-reviewer（sonnet）
- OWASP Top 10 を分析
- 認証・入力検証・機密情報を重点チェック
- グローバルエージェント `$HOME/dotfiles/claude/.config/claude/agents/security-reviewer.md` を参照

### 5. code-comment-checker（sonnet）
- コード内コメントの指示に準拠しているか
- TODO、FIXME、WARNING の対処状況
- DO NOT MODIFY 等の制約違反
