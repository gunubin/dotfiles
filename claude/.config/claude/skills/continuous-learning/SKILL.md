# 継続学習スキル

## 概要

Claude Codeセッションを自動評価し、再利用可能なパターンを抽出して将来の使用のために学習スキルとして保存する。

## 動作メカニズム

このスキルは**Stopフック**として機能し、セッション終了時に以下のステップを実行：

```
1. セッション評価 → 十分なメッセージ数があるか確認（デフォルト最小10）
2. パターン検出 → セッションから抽出可能なパターンを特定
3. スキル抽出 → 有用なパターンを ~/.claude/skills/learned/ に保存
```

## 設定オプション

`config.json` でカスタマイズ可能：

| 設定 | デフォルト | 説明 |
|------|------------|------|
| `min_session_length` | 10 | 最小セッションメッセージ数 |
| `extraction_threshold` | "medium" | 抽出の閾値 |
| `auto_approve` | false | 自動承認の有無 |
| `learned_skills_path` | "~/.claude/skills/learned/" | 保存先パス |

## 検出パターン

### 抽出対象
- エラー解決テクニック
- ユーザー訂正からの洞察
- フレームワーク/ライブラリのワークアラウンド
- 効果的なデバッグ方法
- プロジェクト固有の規約

### 無視するパターン
- 単純なタイポ
- 一回限りの修正
- 外部APIの問題

## 実装

`~/.claude/settings.json` にStopフックを追加：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/skills/continuous-learning/evaluate-session.sh"
          }
        ]
      }
    ]
  }
}
```

## Stopフックを選ぶ理由

| 観点 | Stopフック | UserPromptSubmitフック |
|------|------------|------------------------|
| 実行頻度 | セッション終了時に1回 | 毎メッセージ |
| 負荷 | 軽量 | 重い、レイテンシ増加 |
| コンテキスト | 完全なセッションコンテキスト | 部分的 |

## 保存されるスキルの例

```markdown
# Supabase RLSデバッグパターン

## 問題
RLSポリシーが期待通りに動作しない

## 解決方法
1. supabase.auth.getUser() でユーザーIDを確認
2. ポリシーの条件式をチェック
3. auth.uid() vs auth.jwt()->>'sub' の違いを確認

## コード例
...

## 適用条件
Supabase RLSで認証関連の問題が発生した場合
```
