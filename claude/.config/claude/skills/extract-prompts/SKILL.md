---
name: extract-prompts
description: Claude Codeへのプロンプトから課題や発見を抽出してObsidianに保存する。困りごと、感情、要望、質問を自動判定。
allowed-tools: Bash, Read, Write
---

# プロンプト抽出

Claude Codeのログから前回実行以降のプロンプトを取得し、AIで課題や発見を抽出してObsidianに保存。

## 仕組み

```
前回実行からの差分ログを取得
    ↓
ノイズ除去（コマンド、短文、ツール結果）
    ↓
AIが「課題と発見」を抽出
    ↓
Obsidian/Claude Prompts/ に保存
```

## 抽出対象

| 種別 | 例 |
|------|-----|
| 困りごと | 「〇〇が動かない」「〇〇でハマった」 |
| 感情 | 「面倒」「つらい」「いいね」 |
| 要望 | 「〇〇したい」「〇〇できないかな」 |
| 質問 | 「〇〇って本当？」「なぜ〇〇？」 |
| Q&A回答 | AskUserQuestionへの回答（質問とペアで保存） |

## 除外されるもの

- 短いプロンプト（15文字以下）
- コマンド（/clear等）
- ツール結果（AskUserQuestion回答は除外しない）
- 単なる指示（「修正して」「続けて」）

## 実行

```bash
~/.claude/scripts/extract-prompts.sh
```

## 保存先

```
~/Documents/notes/020_Ideas/Claude Prompts/YYYY/W##_MM-DD_to_MM-DD.md
```

週ごと（月曜始まり）のファイルに保存されます。

## 出力形式

```markdown
# Claude Code プロンプト W52_12-22_to_12-28

## 課題と発見

- pvが上がらない、心が折れそう
- リンク自動化できないか
```
