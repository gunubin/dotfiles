---
name: mobile-app-playbook
description: |
  個人開発の Expo アプリ（NoPace・RestCall）で実際にハマったことから作った、新しいアプリを最初から同じ失敗なしで作るための手引き。
  新しいモバイルアプリを立ち上げるとき、ビルド・OTA・ストア申請・課金（RevenueCat）・分析（Firebase/GA4）・通知・ウィジェットを触るとき、
  モバイルの画面を作るときに読む。「新しいアプリを作る」「アプリの雛形」「ストアに出す」「課金を入れる」「OTA を出す」時に使用。
---

# 個人開発のモバイルアプリの手引き

NoPace（2025〜、iOS・Android 公開済み）と RestCall（2026-10-26 開始）のセッションを精査して、別のアプリでも起きることだけを残した。
アプリ固有の決まりは各リポジトリの CLAUDE.md にある。ここに書くのは、どのアプリでも最初からやっておくこと。

## 初日にやること

新しいアプリを作り始めたら、最初のコミットまでに次をそろえる。あとから入れると、ストア版からやり直しになるものが混じっている。

1. **土台は一番新しいアプリから持ち込む**: 画面の部品・設定画面の並び・版の表示・デバッグのページは持ち込む。設計（アーキテクチャ）は持ち込まない
2. **CNG にする**: `ios/`・`android/` は git に入れない。ネイティブの変更は `app.json`・`app.config.js`・`plugins/` にだけ書く
3. **開発用と本番を別のアプリにする**: ID（`.dev`）・名前・アイコン・スキーム・Firebase のアプリ・App Group を、iOS も Android も分ける。切り替えは eas.json のプロファイルの `env`（`APP_VARIANT`）で行う
4. **ビルドのプロファイルを3つにする**: development / preview（社内配布）/ production。審査に出すのは production だけ
5. **ストアから入れたアプリではデバッグと開発用の OTA を必ず切る**ガードを入れる（インストール元で判定）
6. **OTA の設定を最初に済ませる**: 本番と開発でチャネルと鍵を分ける。コード署名を入れる。手元ビルドの Android は資源名の短縮と CodePush の目録の圧縮を切る。最初の APK を配る前に、エミュレーターで OTA が当たるのを確かめる
7. **設定の一番下に「版・ビルド番号・OTA の番号」を出す**
8. **`npm run check`（型・lint・書式・テスト）を初回のコミットで入れる**。`app.json`・`eas.json` は Prettier から外す
9. **秘密は初日から git に入れない**: `.env`・鍵の JSON・`google-services.json`・ビルドの成果物を `.gitignore` に入れる。鍵ごとに「使っている場所の一覧」を作る（[setup.md](setup.md)）
10. **時刻は1つの入口から取る**: `now()` と「今日」を1か所にまとめ、デバッグで動かせて、lint で `new Date()` を止める
11. **分析は送信をキューにためる**: 初期化を待たずに送ると捨てられる。自動のスクリーン計測は切る。値は型で文字列に強制する。開発用アプリは `traffic_type=internal`
12. **ストアの名前を両方のストアで確かめる**: App Store の名前は取られていることが多い
13. **問い合わせの窓口とストアの通知を作った日にオンにする**: フォームのメール通知、Play Console のメール、App Store Connect のアプリのプッシュ

## トピック別の詳細

作業に入る前に、該当するファイルを読む。

| ファイル | 中身 |
|---------|------|
| [setup.md](setup.md) | 雛形・CNG・開発用の分離・版とビルド番号・秘密・手元ビルド・worktree |
| [ota.md](ota.md) | Revopush の OTA・チャネル・届いたかの確かめ方・ネイティブを変えたとき |
| [store.md](store.md) | App Store・Google Play の申請、審査メモ、スクショ、ASO、申告 |
| [billing.md](billing.md) | RevenueCat・Play と Apple の課金の設定、購入の試し方、権利の扱い |
| [analytics-privacy.md](analytics-privacy.md) | Firebase・GA4 の計測、テスト端末の除外、プライバシーポリシー、EU |
| [native-features.md](native-features.md) | 通知・ウィジェット・バックグラウンド・時刻・データの保存とバックアップ |
| [ui.md](ui.md) | モバイルの基本、OS ごとの落とし穴、ユーザーが繰り返し言った好み |
| [working-with-user.md](working-with-user.md) | Claude の進め方でユーザーが不満を言ったこと |

## 新しくハマったら

このスキルに足す。アプリ固有のことはそのアプリの CLAUDE.md に、どのアプリでも起きることはここに書く。
