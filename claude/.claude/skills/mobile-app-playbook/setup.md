# セットアップ・ビルド

## 雛形

- 土台は一番新しいアプリ（今は `~/works/gunubin/restcall`）から持ち込む。持ち込むのは画面の部品・設定画面の並び・版の表示・デバッグのページ・lint と Prettier の設定・i18n・Firebase の任意読み込み。設計は持ち込まない
  - RestCall では「NoPace の工夫を本当に参考にしているか」とユーザーに言われた。持ち込むものを列挙してから始める
- UI キットや、Babel・Metro で変換するスタイリング（NativeWind・gluestack）は入れない。SDK の更新の足かせになった。StyleSheet とテーマのトークンで書く
- 自作の枠組みを作らない。フォームは react-hook-form＋zod、データの取得は TanStack Query（書いてから invalidate）。「やっぱり普通の使い方がよい」
- ライブラリは採用前に最終更新日と New Architecture 対応を確かめる（止まっている draggable-flatlist で並び替えがずれた）
- 回避策のコードには issue 番号と「いつ消すか」を書く。古い回避策が後で不具合の原因になった
- Expo の autolinking は `react-native.config.js` の null を無視する。プラットフォーム別の除外は `expo.autolinking.<platform>.exclude`
- `expo install` が typescript を dependencies に入れることがある。devDependencies に移す

## CNG

- `ios/`・`android/` を git に入れていると、app.json の変更が効かず、SDK を上げても古いまま残る
- ネイティブを手で書き換えたくなったら config plugin にする

## 開発用と本番の分離

- 同じ ID だと、入れ直すたびにデータが消え、本番アプリで確かめるしかなくなる
- iOS も最初から分ける。あとから分けると、本体・ウィジェット・intents の3ターゲットで半日〜1日かかる見積もりになった
- `app.config.js` で `EAS_BUILD_PLATFORM` を見て切り替えない。手元の EAS CLI はこれを入れずに評価する。プロファイルの `env` に置き、`eas config` で解決結果を確かめる
- ウィジェット・拡張の `deploymentTarget` を本体とそろえる（ずれて Xcode 27 のビルドが落ちた）

## 版とビルド番号

- 正を1か所に決める（EAS の `appVersionSource: remote` か手動か）。決めたらアプリの CLAUDE.md に書く
- Claude はビルド番号を手で書き換えない。提出の直前に書き換えて、ユーザーに強く怒られた
- 製品ビルドはコミット済みのきれいな状態から作り、タグを打つ
- 止めた・失敗したビルドもビルド番号（versionCode）を1つ使う
- ネイティブを変えたら `version` を上げる（[ota.md](ota.md)）

## 手元ビルド

- EAS のクラウドビルドは無料枠と順番待ちがある。ビルドは手元（`--local`）、配るのだけ EAS
- 開発用 APK の共有は GitHub の Pre-release（`v<版>-dev`）。`eas upload` は月の枠がすぐ尽きる
- Firebase を入れたら Gradle のメモリを増やす（`org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m`）
- Gradle と Kotlin のデーモンが CPU を食う。`org.gradle.workers.max=6`、ビルド後に `./gradlew --stop`
- ディスクを食う（Gradle のキャッシュ 20GB、失敗したビルドの `$TMPDIR/eas-build-local-nodejs`）。ビルド前に空きを確かめる。dotfiles に週1の掃除がある
- R8（minify）は製品ビルドだけで効く。WorkManager などが削られる。ネイティブを変えたら release ビルドを実機かエミュレーターで試す
- `ITSAppUsesNonExemptEncryption: false` を入れておく（輸出コンプライアンスを毎回聞かれる）
- `CFBundleLocalizations: ["en","ja"]` を最初から入れる。ないと App Store で「言語：英語」と出る

## EAS の credentials

- 最初の credentials は、ユーザーが自分のターミナルで対話的に作る。`!` 付きのコマンドは stdin を読めず Apple のログインで止まる

## 秘密

- 鍵の JSON・`.env`（Webhook の URL など）がコミットされていたことがある。初日に `.gitignore` に入れる
- 鍵ごとに「使っている場所の一覧」（EAS・GitHub Secrets・RevenueCat・Workers の secret・1Password）を作る。作り直したら一覧を全部回る。Play の鍵を作り直して RevenueCat だけ古いまま、2日間 Android の購入を確かめられなかった
- 環境変数の名前は用途ごとに分ける。同じ名前を別の送り先だと思い込んで、別のチャンネルに通知した
- 値がないときに黙って飛ばさない。ログに出す
- 1Password は Mac での認証が要るので、外出中や寝ている間は止まる。一時的に環境変数へ入れたら、戻ってから消す

## 並行で作業するとき

- 1セッションに1つの worktree と1つのシミュレーター（端末 ID で固定）。共有すると、他のセッションの未コミットの変更で型が落ちる、競合マーカーで Metro が起きない、ユーザーが触っているシミュレーターを閉じる、が起きた
- worktree ごとに Metro のポートを固定する。node_modules はシンボリックリンクではなく APFS のクローンでコピーする
- tmux の中で watchman が動かないことがある。`METRO_NO_WATCHMAN=1` で切るスイッチと、jest の `--no-watchman` を雛形に入れる
- 型付きルート（`.expo/types/router.d.ts`）は起動したときに作られる。起動していない作業ツリーでは typecheck だけ落ちる
- エミュレーターは使い終わったら `adb emu kill`。残っていると二重起動になる

## Android の期限

- targetSdk の期限（毎年8/31、延長で11/1）を予定に入れる。過ぎてから慌てて Android だけ SDK を上げた
- edge-to-edge が強制される。下端の要素は最初から inset を足し、ジェスチャーと3ボタンの両方のナビで確かめる
- 確かめる AVD は対象の最新 OS（API 36・37）で作る。`.ini` の `target=` が `android-0` だと仮想化が効かず落ちる。`-gpu host` で起動する
