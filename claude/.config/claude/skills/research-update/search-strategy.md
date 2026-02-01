# 検索戦略詳細

## クエリ設計原則

### 効果的なクエリの特徴
- **具体的**: 曖昧な用語を避ける
- **年を明示**: `2025`, `2026` を含める
- **言語考慮**: 英語と日本語の両方
- **用語多様化**: 専門用語と一般用語

### クエリテンプレート

```
基本:    "[topic] [keyword] 2025 2026"
公式:    "[topic] official documentation"
変更:    "[topic] changes updates new features"
比較:    "[topic] vs [alternative] comparison"
実践:    "[topic] best practices how to"
問題:    "[topic] issues problems solutions"
チュートリアル: "[topic] tutorial guide example"
```

## 深度別検索戦略

### quick（2-3検索）
| 優先度 | クエリタイプ |
|--------|-------------|
| 1 | 公式情報 |
| 2 | 最新動向 |
| 3 | ベストプラクティス |

### standard（5-7検索）
| 優先度 | クエリタイプ |
|--------|-------------|
| 1 | 公式情報 |
| 2 | 最新動向・変更点 |
| 3 | ベストプラクティス |
| 4 | 問題・解決策 |
| 5 | 比較・代替案 |

### deep（10+検索）
上記に加えて:
- 複数の公式ソース
- コミュニティの議論
- 専門家の見解
- ケーススタディ
- パフォーマンス・ベンチマーク

## ソース信頼性評価

| ソースタイプ | 信頼度 | 使い方 |
|-------------|--------|--------|
| 公式ドキュメント | ★★★★★ | 一次情報として最優先 |
| 技術ブログ（著名） | ★★★★☆ | 実践的知見として活用 |
| GitHub Issues/Discussions | ★★★☆☆ | 問題点・解決策の参考 |
| Stack Overflow | ★★★☆☆ | 具体的な解決策 |
| Reddit/コミュニティ | ★★☆☆☆ | トレンド・意見として |
| 個人ブログ | ★★☆☆☆ | 検証が必要 |

## 情報抽出チェックリスト

- [ ] **事実**: 確認可能な情報
- [ ] **変更点**: 以前との差分
- [ ] **ベストプラクティス**: 推奨方法
- [ ] **注意点**: 落とし穴、よくある間違い
- [ ] **意見**: 専門家の見解
- [ ] **未解決**: オープンな問題

## 検索のコツ

### 結果が少ない場合
- 用語を一般的なものに変更
- 年の指定を外す
- 英語で検索

### 結果が多すぎる場合
- 具体的なキーワードを追加
- 特定のソースに絞る（`site:docs.example.com`）
- フレーズ検索（`"exact phrase"`）

### 矛盾する情報がある場合
1. 日付を確認（新しい方を優先）
2. ソースの権威性を確認
3. 複数ソースでクロスチェック

## 参考

- [Prompt Engineering Best Practices](https://claude.com/blog/best-practices-for-prompt-engineering)
- [AI Search Optimization 2026](https://www.growth-memo.com/p/state-of-ai-search-optimization-2026)
- [Knowledge Synthesis Guide](https://cihr-irsc.gc.ca/e/41382.html)
