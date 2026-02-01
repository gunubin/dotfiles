---
name: review-branch
description: 現在のブランチ全体（コミット済み+未コミット）をmain/masterと比較してコードレビュー。PR作成前の品質確認に使用。
allowed-tools: Bash(git:*), Glob, Grep, Read
context: fork
agent: general-purpose
---

# ブランチコードレビュー

現在のブランチの全変更（main/masterからの差分）をレビューする。

## 対象範囲

```
main ────┬────────────────────────────────────────→
         │
         └── feature ── commit1 ── commit2 ── [unstaged]
             ↑                                   ↑
             └─────── レビュー対象 ───────────────┘
```

## 実行手順

### Step 1: 変更の全体像を把握

```bash
# ベースブランチ検出
BASE=$(git rev-parse --verify main 2>/dev/null && echo main || echo master)

# コミット履歴
git log --oneline $BASE..HEAD

# 変更ファイル一覧
git diff --name-status $BASE...HEAD

# 未コミット変更
git status --short
```

### Step 2: 差分取得

```bash
# mainからの全差分（コミット済み + 未コミット）
git diff $BASE
```

### Step 3: プロジェクトルール確認

`.claude/rules/` があれば読み、プロジェクト固有の規約を把握。

### Step 4: 優先順位付きレビュー

**レビュー順序**:
1. セキュリティ（認証、入力検証、機密情報）
2. ロジック（バグ、エッジケース）
3. 設計・アーキテクチャ
4. コード品質（可読性、命名）

**ファイル種別の観点**:

| 種別 | 重点観点 |
|------|----------|
| API/認証 | セキュリティ最優先 |
| ビジネスロジック | 正確性、エッジケース |
| UI | UX一貫性、アクセシビリティ |
| テスト | カバレッジ、境界値 |
| 設定 | 機密情報漏洩 |

### Step 5: 大規模変更の場合

10ファイル超: 変更の中心を特定し、重要度順にレビュー。

## 出力形式

```markdown
## コードレビュー: `<branch-name>`

**ベース**: main ← <branch-name>
**変更**: N commits + M unstaged files

### 変更の概要
[コミット履歴から読み取った意図]

### 指摘事項

#### 🔴 Critical（必須対応）
- **`file.ts:42`**: [問題] → [修正案]

#### 🟡 Warning（対応推奨）
- **`file.ts:100`**: [問題] → [修正案]

#### 🔵 Info（参考）
- **`file.ts:200`**: [提案]

### 良い点
- [良好な実装]
```
