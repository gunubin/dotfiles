# 課金（RevenueCat）

## Play の課金を始めるまで（一式）

あとから気づいて足したものばかりなので、課金を入れる日に全部やる。

1. Play の販売者アカウントとお支払いプロファイル。価格の基準国がアイルランドになっていないか確かめる
2. RevenueCat 用のサービスアカウントの JSON を RevenueCat に上げる
3. Play Console でそのアカウントに「財務データの表示」と「注文の管理」
4. サービスアカウントに Pub/Sub 管理者（`roles/pubsub.admin`）。ないと RevenueCat の鍵の検証が赤いエラーになる。「Valid credentials」になるまで確かめる
5. 返金を知らせる設定（Google developer notifications / RTDN）: Pub/Sub のトピックを作って RevenueCat につなぎ、Play Console の収益化の設定にも入れる。`google-play-developer-notifications@system.gserviceaccount.com` に Pub/Sub パブリッシャー
6. RevenueCat の既定の Offering を作る。ないと開発ビルドで毎回 `Error fetching offerings` が出る
7. 課金入りのビルドを一度トラックに上げてから商品を作る

- サービスアカウントの連携は最大36時間かかる
- GCP の IAM の権限付けは Claude の安全装置で止まるので、ユーザーに付けてもらう
- 購入を承認（acknowledge）しないと3日で自動返金される

## 購入の試し方を最初に決める

- 別 ID の開発用アプリでは Play の商品を読み込めない。商品は本番のパッケージにだけ付く
- 公開前のアプリで「アイテムが見つかりません」と出るのは内部テストに参加していないため。ライセンス テスターは開発者アカウント全体の設定
- ライセンス テスターで買い切りを買うと消えない。戻すには Play Console で払い戻しをし、「権利の取り消し」まで付ける。Play 側から払い戻すと RevenueCat が気づくまで最大24時間。RevenueCat の画面の Refund ならすぐ外れる
- テスト購入は RevenueCat の「Sandbox data」をオンにしないと見えない
- iOS の Sandbox は購入履歴を消しても非消耗型が残る。新しい Sandbox テスター（`+` 付きのアドレス、国は日本）を作り、端末の Sandbox アカウントを切り替え、アプリを入れ直す
- 直接入れた本番のバイナリでだけ開くデバッグに「Pro の段階を上書き」「購入を確かめ直す」「RevenueCat で自分の購入を開く」を置く。ストアから入れたアプリでは開けない
- 本番で本物を買って確かめない（Pro でない人の画面が見られなくなる、売上の数字が汚れる、手数料で損する）
- Sandbox の購入が本物と同じ形で Slack に届いて慌てた。連携で Sandbox のイベントを切る

## 権利の扱い

- **権利の状態を保存した値に頼らない**。AsyncStorage に権利の JSON を保存していたら、前の版の値に新しいフィールドがなく、アップデート直後に課金済みの人が止められた。RevenueCat の entitlement から毎回組み立てる。キャッシュするなら段階（level）だけ
- 有料の上限は保存する処理（UseCase）の中で判定する。描画した時点の件数で判定すると、連打で上限を超えられる
- Pro の判定と同期で `Platform.OS` によって分けない。起動時の同期が iOS でしか動いておらず、Android で買った人が次の起動で Pro を失うところだった
- 読み取りに失敗したときに「新規ユーザー」などの判定を永久に保存しない

## 購入の処理

- 二重タップは state ではなく ref で防ぐ
- `PAYMENT_PENDING_ERROR` は失敗ではなく承認待ちとして分ける
- 値段の読み込みにタイムアウトと再試行を付ける（本番で値段がぐるぐるのまま止まった）
- 購入は GA4 の標準の `purchase` に金額・通貨・`transaction_id` を付けて送る。独自のイベントだけでは収益に入らない。開発用アプリからは送らない
