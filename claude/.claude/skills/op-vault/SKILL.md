---
name: op-vault
description: |
  API キー・トークンなどの秘密情報を 1Password に保存し、Claude とシェルから `op://` 参照で使えるようにする。
  値そのものはチャット・ファイル・git に書かず、参照の台帳（rules/1password.md）だけを残す。
  「APIキーを保存して」「1Password に入れて」「秘密情報を環境変数にしたい」「op の参照を登録して」時に使用。
allowed-tools: Bash(op *), Bash(fish -c *), Read, Edit
argument-hint: "<kebab-case の項目名> [用途の一言]"
---

# op-vault

秘密情報を 1Password CLI（`op`）で扱う。値は Claude が見ない・書かないのが原則。

## 規約

| 項目 | 決まり |
|------|--------|
| 保管庫 | `dev`（Claude が使う開発用の秘密はここに集める） |
| タイトル | 英小文字の kebab-case（例: `mf-cloud-accounting-api-key`）。日本語・全角・記号は `op://` 参照に使えない |
| カテゴリ | API キー・トークンは `API Credential`（値のフィールドは `credential`）。ID/パスワードは `Login`（`password`） |
| タグ | `claude` を必ず付ける。サービス名・会社名を追加してよい |
| メモ | 日本語で、用途・発行場所・ヘッダー名や URL・シェルへの入れ方を書く |
| 参照 | `op://dev/<タイトル>/<フィールド>` |

## 実行手順

1. 空の項目を作る。値は入れない。
   ```bash
   op item create --vault dev --category "API Credential" --title "<name>" --tags "claude,<service>" \
     'credential=' 'notesPlain=<用途・発行場所・使い方を日本語で>'
   ```
2. ユーザーに「1Password アプリでこの項目の credential 欄に値を貼って保存して」と頼む（user-todos に登録する）。
3. 保存されたら、値を表示せずに読めることだけ確かめる。
   ```bash
   op read "op://dev/<name>/credential" > /dev/null && echo ok
   ```
4. `~/.claude/rules/1password.md` の台帳に 1 行足す（用途・参照・備考）。
5. シェルで使うなら fish のユニバーサル変数に入れる。値はターミナル上にも出さない。
   ```bash
   fish -c 'set -Ux <VAR> (op read "op://dev/<name>/credential")'
   ```

## 注意

- `op` は呼び出しのたびに 1Password の認証ダイアログが出る。1 タスクで何度も呼ばず、一度環境変数に入れて使い回す。
- 値を `echo`・ログ・ファイル・コミットに出さない。長さや先頭数文字の確認もしない。
- 既存項目のタイトルが日本語なら、`--title` で kebab-case に改名してから参照する（ID でも参照できるが読めない）。
- Claude Code の MCP 設定にはヘッダーを `${VAR}` で書き、値は環境変数から渡す。

## 使用例

```
/op-vault stripe-test-secret-key Stripe のテスト用シークレット
```
