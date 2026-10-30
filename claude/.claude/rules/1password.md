# 1Password の秘密情報と参照の台帳

## 概要

API キーやトークンは 1Password の `dev` 保管庫に置き、Claude とシェルは `op://` 参照で使う。値はチャット・ファイル・git に書かない。保存と登録の手順は `op-vault` スキル。

## ガイドライン

### 必須

- 新しい秘密情報は `op-vault` スキルの規約で保存し、下の台帳に 1 行足す
- 参照は `op://dev/<kebab-case タイトル>/<フィールド>`。日本語タイトルは参照に使えない
- シェルへは `fish -c 'set -Ux <VAR> (op read "op://...")'` で渡す。値は表示しない
- `op` は呼ぶたびに認証ダイアログが出る。1 タスクで 1 回にし、環境変数で使い回す

### 禁止

- 値を `echo`・ログ・設定ファイル・コミットに出すこと
- 値を推測・一部表示して確認すること（`op read ... > /dev/null` で読めるかだけ確かめる）

## 台帳（dev 保管庫）

| 用途 | 参照 | 環境変数 | 備考 |
|------|------|----------|------|
| マネーフォワード クラウド会計 API キー（Claude Code の MCP `mfc_ca` 用） | `op://dev/mf-cloud-accounting-api-key/credential` | `MF_API_KEY` | ヘッダー `Mf-API-Key`。事業者コード 8031-8697 |
| GitHub Personal Access Token | `op://dev/GitHub Personal Access Token/credential` | - | タイトルに空白あり。参照は可能 |
| nudgit 本番 Open API トークン | `op://dev/nudgit-prod-open-api-token/credential` | - | |
| behivior-log（用途は項目のメモ参照） | `op://dev/behivior-log/credential` | - | |
| my-health の Google auth platform | `op://dev/my-health-google-auth-platform/credential` | - | |
| Cloudflare API Token（fren-admin 検証環境） | `op://dev/cloudflare-api-token-fren-admin-staging/credential` | - | |
| Apple Sandbox Tester 02（NoPace） | `op://dev/Apple Sandbox Tester 02 (NoPace)/password` | - | Login 項目 |
| NoPace の Google Play サービスアカウントの鍵（JSON。Play API・release-status.js・play-release.js 用） | `op://dev/google-play-service-account-nopace/credential` | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`（手元ではふだん置かない。GitHub Actions はシークレットから） | `eas-submit-service@nopace-469609`。同じ鍵を EAS と GitHub のシークレットにも登録（#140、2026-10-19）。手元のスクリプトは op read で読む（2026-10-28 に環境変数を消した） |
| RestCall の Google Play サービスアカウントの鍵（JSON。restcall の scripts/playApi.js 用。Play では RestCall だけ扱える） | `op://dev/google-play-service-account-restcall/credential` | `GOOGLE_PLAY_SERVICE_ACCOUNT_RESTCALL_JSON`（ふだんは置かない） | `restcall-play@nopace-469609`。スクリプトが op read で読む（2026-10-28 に環境変数から戻した） |
| YouTube Data API v3 キー（keyword-analysis MCP の get_youtube_trending 用） | `op://dev/youtube-data-api-key/credential` | `YOUTUBE_API_KEY` | クエリ `?key=`。mono-and.blog の git 履歴から移した（2026-10-19） |
| Hugging Face アクセストークン（keyword-analysis MCP の analyze_sentiment 用） | `op://dev/huggingface-api-key/credential` | `HUGGINGFACE_API_KEY` | ヘッダー `Authorization: Bearer`。mono-and.blog の git 履歴から移した（2026-10-19） |
| Google Photos Picker API の OAuth クライアント（JSON。photo-memories スキル用） | `op://dev/google-photos-picker-oauth-client/credential` | `GOOGLE_PHOTOS_PICKER_CLIENT_JSON` | デスクトップアプリ型。スコープ `photospicker.mediaitems.readonly`。トークンは `~/.config/photo-memories/token.json` |
| NoPace の OTA の配信を Slack の ota チャンネルに知らせる Incoming Webhook の URL（mobile/scripts/deploy-ota.js 用） | `op://dev/nopace-slack-ota-webhook/credential` | `NOPACE_OTA_SLACK_WEBHOOK_URL` | 手元から配ったときの通知。Actions は GitHub の Secrets の SLACK_WEBHOOK_URL（2026-10-21） |
| Harebi の AI の分析の中継（Cloudflare Workers の harebi-ai）が Claude を呼ぶ Anthropic API キー | `op://dev/anthropic-api-key-harebi/credential` | - | Console のワークスペース harebi・名前 harebi-ai-relay。中継へは `wrangler secret put ANTHROPIC_API_KEY` で op read から渡す。アプリには入れない（2026-10-30） |
| test-api-key / test-note | - | - | テスト用。使わない |
