# Komap 古地図巡り

現在のGoogle Map上に古地図を重ね合わせ、自分が歩いている場所の「昔の姿」をAIが解説してくれる、
時間旅行気分の散策アプリです。iOSアプリで保存した「わたしの時間旅行」は、Webアプリ
（`map.ktrips.net`）からも同じGoogleアカウントでログインして見ることができます。

## 主な機能

- 現在地をGoogle Map上に表示（現在の一般的な地図表示）
- 江戸時代の古地図（サンプル：江戸城周辺・浅草周辺）を現在の地図に重ねて表示
- スライダーで「現在の地図」⇔「古地図」の濃さ（不透明度）を自由に調整
- 地図上の好きな地点をタップ（または現在地ボタン）すると、AIがその場所の昔の出来事や物語を生成
- 気に入った物語は「わたしの時間旅行」として端末に保存し、後から一覧・詳細で見返せる
- Googleでサインインすると、保存した地点がクラウド（Firestore）に同期され、
  Webアプリ（`map.ktrips.net` を予定）でも同じ記録を閲覧できる

## 技術構成

| 項目 | 内容 |
|---|---|
| iOS UI | SwiftUI（iOS 17+） |
| iOS 地図 | Google Maps SDK for iOS（Swift Package Manager） |
| 位置情報 | CoreLocation |
| ローカル保存 | SwiftData（保存した地点・物語） |
| AI | OpenAI Chat Completions API（`gpt-4o-mini`） |
| クラウド同期 | Firebase Authentication（Googleサインイン） + Cloud Firestore |
| Webアプリ | Vite + React + TypeScript、Firebase JS SDK、Google Maps JavaScript API |
| iOSプロジェクト管理 | [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`project.yml` から `.xcodeproj` を生成） |

`.xcodeproj` はリポジトリにコミットせず、`project.yml` から都度生成する運用です（`.gitignore` 済み）。

## リポジトリ構成

```
project.yml                 # iOS: XcodeGenのプロジェクト定義
Config/Secrets.xcconfig     # iOS: APIキー（Google Maps）などのビルド設定
Komap/                      # iOSアプリ本体（詳細は後述）
firebase.json               # Firebase Hosting / Firestore の設定
.firebaserc                 # Firebaseプロジェクトのエイリアス（要編集）
firebase/
  firestore.rules            # Firestoreセキュリティルール（本人のデータのみ読み書き可）
  firestore.indexes.json
web/                         # Webアプリ本体（Vite + React）
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
firebase deploy --only firestore:rules
```

> `firebase/firestore.rules` は「自分の `users/{uid}/places/**` のみ読み書き可能」という
> シンプルなルールです。iOSアプリ・Webアプリはどちらもこのルールの下で、
> 同じFirebase Authenticationの `uid` を使ってアクセスします。

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
（Authentication → Settings → Authorized domains）。

---

## 古地図データについて（重要な注意）

同梱している古地図画像（江戸城周辺・浅草周辺）は、このサンプルアプリのために生成した
**古地図"風"のイラスト画像**であり、実際の歴史史料をスキャンしたものではありません。
また、それぞれの画像に設定している緯度経度の位置合わせ座標
（`Komap/Models/HistoricalOverlayMap.swift` 内の `southWest` / `northEast`）も、
現在の地理に大まかに合わせた**仮の値**です。

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
    HistoricalOverlayMap.swift  # 古地図カタログ（画像・時代・位置合わせ座標）
    TappedPoint.swift
  Services/
    LocationManager.swift       # 現在地の取得
    AIHistoryService.swift      # OpenAI APIで物語を生成
    KeychainStore.swift         # APIキーの安全な保存
    SecretsConfig.swift         # APIキーの読み込み口
    AuthService.swift           # Googleサインイン → Firebase Auth
    SyncService.swift           # Firestoreへの地点の同期（アップロード/取得）
  Views/
    RootView.swift
    Map/                         # マップ画面・古地図オーバーレイ・物語シート
    SavedPlaces/                 # 保存済み地点の一覧・詳細
    Settings/                    # APIキー設定・Googleサインイン
  Resources/
    Assets.xcassets              # 古地図画像などのアセット
    Info.plist                   # xcodegenが project.yml から自動生成（コミット対象外）
    GoogleService-Info.plist     # 各自のFirebase設定（要配置・コミット対象外）
```

## 既知の制約・今後の拡張候補

- 古地図の位置合わせはサンプル用の仮座標です（上記「古地図データについて」を参照）。
- Google MapsのAPIキーはアプリ内からは変更できません（ビルド時のxcconfigのみ）。
  実運用では課金設定・APIキーの制限（Bundle ID制限など）も併せて設定してください。
- AIの物語生成はOpenAI APIキーが必要で、通信環境とAPI利用料が発生します。
- Firebase未設定のままでもiOSアプリは起動できますが、クラウド同期・Web連携・
  Googleサインインは利用できません（設定タブにその旨のメッセージが表示されます）。
- Sign in with Appleは未対応です（無料のApple IDでは使えないため。上記1-4の注記を参照）。
- Webアプリはmap一覧の閲覧が中心で、古地図画像のオーバーレイ表示は現時点では未対応です
  （地点ごとの時代・古地図タイトルはラベルとして表示されます）。
- 現在は古地図2種（江戸城周辺・浅草周辺）のサンプルのみですが、
  `OldMapCatalog` にエントリを追加するだけで拡張できます。
