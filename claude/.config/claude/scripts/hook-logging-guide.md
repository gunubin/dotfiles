# Claude Code Hook ログ設定ガイド

## 概要
Claude Codeのhook（lint/format）のログ出力を制御するための設定ガイドです。

## 設定方法

### デフォルト動作（ログOFF）
```bash
# 何も設定しない場合、ログは出力されません
# hookは実行されますが、ログファイルには何も記録されません
```

### ログを有効にする方法

#### 一時的に有効化（セッション限定）
```bash
export CLAUDE_HOOK_LOGGING=true
# この後のClaude Code操作でログが出力されます
```

#### 永続的に有効化（.bashrc/.zshrc等に追加）
```bash
echo 'export CLAUDE_HOOK_LOGGING=true' >> ~/.zshrc
source ~/.zshrc
```

#### 特定のプロジェクトでのみ有効化
```bash
# プロジェクトディレクトリで
echo 'export CLAUDE_HOOK_LOGGING=true' > .env
# または
CLAUDE_HOOK_LOGGING=true claude --project .
```

### ログを無効にする方法
```bash
export CLAUDE_HOOK_LOGGING=false
# または
unset CLAUDE_HOOK_LOGGING
```

## ログファイルの場所
- **Lintログ**: `~/.claude/lint-hook.log`
- **Formatログ**: `~/.claude/format-hook.log`

## ログ肥大化の対策
```bash
# ログファイルをクリア
> ~/.claude/lint-hook.log
> ~/.claude/format-hook.log

# または削除
rm ~/.claude/lint-hook.log ~/.claude/format-hook.log
```

## 推奨設定
- **開発時**: `CLAUDE_HOOK_LOGGING=true` (デバッグ用)
- **日常使用**: `CLAUDE_HOOK_LOGGING=false` (デフォルト、ログなし)