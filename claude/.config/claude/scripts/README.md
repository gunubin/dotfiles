# Claude Code Scripts

このディレクトリには、Claude Codeのフック機能で使用するスクリプトが含まれています。

## スクリプト一覧

### format-edited-file.sh
- **目的**: 編集されたファイルに対して自動的にコードフォーマット（Prettier等）を実行
- **トリガー**: Edit, MultiEdit, Writeツール使用後
- **対象**: TypeScript/JavaScript ファイル（.ts, .tsx, .js, .jsx, .mjs, .cjs）
- **実行コマンド**: `npm run format`

### lint-edited-file.sh
- **目的**: 編集されたファイルに対して自動的にESLint修正を実行
- **トリガー**: Edit, MultiEdit, Writeツール使用後
- **対象**: TypeScript/JavaScript ファイル（.ts, .tsx, .js, .jsx, .mjs, .cjs）
- **実行コマンド**: `npm run lint:fix`

### deny-check.sh
- **目的**: 危険なBashコマンドの実行を防ぐセキュリティチェック
- **トリガー**: Bashツール使用前
- **機能**: 設定されたパターンに一致するコマンドをブロック

## 使用方法

### 1. プロジェクトでの有効化

プロジェクトの `.claude/settings.json` に以下のようにフックを設定します：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/deny-check.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/koki/dotfiles/claude/.config/claude/scripts/format-edited-file.sh"
          },
          {
            "type": "command",
            "command": "/Users/koki/dotfiles/claude/.config/claude/scripts/lint-edited-file.sh"
          }
        ]
      }
    ]
  }
}
```

### 2. ログ出力の有効化

デバッグ目的でログ出力を有効にする場合：

```bash
export CLAUDE_HOOK_LOGGING=true
```

ログファイルの場所：
- format-edited-file.sh: `~/.claude/format-hook.log`
- lint-edited-file.sh: `~/.claude/lint-hook.log`

### 3. 前提条件

各スクリプトが正常に動作するには、プロジェクトの `package.json` に以下のスクリプトが定義されている必要があります：

- **format-edited-file.sh**: `"format": "prettier --write"`
- **lint-edited-file.sh**: `"lint:fix": "eslint --fix"`

## トラブルシューティング

### スクリプトが実行されない場合

1. 実行権限を確認：
   ```bash
   chmod +x /Users/koki/dotfiles/claude/.config/claude/scripts/*.sh
   ```

2. jqコマンドがインストールされているか確認：
   ```bash
   which jq || brew install jq
   ```

3. ログを有効にして詳細を確認：
   ```bash
   export CLAUDE_HOOK_LOGGING=true
   tail -f ~/.claude/*.log
   ```

### パフォーマンスへの影響

- スクリプトは編集されたファイルに対してのみ実行されるため、パフォーマンスへの影響は最小限です
- 大きなプロジェクトでも、単一ファイルの処理は通常1秒以内に完了します

## カスタマイズ

各スクリプトは以下の点でカスタマイズ可能です：

- 対象ファイルの拡張子
- 実行するnpmスクリプト名
- ログ出力の詳細度
- エラーハンドリングの挙動

詳細は各スクリプトのソースコードを参照してください。