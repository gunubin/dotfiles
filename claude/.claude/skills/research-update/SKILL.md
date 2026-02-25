---
name: research-update
description: 特定トピックの最新情報をウェブ検索で収集し、知識として統合・構造化する。「〜について最新情報を知りたい」「〜の知識をアップデートしたい」時に使用。
allowed-tools: WebSearch, WebFetch, Read, Write, Bash(mkdir *), Bash(find ~/.claude/research *)
context: fork
agent: general-purpose
argument-hint: "<topic> [quick|standard|deep] [force]"
---

# リサーチ＆知識アップデート

トピック `$ARGUMENTS` について最新情報を収集し、知識として統合する。

## 深度の判断

引数に含まれるキーワードで深度を判断:
- `quick` → 2-3検索
- `deep` / `comprehensive` / `詳しく` → 10+検索
- それ以外 → `standard`（5-7検索）

## 実行手順

### Step 0: キャッシュチェック（最初に必ず実行）

同じトピックの既存ファイルを検索:

```bash
find ~/.claude/research -name "*.md" -mtime -7 2>/dev/null | xargs grep -l -i "[topic-keyword]" 2>/dev/null
```

**1週間以内のファイルが見つかった場合:**
1. そのファイルを読み込む
2. 内容をサマリーとして返却
3. 「既存のリサーチ結果を参照しました（YYYY-MM-DD作成）」と明示
4. **新規検索はスキップ**

**見つからない場合 or `force` / `強制` オプション指定時:**
→ Step 1以降を実行

### Step 1: 検索戦略設計

トピックを分解し、複数クエリを設計:
- `"[topic] 2025 2026"` - 最新情報
- `"[topic] official documentation"` - 公式情報
- `"[topic] best practices"` - 実践
- `"[topic] changes updates"` - 変更点

### Step 2: 多角的検索

1. **並列実行**: 独立したクエリは同時に
2. **深掘り**: 重要ソースは WebFetch で詳細取得
3. **ソース多様化**: 公式 > ブログ > コミュニティ

### Step 3: 情報統合

1. **矛盾解決**: 新しい・公式情報を優先
2. **ギャップ特定**: 不足情報を明示
3. **実践への翻訳**: アクションに変換

### Step 4: ファイル保存

**保存先**: `~/.claude/research/YYYY/MM/[topic-name].md`

```bash
mkdir -p ~/.claude/research/$(date +%Y)/$(date +%m)
```

**ファイル形式**:

```markdown
---
topic: [トピック]
date: YYYY-MM-DD
depth: quick|standard|deep
sources: N
---

# [トピック] 知識アップデート

## 概要
[1-3文サマリー]

## 主要な発見

### 1. [発見1]
[詳細]
- **ソース**: [URL]

### 2. [発見2]
[詳細]
- **ソース**: [URL]

## 最新の変更点
- [変更]（時期）

## ベストプラクティス
1. [プラクティス]

## 注意点
- [落とし穴]

## 参考リンク
- [タイトル](URL)
```

### Step 5: サマリー返却

メイン会話に返すのは以下のみ:
- 保存先ファイルパス
- 概要（1-3文）
- 主要な発見（箇条書き3-5件）

## 検索のコツ

- 年を明示（2025, 2026）
- 英語と日本語の両方を検討
- 公式ドキュメントを最優先
- 矛盾する情報は新しい方を採用

## 古いファイルの管理

30日以上前のファイルは削除を検討:
```bash
find ~/.claude/research -type f -mtime +30 -name "*.md"
```
