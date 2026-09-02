# Komap 古地図巡り

現在のGoogle Map上に古地図を重ね合わせ、自分が歩いている場所の「昔の姿」をAIが解説してくれる、
時間旅行気分の散策アプリです。iOSアプリ本体に加えてApple Watch単体でも記録でき、
保存した「My Trips（私の時空旅）」はWebアプリ（`komap.ktrips.net` など）からも
同じGoogleアカウントでログインして見ることができます。

## 主な機能

### 地図・古地図まわり
- 現在地をGoogle Map上に表示（現在の一般的な地図表示）
- 江戸〜明治期の古地図（同梱サンプル、詳細は後述）を現在の地図に重ねて表示
- スライダーで「現在の地図」⇔「古地図」の濃さ（不透明度）を自由に調整
- 「全ての古地図を表示」を選ぶと、同梱・登録済みの古地図とチェックポイントを
  地図上にまとめて重ねて見られる（タップするとその古地図単体の表示に切り替わる）
- OpenAI + Google カスタム検索を使って、新しい古地図をその場で検索して追加する機能
- 地図上の好きな地点をタップ（または史跡チェックポイントのアイコン）すると、
  AIがその場所の昔の出来事や物語を生成

### 記録・ゲーミフィケーション
- 「スタート」でGPSによる徒歩ルートの記録を開始。「完了」を押すと、大きな「保存」ボタンと
  小さな「破棄」ボタン（誤操作防止の確認つき）で記録を残すか選べる
- Apple Watch単体でも同じ記録ができ（iPhoneを開いていなくても可）、iPhone側にも
  リアルタイムで軌跡・御朱印・写真投稿が同期される
- 古地図ごとに置かれた史跡チェックポイントに近づくと「御朱印」を自動で獲得
- ウォーキング中に自由なタイミングで写真を投稿するとポイントを獲得（史跡の御朱印時の写真とは別枠）
- 「My Trips（私の時空旅）」タブで、歩いた記録を古地図ごとにグルーピングして一覧表示。
  御朱印・アップした写真（チェックポイント／プラスポイントに分けて4枚横並び）・
  保存した物語もまとめて見返せる

### クラウド連携
- Googleでサインインすると、保存した地点・御朱印・時間旅（歩いたルート）・投稿写真がクラウド
  （Firestore）に同期され、Webアプリからも同じ記録を閲覧できる
- 御朱印・投稿写真の画像本体はFirebase Storageへ自動アップロードされ、Web側やシェア時にも
  画像そのものを見られる
- Webアプリの「時空旅」タブでは、自分の記録（My Trips）に加えて他ユーザーが共有した
  時間旅（sharedTrips）も選択して、地図・写真・御朱印を表示できる

## 技術構成

| 項目 | 内容 |
|---|---|
| iOS UI | SwiftUI（iOS 17+） |
| iOS 地図 | Google Maps SDK for iOS（Swift Package Manager） |
| 位置情報 | CoreLocation |
| Watch連携 | Apple Watch単体アプリ（WatchOS）+ WatchConnectivity |
| ローカル保存 | SwiftData（保存した地点・物語・時間旅・御朱印・投稿写真） |
| AI | OpenAI Chat Completions API（`gpt-4o-mini`） |
| クラウド同期 | Firebase Authentication（Googleサインイン） + Cloud Firestore + Firebase Storage（画像） |
| Webアプリ | Vite + React + TypeScript、Firebase JS SDK、Google Maps JavaScript API |
| iOSプロジェクト管理 | [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`project.yml` から `.xcodeproj` を生成） |
| CI/CD | GitHub Actions（`main`へのpushでWebアプリをFirebase Hostingへ自動デプロイ） |

`.xcodeproj` はリポジトリにコミットせず、`project.yml` から都度生成する運用です（`.gitignore` 済み）。

## リポジトリ構成

```
project.yml                 # iOS: XcodeGenのプロジェクト定義（iOS + Watchの両ターゲット）
Config/Secrets.xcconfig     # iOS: APIキー（Google Maps）などのビルド設定
Komap/                      # iOSアプリ本体（詳細は後述）
Komap Watch App/             # Apple Watch単体アプリ（スタート/一時停止/終了・保存確認など）
firebase.json               # Firebase Hosting / Firestore の設定
.firebaserc                 # Firebaseプロジェクトのエイリアス（要編集）
firebase/
  firestore.rules            # Firestoreセキュリティルール（本人のplaces/stamps/walkRoutes/photoPostsのみ読み書き可、sharedTripsは閲覧のみ全員可）
  firestore.indexes.json
  storage.rules               # Firebase Storageセキュリティルール（御朱印・投稿写真の画像本体）
web/                         # Webアプリ本体（Vite + React）
.github/workflows/
  deploy-web.yml              # main へのpushでWebアプリをFirebase Hostingへ自動デプロイ
```

---

## Part 1: iOSアプリのセットアップ

### 1-1. 前提ツール

- Xcode（最新版を推奨。iOS 17以降のシミュレータ/実機が必要）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

### 1-2. Google Maps APIキーの取得と設定

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクトを作成し、
   「Maps SDK for iOS」を有効化してAPIキーを発行します。
   （手順: https://developers.google.com/maps/documentation/ios-sdk/get-api-key）
2. `Config/Secrets.xcconfig` を開き、`GOOGLE_MAPS_API_KEY` に発行したキーを設定します。

```
GOOGLE_MAPS_API_KEY = ここに実際のAPIキーを貼り付け
```

> このキーが未設定（デフォルト値のまま）の場合、アプリ起動時にセットアップ案内画面が表示され、
> 地図タブは利用できません。

### 1-3. OpenAI APIキーの設定

- [OpenAI Platform](https://platform.openai.com/) でAPIキーを発行してください。
- キーはビルド時に設定する必要はありません。アプリを起動し、「設定」タブから入力すると、
  端末のKeychainに安全に保存されます。
- （任意）`Config/Secrets.xcconfig` の `OPENAI_API_KEY_DEFAULT` に設定すると、
  初回起動時のデフォルト値として使われます（開発・検証用途を想定）。

### 1-4. Firebase（Web連携）のセットアップ

Web（`map.ktrips.net`）で「自分のマップ」を見られるようにするには、Firebaseの設定が必要です。
不要であればスキップしても、iOSアプリ単体（ローカル保存のみ）は動作します。

1. [Firebase Console](https://console.firebase.google.com/) で新しいプロジェクトを作成します。
2. 「Authentication」→「Sign-in method」で **Google** プロバイダを有効化します。
   - GoogleサインインはFirebaseプロジェクト自身のOAuthクライアントを自動的に使うため、
     追加のキー発行は不要です。「有効にする」→サポートメールを選択→保存、のみで使えるようになります。
   - iOS側で使うには、後述の「1-4-1. iOSでGoogleサインインを使うための追加設定」も行ってください。
3. 「Firestore Database」を作成します（本番モードでOK。ルールは後述のものをデプロイします）。
3-1. 「Storage」を開き、「開始する（Get started）」でStorageバケットを作成します
   （御朱印・投稿写真の画像本体を保存するために必要です）。**バケットのリージョンは
   後から変更できない**ため、利用者に近いリージョン（例: `asia-northeast1`）を選んでください。
   このバケットを作成しないまま`firebase deploy`でStorageルールをデプロイしようとすると、
   `Firebase Storage has not been set up on project ...` というエラーで失敗します。
4. 「プロジェクトの設定」→「マイアプリ」で **iOSアプリ** を追加します。
   - Bundle ID には `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER`（既定値 `com.komap.Komap`）を入力。
   - ダウンロードした `GoogleService-Info.plist` を `Komap/Resources/GoogleService-Info.plist`
     に配置してください（このファイルは`.gitignore`済みで、公開リポジトリにはコミットされません）。
5. 同じFirebaseプロジェクトに **Webアプリ** も追加し、表示された設定値を
   `web/.env` に設定します（Part 2を参照）。
6. Firebase CLIをインストールし、Firestoreのセキュリティルールをデプロイします。

> **注記: Apple Sign-inについて**
> このアプリはSign in with Appleには対応していません。Sign in with Appleの
> Capabilityは、無料のApple ID（Personal Team）では使用できず、有料のApple
> Developer Program（年間$99）への登録が必須のためです。Google
> サインインはこの制約がなく、無料のApple IDでも問題なく使えます。
> 有料のDeveloper Programに登録済みで、Apple Sign-inも追加したい場合は、
> `project.yml` の `Komap` ターゲットに以下の `entitlements` セクションを追加し、
> `Komap/Services/AuthService.swift` にApple版のサインイン処理
> （`ASAuthorizationController` を使ったフロー）を実装してください。
>
> ```yaml
> entitlements:
>   path: Komap/Komap.entitlements
>   properties:
>     com.apple.developer.applesignin:
>       - Default
> ```

```bash
npm install -g firebase-tools
firebase login
# .firebaserc の "YOUR_FIREBASE_PROJECT_ID" を実際のプロジェクトIDに書き換えてから:
firebase deploy --only firestore:rules,storage
```

> Storageルールのデプロイ対象は `storage:rules` ではなく `storage` を指定してください。
> このプロジェクトのようにStorageバケットが1つだけの構成では、`storage:rules`は
> `Could not find rules for the following storage targets: rules` というエラーで
> 失敗します（`storage:rules`は`firebase.json`で複数バケットをtarget指定している
> 構成向けの書き方です）。また、上記の手順3-1でStorageバケットを作成する前に
> このコマンドを実行すると失敗します。

> `firebase/firestore.rules` は「自分の `users/{uid}/places` `stamps` `walkRoutes`
> `photoPosts` 配下のみ読み書き可能、`sharedTrips`（みんなの時空旅）はサインインしていれば
> 誰でも閲覧可・書き込みは本人のみ」というルールです。iOSアプリ・Webアプリはどちらも
> このルールの下で、同じFirebase Authenticationの `uid` を使ってアクセスします。

### 1-4-1. iOSでGoogleサインインを使うための追加設定

上記手順で `GoogleService-Info.plist` を配置していれば、GoogleサインインのクライアントID
自体は自動的に読み込まれます。ただし、認証完了後にアプリへ戻ってくるためのURL Schemeを
別途設定する必要があります。

1. 配置した `GoogleService-Info.plist` を開き、`REVERSED_CLIENT_ID` の値
   （`com.googleusercontent.apps.` から始まる文字列）をコピーします。
2. `Config/Secrets.xcconfig` の `GOOGLE_REVERSED_CLIENT_ID` に、コピーした値を貼り付けます。

```
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

3. `xcodegen generate` を再実行して、Info.plistのURL Schemeに反映してください。

> この値を設定しないと、Googleサインインのボタンを押してもアプリに認証結果が
> 返ってこず、サインインが完了しません。

### 1-5. プロジェクトの生成とビルド

```bash
cd kmap
xcodegen generate
open Komap.xcodeproj
```

Xcodeが開いたら、Signing & Capabilities でご自身のDevelopment Teamを選択し、
シミュレータまたは実機を選んで実行してください（Googleサインインはシミュレータでも
ブラウザ経由でサインインできます）。

`project.yml` を変更した場合は、再度 `xcodegen generate` を実行してください。

---

## Part 2: Webアプリ（map.ktrips.net）のセットアップ

Webアプリは `web/` ディレクトリにあります。iOSアプリと同じFirebaseプロジェクトの
Firestoreを読むことで、「自分のマップ」をブラウザからも閲覧できます。

> 今回作成したのはWebアプリのコードとFirebase設定ファイルのみです。
> 実際に `map.ktrips.net` というドメインで公開するには、Firebase Hostingへのデプロイと
> ドメインのDNS設定をご自身のFirebase/ドメイン管理アカウントで行ってください。

### 2-1. 環境変数の設定

```bash
cd web
npm install
cp .env.example .env
```

`.env` を開き、Firebase Console の「プロジェクトの設定」→「マイアプリ」→Web アプリで
表示される値と、Web用に発行したGoogle Maps APIキー（JavaScript API有効化、
HTTPリファラーを `map.ktrips.net` や `localhost` に制限したもの）を設定してください。

```
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=...
VITE_FIREBASE_PROJECT_ID=...
VITE_FIREBASE_STORAGE_BUCKET=...
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
VITE_GOOGLE_MAPS_API_KEY=...
```

### 2-2. ローカルで動作確認

```bash
npm run dev
```

表示されたローカルアドレス（既定では `http://localhost:5173/`）をブラウザで開いてください。
iOSアプリで使ったのと同じGoogleアカウントでサインインすると、
iOS側で保存した地点がリアルタイムに表示されます。

### 2-3. 本番公開（map.ktrips.net）へのデプロイ

```bash
cd web
npm run build
cd ..
firebase deploy --only hosting
```

デプロイ後、Firebase Console の「Hosting」→「カスタムドメインを追加」で
`map.ktrips.net` を接続し、案内されるDNSレコード（TXT/A等）をドメインのDNS設定に
追加してください。有効化されるまで数分〜数十分かかることがあります。

GoogleサインインはWeb上では追加設定なしで動作します（Firebase Consoleで
Googleプロバイダを有効化するだけです）。ただし本番ドメイン（`map.ktrips.net`）を
Firebase Authenticationの「承認済みドメイン」に追加しておく必要があります
（Authentication → Settings → Authorized domains）。カスタムドメインを複数接続した場合は、
それぞれをこの承認済みドメインに追加してください。

### 2-4. GitHub Actionsでの自動デプロイ

`web/**`・`firebase.json`・`firebase/**` を変更して`main`ブランチにpushすると、
`.github/workflows/deploy-web.yml` が自動的にWebアプリをビルドし、Firebase Hosting と
Firestore/Storageルールへデプロイします（手動で`workflow_dispatch`から実行することも可能）。

利用するには、GitHubリポジトリの Settings → Secrets and variables → Actions に、
以下のRepository secretsを登録してください。

| Secret名 | 内容 |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | デプロイ用サービスアカウントのJSONキー（下記手順で発行） |
| `VITE_FIREBASE_API_KEY` 他 `VITE_FIREBASE_*` | `web/.env` と同じ値（2-1を参照） |
| `VITE_GOOGLE_MAPS_API_KEY` | `web/.env` と同じ値 |

サービスアカウントは、Hosting・Firestore/Storageルールのデプロイだけができる最小権限で
発行することを推奨します。`roles/firebasestorage.admin`が無いと、Storageルールの
デプロイだけが `Deploy to Firebase Hosting + Firestore/Storage rules` ステップで
失敗します（Hosting・Firestoreは成功するため気づきにくい点に注意してください）。

```bash
gcloud iam service-accounts create github-actions-deploy \
  --project=YOUR_FIREBASE_PROJECT_ID \
  --display-name="GitHub Actions (Firebase deploy)"

for role in roles/firebasehosting.admin roles/firebaserules.admin roles/firebasestorage.admin roles/datastore.indexAdmin; do
  gcloud projects add-iam-policy-binding YOUR_FIREBASE_PROJECT_ID \
    --member="serviceAccount:github-actions-deploy@YOUR_FIREBASE_PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role"
done

gcloud iam service-accounts keys create github-actions-deploy-key.json \
  --iam-account=github-actions-deploy@YOUR_FIREBASE_PROJECT_ID.iam.gserviceaccount.com
```

発行した `github-actions-deploy-key.json` の**中身**（JSON全体）を `FIREBASE_SERVICE_ACCOUNT`
シークレットに貼り付けたら、ローカルのキーファイルは削除してください。漏洩した場合は
`gcloud iam service-accounts keys delete` で失効できます。

---

## 古地図データについて（重要な注意）

同梱している古地図は、大きく3種類に分かれます（いずれも `Komap/Models/HistoricalOverlayMap.swift`
の `OldMapCatalog` で定義）。

- **イラスト画像**（江戸城周辺・浅草周辺）: このサンプルアプリのために生成した
  **古地図"風"のイラスト**で、実際の歴史史料をスキャンしたものではありません。
- **実在の歴史地図**（本郷・谷中／上野／日本橋／芝／神田／東海道／中山道／
  松尾芭蕉ゆかりの地／霞ヶ関・虎ノ門／明治神宮・表参道・神宮外苑、および
  「五色不動めぐり」「九段下・千鳥ヶ淵」）:
  「1891 Meiji Map of Tokyo or Edo, Japan」
  （Geographicus発行、1931年より前の発行につきパブリックドメイン。出典: Wikimedia Commons）
  の実画像（フル解像度3500×2610pxの原本）を、エリアごとに切り出す、または広域のまま
  使ったものです。位置合わせは地図上の目印（不忍池・皇居のお堀等）を基準に手作業で
  行った概算で、史料的に厳密な測量座標ではありません。「五色不動めぐり」
  「九段下・千鳥ヶ淵」は、専用に切り出した画像を用意せず広域画像をそのまま使い回している
  テーマ別ルートで、旧東京市の外側にあたる地域（目黒・世田谷・品川区南部など）も含む
  広域表示のため、地図の密度が粗く、位置合わせもより概算になります。
  「東海道」「中山道」「松尾芭蕉ゆかりの地」「霞ヶ関・虎ノ門」「明治神宮・表参道・
  神宮外苑」は、同じ原本から専用に切り出した画像（それぞれ日本橋〜京橋・新橋、
  本郷〜小石川・巣鴨、深川〜浅草・本所、外務省・海軍省・麹町区一帯、原宿・代々木一帯
  にかけてのエリア）を使っていますが、原本の解像度・記載範囲の都合上、品川宿・板橋宿・
  千住といった各街道の終点そのものまでは画像に収まっていません（チェックポイント自体は
  現在地の緯度経度に正しく配置されるため、御朱印機能自体には影響しません）。なお
  「明治神宮・表参道・神宮外苑」は、明治神宮の鎮座（1920年）より前の1891年の地図のため、
  神社そのものは描かれておらず、その前身にあたる代々木御料地・青山練兵場一帯が写っています。
- **現在の地図から加工した「古地図風」画像**（赤坂・紀尾井町／麻布・六本木／
  大山街道〈赤坂〜二子玉川〉）: 実際の歴史史料ではなく、現在の地図から作成した画像に
  セピア調のフィルター（減彩・セピア変換・ビネット・粒状ノイズ）をかけて古地図"風"に
  加工したものです。「赤坂・紀尾井町」「麻布・六本木」は、アプリ内の現在の地図
  （チェックポイントのピン付き）のスクリーンショットから、ピンアイコン類をOpenCVの
  [inpaint](https://docs.opencv.org/)で除去した上でフィルターをかけています。
  「大山街道」は、[OpenStreetMap](https://www.openstreetmap.org/copyright)のタイル画像
  （© OpenStreetMapコントリビューター、ODbL）をそのまま結合してフィルターをかけたもので、
  ピン等が写り込んでいないためinpaintは行っていません。位置合わせ座標は、画像に写っている
  実在の駅・交差点（四ツ谷・青山一丁目・麻布十番など）の緯度経度、またはOpenStreetMapタイル
  座標から正確に算出しています。

いずれの画像も、設定している緯度経度の位置合わせ座標
（`OldMapCatalog` 内の `southWest` / `northEast`）は、現在の地理に大まかに合わせた
**仮の値**です。

実際の史料に基づく古地図を使いたい場合は、次の手順で入れ替えてください。

1. 実際の古地図画像（できれば矩形に近い形でトリミング済みのもの）を用意する。
2. `Komap/Resources/Assets.xcassets` 内に新しいImage Setを追加し、画像を登録する。
3. `Komap/Models/HistoricalOverlayMap.swift` の `OldMapCatalog` に、
   画像名・時代・タイトルと合わせて、画像の南西端・北東端の緯度経度
   （できるだけ正確に位置合わせしたもの）を追加する。
4. `OldMapCatalog.all` に追加したエントリを登録すると、アプリ内のピッカーから選択できるようになる。
5. （任意）Web側でも時代ラベルを表示したい場合は、`web/src/lib/oldMapCatalog.ts` にも
   同じ `id` でエントリを追加してください。

## iOSアプリのプロジェクト構成

```
Komap/
  App/
    KomapApp.swift             # アプリのエントリーポイント（Google Maps / Firebase初期化）
  Models/
    SavedPlace.swift            # SwiftDataモデル（保存した地点・物語）
    WalkRoute.swift              # SwiftDataモデル（歩いた時間旅・軌跡）
    CollectedStamp.swift         # SwiftDataモデル（獲得した御朱印）
    WalkPhotoPost.swift          # SwiftDataモデル（投稿写真・ポイント）
    HistoricalOverlayMap.swift  # 古地図カタログ（画像・時代・位置合わせ座標）
    HistoricSite.swift           # 古地図ごとの史跡チェックポイント一覧
    TappedPoint.swift
  Services/
    LocationManager.swift       # 現在地・徒歩ルートの記録
    AIHistoryService.swift      # OpenAI APIで物語を生成
    KeychainStore.swift         # APIキーの安全な保存
    SecretsConfig.swift         # APIキーの読み込み口
    AuthService.swift           # Googleサインイン → Firebase Auth
    SyncService.swift           # Firestoreへの同期（地点・御朱印・時間旅）
    WatchConnectivityManager.swift # Apple Watchとのコマンド・状態のやり取り
    OldMapSearchService.swift    # AI + Google検索で新しい古地図を探す
  Views/
    RootView.swift
    Map/                         # マップ画面・古地図オーバーレイ・物語シート
    SavedPlaces/                 # 保存済み地点・時間旅の一覧・詳細
    MyTimeTrip/                  # 「My Trips」タブ（時間旅・御朱印・写真・物語）
    Settings/                    # APIキー設定・Googleサインイン
  Resources/
    Assets.xcassets              # 古地図画像・アプリアイコンなどのアセット
    Info.plist                   # xcodegenが project.yml から自動生成（コミット対象外）
    GoogleService-Info.plist     # 各自のFirebase設定（要配置・コミット対象外）
Komap Watch App/
  ContentView.swift              # Watch単体の記録UI（スタート/一時停止/完了・保存確認）
  WatchSessionManager.swift      # Watch単体のGPS記録 + iPhoneとの連携
  WatchWorkoutLocationTracker.swift # HealthKitワークアウトセッション経由の位置情報取得
```

## 既知の制約・今後の拡張候補

- 古地図の位置合わせはサンプル用の仮座標です（上記「古地図データについて」を参照）。
- Google MapsのAPIキーはアプリ内からは変更できません（ビルド時のxcconfigのみ）。
  実運用では課金設定・APIキーの制限（Bundle ID制限など）も併せて設定してください。
- AIの物語生成はOpenAI APIキーが必要で、通信環境とAPI利用料が発生します。
- Firebase未設定のままでもiOSアプリは起動できますが、クラウド同期・Web連携・
  Googleサインインは利用できません（設定タブにその旨のメッセージが表示されます）。
- Sign in with Appleは未対応です（無料のApple IDでは使えないため。上記1-4の注記を参照）。
- Webアプリの「時空旅」タブは、古地図ごとにまとめた時間旅の一覧・詳細（距離・時間・歩数など）
  に加え、選択した時間旅の地図（軌跡）・投稿写真・御朱印も表示できます。
- `OldMapCatalog` にエントリを追加するだけで、選べる古地図を拡張できます
  （Web側でも表示したい場合は `web/src/lib/oldMapCatalog.ts` にも同じ `id` で追加）。
