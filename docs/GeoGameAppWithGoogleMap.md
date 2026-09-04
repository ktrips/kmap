# 週末だけでできる！Google Mapを使った地図ゲームアプリを作る＆収益化する方法

---

## はじめに

「アプリを作ってみたい。でも本業もあるし、まとまった時間なんて取れない」——多くの個人開発者が最初にぶつかる壁は、技術力ではなく「時間」です。

本書は、この壁を「週末だけ」という制約の中で乗り越えるための実践ガイドです。題材として取り上げるのは、Google Mapと画像レイヤー（古地図や独自マップ）を組み合わせた「地図ゲームアプリ」。現在地に応じて古い地図や創作の世界地図を重ね合わせ、歩くこと自体をゲームにする——という、位置情報×ゲーミフィケーションの定番かつ拡張性の高いジャンルです。

筆者は実際に、Google Maps SDK・古地図オーバーレイ・GPSによる徒歩記録・チェックポイント（御朱印）収集・AIによる物語生成・Firebaseを使ったクラウド同期・Apple Watch連携・Web版展開までを、週末の空き時間を積み重ねる形で実装してきました。本書の技術パートは、この実体験にもとづく「実際に動いたコード」と「実際にハマった落とし穴」を土台にしています。

本書は大きく2部構成です。

- **第I部（開発編）**：企画からアーキテクチャ設計、Google Maps SDKの導入、画像オーバーレイの実装、位置情報記録、ゲーミフィケーション設計、AI連携、データ永続化とクラウド同期、Watch対応、Web版展開、テスト、そしてApp Store申請までを、週末単位のマイルストーンに分解して解説します。
- **第II部（収益化・マーケティング編）**：個人開発の地図ゲームアプリが現実的に収益を得るためのモデル選定、ASO（App Store最適化）、SNSとコミュニティを使った低予算マーケティング、リリース後のグロースサイクル、そして実例に基づくケーススタディを扱います。

「土日に2〜3時間ずつ触るだけで、数ヶ月後にはApp Storeに公開されたアプリがある」——そんな状態を目指す方に向けて書きました。プログラミング経験はあるが位置情報アプリやGoogle Maps SDKは初めて、という読者を主な対象としていますが、企画やマーケティングの章は非エンジニアの方にも読めるように構成しています。

それでは、最初の週末から始めましょう。

---

# 第I部　開発編：週末だけでGoogle Map地図ゲームを作る

## 第1章　地図ゲームアプリという企画の魅力

### 1-1. なぜ「地図×ゲーム」なのか

位置情報を使ったアプリは、スマートフォン向けアプリの中でも特に「体験の質」で差別化しやすいジャンルです。理由は3つあります。

1. **現実世界がそのままコンテンツになる**：ゲーム内の「マップ」を自分で作り込まなくても、ユーザーが実際に歩く道・訪れる場所がそのままステージになります。開発者が用意するのは「その場所に何を重ねるか」というレイヤーだけで済みます。
2. **外出という行動そのものに価値がある**：健康志向、観光需要、地域活性化といった社会的な文脈と相性が良く、自治体や観光協会との協業、地域メディアでの紹介など、広告費をかけずに露出を得られる経路が多い。
3. **「歩く→何かを集める」というループがゲームとして完成している**：位置情報ゲームの王道パターン（Ingress、ポケモンGOなど）がすでに市場で実証済みであり、ユーザー教育コストが低い。

本書で扱う「古地図オーバーレイ×ウォーキング記録」という切り口は、この中でも特にニッチかつ差別化しやすい領域です。史跡・郷土史・観光といった文脈に接続でき、かつ実装難易度は据え置きのまま「意味のある体験」を作れます。

### 1-2. 個人開発・週末開発に向いている理由

大規模なゲーム開発とは異なり、地図ゲームアプリは次の点で個人開発と相性が良好です。

- **コンテンツ制作がスケーラブル**：3Dモデルやアニメーションを大量に作る必要がなく、地図画像・史跡データ・簡単なテキスト（AIで生成可能）でコンテンツを増やせる。
- **サーバーサイドを自前で持たなくてよい**：Firebase（Firestore・Authentication・Storage・Cloud Functions）を使えば、バックエンドエンジニアリングの多くを外部サービスに委譲できる。
- **プラットフォームの地図基盤が使える**：Google Maps SDKやApple Mapsなど、地図描画・現在地取得・ジオコーディングといった重い実装はSDKが担ってくれる。
- **段階的にリリースできる**：「現在地に史跡ピンを立てるだけ」の最小版から始めて、古地図オーバーレイ、ゲーミフィケーション、AI生成、クラウド同期、Watch対応、Web版と、機能を積み増していくロードマップが自然に描ける。

### 1-3. 本書で作るアプリの全体像

本書を通して組み立てていくアプリは、次のような機能を持ちます（実際に本書の著者が開発したアプリの構成に基づいています）。

- 現在地をGoogle Map上に表示し、古地図（またはオリジナルのファンタジーマップ・観光マップなど）をオーバーレイ表示
- スライダーで「現在の地図」⇔「古地図」の透過度を調整
- 地図上のスポットをタップすると、AIがその場所にまつわる物語を生成
- 「スタート」でGPSによる徒歩ルートの記録を開始し、「完了」で保存
- 史跡チェックポイントに近づくと「御朱印」（コレクションアイテム）を自動獲得
- 徒歩中に自由なタイミングで写真を投稿できる
- Googleサインインでクラウド同期し、Webブラウザからも記録を閲覧
- Apple Watch単体でも記録可能
- いいね・コメントなどのソーシャル機能

すべてを最初から作る必要はありません。本書は「週末ごとに1つずつ機能を足していく」設計で章を並べています。読者は自分のアイデアに合わせて、必要な章だけをつまみ食いしても構いません。

### 1-4. 企画を固めるための3つの問い

開発に入る前に、次の3つの問いに答えておくと、後の設計判断がぶれません。

1. **誰が、どんな時に使うのか**（例：休日に散歩する人、旅行先で観光する人、子どもと一緒に地域の歴史を学びたい親）
2. **地図に重ねる「レイヤー」は何か**（古地図、架空の世界地図、スタンプラリー用のイラストマップ、ハザードマップなど）
3. **「集める」対象は何か**（史跡の御朱印、キャラクター、写真、称号、バッジ）

本書のサンプルでは「古地図」「御朱印」「AIが生成する物語」という組み合わせを採用していますが、たとえば「アニメの聖地巡礼マップ」「町内会のスタンプラリー」「防災訓練用のハザードマップウォーク」など、同じ技術基盤で全く異なる企画に転用できます。

---

## 第2章　週末開発のロードマップ設計

### 2-1. マイルストーンを「週末」で区切る

週末開発の最大の敵は「中途半端な状態で放置して、再開時に何をしていたか忘れる」ことです。これを防ぐには、1回の週末（土日で合計4〜8時間程度を想定）で完結する単位にタスクを分割し、必ず「動くもの」で終わることを目標にします。

以下は、本書のサンプルアプリを実際に組み立てる際のロードマップ例です。

| 週末 | ゴール |
|---|---|
| 第1週末 | Xcodeプロジェクトの雛形作成、Google Maps SDK導入、現在地表示まで |
| 第2週末 | 画像オーバーレイ（古地図）を1枚だけ表示、透過度スライダー実装 |
| 第3週末 | 複数の古地図を切り替えられるカタログ構造、位置合わせの仕組み |
| 第4週末 | GPSによる徒歩ルート記録の開始・停止・保存 |
| 第5週末 | 史跡チェックポイントの定義と、接近判定による自動獲得（御朱印） |
| 第6週末 | ローカル保存（SwiftDataなど）、記録一覧画面 |
| 第7週末 | OpenAI等のAI APIで物語生成、API keyの安全な管理 |
| 第8週末 | Firebase導入（Authentication・Firestore）、クラウド同期 |
| 第9週末 | 写真投稿機能、Firebase Storageへのアップロード |
| 第10週末 | Web版の雛形（Vite+React）、Firestore読み取り表示 |
| 第11週末 | Apple Watch単体アプリ、WatchConnectivity連携 |
| 第12週末 | いいね・コメント等のソーシャル機能、公開ページ |
| 第13週末以降 | テスト、審査対応、リリース準備、マーケティング準備 |

このロードマップはあくまで目安です。重要なのは「毎週末、必ず1つ動くものを増やす」という原則そのものです。

### 2-2. 「垂直スライス」で進める

ゲーム開発の世界には「垂直スライス（Vertical Slice）」という考え方があります。これは、機能を横断的に少しずつ作るのではなく、1つの体験を最初から最後まで（浅くてもいいので）通しで作ってしまう、という進め方です。

地図ゲームアプリの場合、最初の週末で目指すべき垂直スライスは次のようなものです。

> 「アプリを起動する → 現在地が地図に表示される → 1枚だけ古地図が重なって見える → 透過度スライダーで見た目が変わる」

この4ステップが動けば、それだけで「動くプロトタイプ」と呼べます。デザインが粗くても、古地図が1枚しかなくても構いません。ここから機能を継ぎ足していく方が、モチベーションを保ちやすく、途中で企画自体の見直しにも柔軟に対応できます。

### 2-3. 技術選定の指針：枯れた技術を選ぶ

週末開発では「学習コストの高い最新技術」よりも「情報量が多く、詰まった時に自力で解決しやすい枯れた技術」を優先すべきです。本書で採用する技術スタックは、いずれも実務で広く使われ、ドキュメントやコミュニティの情報が豊富なものです。

- **iOS UI**: SwiftUI（宣言的UIで学習コストが低く、変更が素早く反映される）
- **地図**: Google Maps SDK for iOS（Apple純正のMapKitより古地図オーバーレイやカスタマイズの自由度が高い）
- **位置情報**: CoreLocation（標準API）
- **ローカル保存**: SwiftData（iOS 17以降の標準永続化フレームワーク）
- **AI**: OpenAI Chat Completions API（ドキュメントが豊富で、gpt-4o-miniのような低コストモデルも選べる）
- **クラウド**: Firebase（Authentication・Firestore・Storage・Cloud Functions・Hosting）を一式で使い、自前サーバーを持たない
- **Web**: Vite + React + TypeScript + Firebase JS SDK
- **プロジェクト管理**: XcodeGen（`.xcodeproj`をGit管理せず、YAMLから毎回生成することでコンフリクトを避ける）

これらはいずれも「个人開発者が1人で全レイヤーを触れる」ことを重視した選定です。

---

## 第3章　開発環境を整える（第1週末：土曜午前）

### 3-1. 必要なツール

- Xcode（最新の安定版。iOS 17以降のシミュレータ/実機が必要）
- Homebrew（Macのパッケージマネージャ）
- XcodeGen（`brew install xcodegen`）
- Google Cloud Platformアカウント（Google Maps APIキー発行用）
- （後の週末で使用）Node.js、Firebase CLI、OpenAIアカウント

### 3-2. XcodeGenでプロジェクトを構成する理由

`.xcodeproj`ファイルはXMLベースのバイナリに近い構造を持ち、複数人（あるいは複数の作業セッション）で編集するとGitの差分が読みにくく、コンフリクトも起きやすいという弱点があります。XcodeGenを使うと、プロジェクト構成をシンプルなYAMLファイル（`project.yml`）で宣言し、コマンド一発で`.xcodeproj`を生成できます。

```yaml
name: Komap
options:
  bundleIdPrefix: com.example
targets:
  Komap:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources: [Komap]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.Komap
    dependencies:
      - package: GoogleMaps
```

`.xcodeproj`は`.gitignore`に加え、`project.yml`だけをGit管理する運用にします。これにより、複数のブランチで作業してもコンフリクトはYAMLレベルの軽微なものにとどまります。

```bash
xcodegen generate
open Komap.xcodeproj
```

この2行のコマンドを覚えておくだけで、プロジェクト構成を変更した後も常に最新の`.xcodeproj`を再生成できます。

### 3-3. Google Maps SDKの導入とAPIキー取得

1. [Google Cloud Console](https://console.cloud.google.com/) で新規プロジェクトを作成
2. 「Maps SDK for iOS」を有効化
3. 認証情報からAPIキーを発行
4. 本番運用時はAPIキーに「iOSアプリの制限（Bundle ID制限）」をかけて悪用を防ぐ

APIキーはソースコードに直接埋め込まず、`.xcconfig`ファイルなどビルド設定側で管理し、`.gitignore`に追加してリポジトリにコミットしないようにします。これはセキュリティ上非常に重要な習慣です。

```
// Config/Secrets.xcconfig（Gitにコミットしない）
GOOGLE_MAPS_API_KEY = AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

`Info.plist`側では、この値を`$(GOOGLE_MAPS_API_KEY)`のようにビルド変数として参照させ、コード上では`Bundle.main.object(forInfoDictionaryKey:)`などを通じて読み込みます。

XcodeGenを使う場合、Swift Package Manager経由でGoogle Maps SDKを依存関係に追加できます。

```yaml
packages:
  GoogleMaps:
    url: https://github.com/googlemaps/ios-maps-sdk
    exactVersion: 9.0.0
```

### 3-4. 最初の週末のゴール：現在地を表示する

`GMSMapView`をSwiftUIから使うには、`UIViewRepresentable`でラップします。

```swift
import GoogleMaps
import SwiftUI

struct GoogleMapRepresentable: UIViewRepresentable {
    @Binding var cameraPosition: CLLocationCoordinate2D

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: cameraPosition.latitude,
            longitude: cameraPosition.longitude,
            zoom: 16
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // 現在地の更新に応じてカメラを動かす処理をここに書く
    }
}
```

CoreLocationで現在地を取得する`LocationManager`クラスを作り、`CLLocationManagerDelegate`経由で位置情報の更新を受け取ります。プライバシー説明文（`NSLocationWhenInUseUsageDescription`）を`Info.plist`（またはXcodeGenの`project.yml`のinfo設定）に忘れず追加してください。これを忘れると、審査どころかシミュレータでも現在地取得が失敗します。

この時点で「アプリを起動すると現在地が地図上に青い点で表示される」状態になっていれば、第1週末のゴール達成です。

---

## 第4章　古地図・画像オーバーレイの実装（第2〜3週末）

### 4-1. GMSGroundOverlayの基本

Google Maps SDKには、指定した緯度経度の矩形範囲に画像を貼り付ける`GMSGroundOverlay`というクラスがあります。これが「古地図を現在の地図に重ねる」機能の核になります。

```swift
let southWest = CLLocationCoordinate2D(latitude: 35.685, longitude: 139.750)
let northEast = CLLocationCoordinate2D(latitude: 35.695, longitude: 139.765)
let bounds = GMSCoordinateBounds(coordinate: southWest, coordinate: northEast)

let overlay = GMSGroundOverlay(bounds: bounds, icon: UIImage(named: "old_map_edo"))
overlay.bearing = 0 // 画像が北を向いていない場合はここで回転角を指定
overlay.opacity = 0.7 // 透過度（0〜1）
overlay.map = mapView
```

ポイントは次の3つです。

- **`bounds`**：画像の南西端・北東端の緯度経度。ここが古地図の「位置合わせ」の核心部分です。
- **`bearing`**：画像が真北を向いていない場合の回転角。古地図のように傾いた向きで描かれている画像では必須の設定で、これを忘れると「絵柄と実際の地形がずれる」不具合の原因になります。
- **`opacity`**：透過度。スライダーのUIとバインドすることで「現在の地図⇔古地図」を自由に行き来できる体験を作ります。

### 4-2. 位置合わせ（ジオリファレンス）の考え方

古地図の位置合わせは、本格的にやるならGIS的な「ジオリファレンス」（地図上の複数の既知地点を基準に、画像の歪みを補正しながら座標を割り当てる作業）が必要ですが、個人開発の週末プロジェクトではそこまで厳密にやる必要はありません。

実務的な近似法は次の通りです。

1. 古地図の画像の中で、現代でも判別できるランドマーク（大きな交差点、寺社、川、皇居のお堀など）を2〜3点選ぶ
2. Google Mapで同じランドマークの緯度経度を調べる
3. 画像の四隅（あるいは南西端・北東端）が、その基準点から見てどの位置に来るかを目分量で算出する
4. 実機・シミュレータで表示して、ずれを見ながら微調整する

この「仮の値」で始めて、後から精度を上げていく進め方で十分です。実際、本書のベースにしたアプリでも「現在の地理に大まかに合わせた仮の座標」であることを明記した上でリリースしています。ユーザー体験としては、多少のズレよりも「古地図が見える」という体験の価値の方が大きいためです。

### 4-3. 古地図カタログの設計

古地図を1枚だけでなく複数扱うために、カタログ構造を用意します。

```swift
struct OldMapEntry: Identifiable {
    let id: String
    let title: String
    let era: String          // 例: "江戸時代（安政期）"
    let imageName: String
    let southWest: CLLocationCoordinate2D
    let northEast: CLLocationCoordinate2D
    let bearing: Double
}

enum OldMapCatalog {
    static let all: [OldMapEntry] = [
        OldMapEntry(
            id: "edo-castle",
            title: "江戸城周辺",
            era: "安政期",
            imageName: "old_map_edo",
            southWest: .init(latitude: 35.678, longitude: 139.745),
            northEast: .init(latitude: 35.696, longitude: 139.762),
            bearing: 0
        ),
        // ここに古地図を追加していく
    ]
}
```

古地図が10枚、20枚と増えてくると、SwiftUIの`Menu`のような単純なドロップダウンでは選択肢が画面に収まりきらず、スクロールもできないまま一部の選択肢が表示されなくなる、という問題が起こり得ます（実際に著者もこの問題に遭遇しました）。対策として、`.sheet` + `List`によるピッカー画面を用意すると、件数が増えても確実にスクロールで選択できます。

```swift
struct OldMapPickerSheet: View {
    let entries: [OldMapEntry]
    let onSelect: (OldMapEntry) -> Void

    var body: some View {
        List(entries) { entry in
            Button {
                onSelect(entry)
            } label: {
                VStack(alignment: .leading) {
                    Text(entry.title).font(.headline)
                    Text(entry.era).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

### 4-4. 「統合済みマップID」の考え方

コンテンツを育てていくと、「最初は別々に用意していた2つの古地図を、範囲を広げて1枚に統合したい」というリファクタリングが発生します。このとき、すでにユーザーの記録に古いID（廃止したマップID）が保存されている場合、そのIDを引き続き正しく解決できる仕組みが必要です。

```swift
extension OldMapCatalog {
    // 廃止されたIDを統合後のIDにマッピングする
    private static let mergedIdAliases: [String: String] = [
        "kudanshita-chidorigafuchi": "edo-castle",
        "kasumigaseki-toranomon": "edo-castle",
        "ueno-kaneiji": "hongo-yanaka-ueno",
    ]

    static func resolve(id: String) -> OldMapEntry? {
        let resolvedId = mergedIdAliases[id] ?? id
        return all.first { $0.id == resolvedId }
    }
}
```

こうしておけば、過去に保存された時空旅の記録・チェックポイントのデータをマイグレーションすることなく、表示ロジック側で「統合先」を常に正しく解決できます。データベースのマイグレーションは個人開発において地味に時間を奪う作業なので、可能な限り「表示側で吸収する」設計を検討する価値があります。

### 4-5. 画像サイズとテクスチャアトラスの制約に注意

Google Maps SDKの内部実装には、オーバーレイやマーカーのために使う「テクスチャアトラス」の容量上限があります。フル解像度（3000px超）の大きな画像を何枚も同時にロードして切り替えていくと、ある時点から古地図が真っ白になったり、一部しか描画されなくなったりする不具合が起きます。

対策は次の2点です。

1. **単体表示時は画像を縮小してから使う**：長辺1600px程度にダウンサンプリングしたキャッシュを作り、それをオーバーレイに使う。
2. **同時に読み込む実画像オーバーレイの枚数を制限する**：「全ての古地図を表示」のような一覧表示機能を作る場合、実画像を使うオーバーレイは同時に4枚程度までに制限し、それ以外は簡易表示（枠線や低解像度サムネイル）にとどめる。

```swift
func downsampledImage(named: String, maxDimension: CGFloat = 1600) -> UIImage? {
    guard let source = UIImage(named: named) else { return nil }
    let scale = min(1, maxDimension / max(source.size.width, source.size.height))
    guard scale < 1 else { return source }
    let newSize = CGSize(width: source.size.width * scale, height: source.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in source.draw(in: CGRect(origin: .zero, size: newSize)) }
}
```

このような「SDKの見えない制約」は公式ドキュメントに明記されていないことが多く、実際に手を動かして初めて発覚します。週末開発では、こうした落とし穴に遭遇したら、まず「同時に扱う量を減らす」という単純な対策から試すのが定石です。

---

## 第5章　位置情報記録とウォーキングゲーム化（第4〜5週末）

### 5-1. 徒歩ルートの記録

CoreLocationの`CLLocationManager`を使い、「スタート」ボタンが押されている間、位置情報の更新を蓄積していきます。

```swift
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var recordedPath: [CLLocationCoordinate2D] = []
    @Published var isRecording = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func startRecording() {
        recordedPath.removeAll()
        isRecording = true
        manager.startUpdatingLocation()
    }

    func stopRecording() {
        isRecording = false
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRecording, let location = locations.last else { return }
        recordedPath.append(location.coordinate)
    }
}
```

バックグラウンドでの位置情報取得を行う場合は、`Info.plist`に`NSLocationAlwaysAndWhenInUseUsageDescription`を追加し、Capabilitiesで「Background Modes」の「Location updates」を有効化する必要があります。バッテリー消費との兼ね合いもあるため、「アプリがアクティブな間だけ記録する」という制約でスタートし、後からニーズに応じて拡張するのが週末開発では現実的です。

### 5-2. 軌跡の見た目を整える：Chaikinのコーナーカット法

GPSの生データをそのまま線で結ぶと、信号のノイズでジグザグした見た目になります。これを滑らかにする簡易的な方法として、Chaikinのコーナーカット法（角を切り落として丸めるアルゴリズム）が使えます。

```swift
func chaikinSmooth(_ points: [CLLocationCoordinate2D], iterations: Int = 2) -> [CLLocationCoordinate2D] {
    var result = points
    for _ in 0..<iterations {
        guard result.count > 2 else { break }
        var smoothed: [CLLocationCoordinate2D] = [result[0]]
        for i in 0..<(result.count - 1) {
            let p0 = result[i]
            let p1 = result[i + 1]
            let q = CLLocationCoordinate2D(
                latitude: 0.75 * p0.latitude + 0.25 * p1.latitude,
                longitude: 0.75 * p0.longitude + 0.25 * p1.longitude
            )
            let r = CLLocationCoordinate2D(
                latitude: 0.25 * p0.latitude + 0.75 * p1.latitude,
                longitude: 0.25 * p0.longitude + 0.75 * p1.longitude
            )
            smoothed.append(q)
            smoothed.append(r)
        }
        smoothed.append(result.last!)
        result = smoothed
    }
    return result
}
```

このような「見た目の質」に効く小さな改善は、ユーザーが実際にスクリーンショットをSNSでシェアするかどうかに直結します。マーケティング効果を考えると、開発の早い段階で軌跡の見た目にひと手間かけておく価値は十分にあります。

### 5-3. 過去の軌跡と現在の軌跡を描き分ける

記録中の画面で「保存済みの過去の軌跡」を薄い色で背景に表示し、「今歩いている軌跡」を目立つ色で表示すると、ユーザーは自分の探索の進み具合を直感的に把握できます。ゲームでいう「マップの踏破率」の可視化に相当します。

```swift
let pastPathColor = UIColor.systemBlue.withAlphaComponent(0.25)
let currentPathColor = UIColor.systemBlue

let pastPolyline = GMSPolyline(path: pastPathGooglePath)
pastPolyline.strokeColor = pastPathColor
pastPolyline.strokeWidth = 3
pastPolyline.map = mapView

let currentPolyline = GMSPolyline(path: currentPathGooglePath)
currentPolyline.strokeColor = currentPathColor
currentPolyline.strokeWidth = 5
currentPolyline.map = mapView
```

### 5-4. 記録開始時に古地図を自動表示する

ユーザーが「スタート」を押した瞬間に古地図が未選択であれば自動的に表示し、透過度も一定以上に引き上げる、という細かい配慮も体験の質を大きく左右します。これは「わざわざ古地図を選ぶ」という手間を1ステップ減らすだけで、ユーザーが本来体験したい「古地図の上を歩いている感覚」により早くたどり着けるようにする施策です。

```swift
func startWalking() {
    if selectedOldMap == nil {
        selectedOldMap = OldMapCatalog.all.first
        overlayOpacity = max(overlayOpacity, 0.6)
    }
    locationManager.startRecording()
}
```

こうした「あと一歩の親切設計」は、レビューの星評価やリテンション（継続利用率）に直結するため、収益化パートでも改めて触れます。

---

## 第6章　ゲーミフィケーション設計：チェックポイントと御朱印（第5〜6週末）

### 6-1. 史跡チェックポイントの定義

古地図ごとに、実際の緯度経度を持った「チェックポイント」を定義します。

```swift
struct HistoricSite: Identifiable {
    let id: String
    let mapId: String       // 対応する古地図のID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let storyPrompt: String // AIに物語を生成させる際のヒント
}
```

### 6-2. 接近判定と「御朱印」の自動獲得

ユーザーがチェックポイントに一定距離（例：30メートル）以内に近づいたら、自動的に「御朱印」を獲得したことにします。

```swift
func checkProximity(currentLocation: CLLocationCoordinate2D, sites: [HistoricSite], radius: CLLocationDistance = 30) -> HistoricSite? {
    let current = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
    for site in sites {
        let target = CLLocation(latitude: site.coordinate.latitude, longitude: site.coordinate.longitude)
        if current.distance(from: target) <= radius {
            return site
        }
    }
    return nil
}
```

この判定を位置情報の更新のたびに走らせ、まだ獲得していないチェックポイントであれば、獲得演出（トースト通知、効果音、バイブレーション）を出してあげると、ゲームらしい達成感が生まれます。

### 6-3. ゲーミフィケーション要素の設計原則

心理学の「オペラント条件付け」や「可変報酬」の考え方をシンプルに応用すると、地図ゲームには次のような報酬設計が有効です。

- **即時報酬**：チェックポイントに近づいた瞬間に得られる御朱印（探索の直接的な報酬）
- **蓄積報酬**：御朱印のコレクション数、歩いた距離の累計、訪れた古地図の枚数（長期的なモチベーション）
- **創造的報酬**：AIが生成する、その場所固有の物語（毎回異なる体験になり、飽きにくい）
- **社会的報酬**：いいね・コメントなど、他者からの反応（本書後半で詳述）

これら4種類の報酬をバランス良く配置することで、「1回だけ試して終わり」ではなく「継続して使う」アプリになります。特に個人開発の場合、蓄積報酬（コレクション要素）は実装コストが低い割にリテンション効果が高いため、優先度を上げることをお勧めします。

### 6-4. 写真投稿によるプラスポイント

史跡以外の場所でも、ユーザーが自由なタイミングで写真を投稿できるようにすると、「決められたルート」以外の自由な探索行動も肯定できます。

```swift
struct WalkPhotoPost: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let imageData: Data
    let capturedAt: Date
    let isCheckpointPhoto: Bool // 史跡での御朱印用か、自由投稿か
}
```

`PhotosPicker`（PhotosUI）を使う場合、`Menu`の直下に`PhotosPicker`を直接置くと開かないことがある、というSwiftUI側の既知の制約があります。回避策として、`Button` + `.photosPicker(isPresented:)`モディファイアの組み合わせに変更すると安定して動作します。

```swift
Button("ライブラリから選ぶ") {
    isPhotoPickerPresented = true
}
.photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedItem)
```

このような「SwiftUIのフレームワーク特有の罠」は検索してもすぐには見つからないことが多いため、実際に手を動かして初めて得られる知見です。週末開発では、こうした詰まりに時間を溶かさないよう、「動かない場合はコンポーネントの組み合わせを変えてみる」という発想の転換を早めに試すことが重要です。

---

## 第7章　AIによるコンテンツ生成（第7週末）

### 7-1. なぜAI生成が地図ゲームと相性が良いのか

古地図や史跡の数だけ、手作業で解説文を用意するのは個人開発者にとって現実的ではありません。OpenAIのChat Completions APIのようなLLM（大規模言語モデル）を使えば、「その場所の緯度経度・地名・時代」といった情報をプロンプトに渡すだけで、その場に応じた物語やエピソードを動的に生成できます。

### 7-2. APIキーの安全な管理

APIキーをアプリのバイナリに埋め込むと、リバースエンジニアリングで抜き取られるリスクがあります。個人開発の初期段階では次のいずれかの方針を取ります。

- **ユーザー自身にAPIキーを入力してもらい、端末のKeychainに保存する**（開発初期・検証段階向け。コストをアプリ開発者が負担しない）
- **Cloud Functions等のサーバーサイド経由でAPIを呼び出し、キーはサーバー側だけに置く**（本格運用向け。ユーザー体験は良いが、開発者がAPI利用料を負担する）

```swift
import Security

enum KeychainStore {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
```

### 7-3. プロンプト設計の実例

```swift
func buildPrompt(for site: HistoricSite, era: String) -> String {
    """
    あなたは日本の郷土史に詳しい語り部です。
    以下の場所について、旅人が思わず読み込んでしまうような
    短い物語（200字程度）を生成してください。

    場所: \(site.name)
    時代背景: \(era)
    ヒント: \(site.storyPrompt)

    文体は柔らかく、断定しすぎない表現（〜と伝えられています、など）を使い、
    史実と創作の境界を意識してください。
    """
}
```

「史実と創作の境界を意識する」という一文を入れておくのは、コンテンツの信頼性に関わる重要なポイントです。AI生成コンテンツは説得力のある文章を作れる反面、事実と異なる内容を断定的に書いてしまうことがあります。アプリ内で「AIが生成した創作を含みます」という注意書きを添えることも、ユーザーへの誠実さとして推奨します。

### 7-4. コストとレイテンシの管理

- 低コストなモデル（例：`gpt-4o-mini`のような軽量モデル）を選び、1回あたりのトークン数を抑える
- 生成結果をローカル（SwiftData）にキャッシュし、同じ場所・同じユーザーに対して毎回課金しない
- 生成中はローディングインジケーターを表示し、体感速度を担保する

週末開発では「完璧な文章生成」よりも「体験として破綻しない範囲でコストを抑える」ことを優先しましょう。

---

## 第8章　データ永続化とクラウド同期（第6・8週末）

### 8-1. まずはローカル保存から

SwiftData（iOS 17以降の標準永続化フレームワーク）を使うと、Core Dataより少ないコードでモデルを永続化できます。

```swift
import SwiftData

@Model
final class WalkRoute {
    var id: UUID
    var startedAt: Date
    var mapId: String
    var coordinates: [CLLocationCoordinate2D]
    var stepCount: Int
    var notes: String?

    init(id: UUID = UUID(), startedAt: Date, mapId: String, coordinates: [CLLocationCoordinate2D], stepCount: Int) {
        self.id = id
        self.startedAt = startedAt
        self.mapId = mapId
        self.coordinates = coordinates
        self.stepCount = stepCount
    }
}
```

まずクラウド同期なしで「ローカルだけで完結するアプリ」として動く状態を作ることをお勧めします。クラウド連携は後から追加できますが、ローカルで完結する体験の設計を最初にしっかり固めておくと、後のFirebase連携作業がスムーズになります。

### 8-2. Firebaseの導入：認証・データベース・ストレージ

クラウド同期には、個人開発者にとって導入コストの低いFirebaseが定番です。

- **Firebase Authentication**：Googleサインインなど、OAuthベースの認証をほぼコード不要で実装可能
- **Cloud Firestore**：NoSQL型のリアルタイムデータベース。ユーザーごとのデータを`users/{uid}/walkRoutes`のような階層構造で管理
- **Firebase Storage**：写真や画像本体の保存に使用
- **Cloud Functions**：TestFlight招待メールの自動送信など、サーバーサイド処理が必要な場合に利用
- **Firebase Hosting**：Web版アプリの公開先

### 8-3. Firestoreのセキュリティルール設計

個人情報や位置情報を扱うアプリでは、セキュリティルールの設計が特に重要です。基本方針は「本人のデータは本人だけが読み書きでき、公開データ（シェアされた記録）は誰でも閲覧できるが書き込みは本人のみ」という形です。

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /sharedTrips/{tripId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == resource.data.ownerId;

      match /likes/{likeId} {
        allow read: if true;
        allow write: if request.auth != null;
      }
      match /comments/{commentId} {
        allow read: if true;
        allow create: if request.auth != null;
      }
    }
  }
}
```

セキュリティルールは「デフォルトで拒否、必要な範囲だけ許可する」という発想で書くことが鉄則です。個人開発だからといって手を抜くと、後から意図しないデータ漏洩や改ざんのリスクを抱えることになります。

### 8-4. 同期のタイミング設計

すべての操作を毎回リアルタイムでクラウドに送ると、通信量・API呼び出し回数（Firestoreは書き込み回数に応じて課金される）が増え、無料枠を超えるコストにつながります。実務的には次のような設計が有効です。

- ローカルの保存操作が完了した後、非同期でバックグラウンドアップロードする
- 徒歩ルートの記録中は逐次アップロードせず、「保存」ボタンが押されたタイミングでまとめて送信する
- 画像はアップロード前にリサイズ・圧縮してからFirebase Storageに送る

---

## 第9章　Apple Watch対応（第11週末）

### 9-1. Watch単体アプリという選択

Apple Watch向けの実装には、「iPhoneアプリのコンパニオン（付属）として動くWatchアプリ」と「Watch単体でも起動・記録できるアプリ」の2種類があります。ウォーキングゲームでは、iPhoneをポケットにしまったまま、Watchだけで記録を開始・終了できる体験の価値が高いため、単体アプリとしての実装をお勧めします。

`HKWorkoutSession`を使うことで、Watch単体でもGPSによる位置情報取得とワークアウト記録（Apple Healthへの「ウォーキング」ワークアウトとしての保存）が可能になります。

```swift
import HealthKit
import CoreLocation

final class WatchWorkoutLocationTracker: NSObject, HKWorkoutSessionDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?

    func startWorkout() {
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor

        session = try? HKWorkoutSession(healthStore: healthStore, configuration: config)
        session?.delegate = self
        session?.startActivity(with: Date())
    }
}
```

### 9-2. WatchConnectivityによるiPhoneとの連携

Watchで記録した軌跡・獲得した御朱印・投稿写真を、iPhone側にもリアルタイムで反映させるには、`WatchConnectivity`フレームワークの`WCSession`を使います。

```swift
import WatchConnectivity

final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    private let session = WCSession.default

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func sendSnapshot(_ payload: [String: Any]) {
        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
}
```

### 9-3. 「連動状態への追いつき」問題

Watch単体で記録を開始した後にiPhone側アプリを起動した場合、`sendMessage`によるリアルタイム通知だけに頼っていると、次の更新が届くまでiPhone側は「連動中」と認識できません。この問題への対策として、`WCSession`が有効化されたタイミングで、保存済みの`applicationContext`（直近の状態のスナップショット）を読み直す実装を入れておくと、アプリを開いた直後から正しい連動状態を表示できます。

```swift
func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if let context = session.receivedApplicationContext as? [String: Any] {
        applyContext(context)
    }
}
```

さらに、Watch側は記録終了時に`applicationContext`を空にしておくことで、「終了済みの記録がまだ続いているように見える」誤表示も防げます。また、古いスナップショット（例：5分以上前に更新されたもの）は無視するようにガードすることで、通信の遅延によって「記録中」という誤った状態が残り続ける不具合も回避できます。

このように、Watch連携は「ハッピーパスだけでなく、アプリの再起動やバックグラウンド遷移といった中断シナリオ」を丁寧に潰し込む作業が実装コストの大半を占めます。週末開発では、まず単純な連携（片方向の通知）を動かし、その後の週末で「復帰時の整合性」を1つずつ潰していくアプローチが現実的です。

### 9-4. 歩数の正確性を上げる：HealthKitとの統合

`CMPedometer`（Core Motion）だけで歩数を取る場合、iPhoneのセンサーのみに依存するため、Apple Watchを装着している場合の歩数と乖離することがあります。HealthKitの歩数データ（Watch・iPhone双方のセンサー値が統合されたもの）を読み取り専用で利用すると、より正確な歩数を記録に反映できます。

```swift
import HealthKit

final class HealthKitStepReader {
    private let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, _ in
            completion(success)
        }
    }

    func fetchStepCount(from start: Date, to end: Date, completion: @escaping (Int?) -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: .count())
            completion(steps.map { Int($0) })
        }
        healthStore.execute(query)
    }
}
```

HealthKitを使う場合、`NSHealthShareUsageDescription`（読み取りの説明文）に加え、実際には書き込みを行わない場合でも`NSHealthUpdateUsageDescription`をInfo.plistに追加しておく必要があります。これを怠ると、App Store Connectへのアップロード自体が「エラーコード90683」のようなメッセージで拒否されることがあります。HealthKitのエンティトルメントやAPIをリンクした時点で、Appleの静的検証が両方の説明文を要求するためです。審査前に必ずチェックしておきましょう。

---

## 第10章　Web版アプリへの展開（第10週末）

### 10-1. なぜWeb版を作るのか

iOSアプリだけで完結させず、同じFirebaseプロジェクトを参照するWebアプリを用意すると、次のメリットがあります。

- ユーザーが自分の記録をPCの大画面で見返せる
- 検索エンジンやSNSのリンクから、アプリをインストールしていない人にも「公開ページ」として体験の一部を見せられる（マーケティング上、非常に強力）
- App Storeの審査を経ずに素早く機能追加・修正ができる

### 10-2. Vite + React + Firebase JS SDKの構成

```bash
npm create vite@latest web -- --template react-ts
cd web
npm install firebase
```

```typescript
// web/src/lib/firebase.ts
import { initializeApp } from "firebase/app";
import { getAuth, GoogleAuthProvider } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();
export const db = getFirestore(app);
```

iOSアプリとWebアプリが同じFirebaseプロジェクトの同じUID（Googleサインインで一意になる）を使うことで、「iOSで記録した時空旅を、Webで即座に閲覧できる」という体験がシームレスに実現します。

### 10-3. 未サインインでも見られる「公開ページ」の設計

マーケティングの観点で特に重要なのが、サインインしていない訪問者でも一部のコンテンツ（例えば、ユーザーが「公開」設定にした時空旅の記録）を閲覧できるページです。

```typescript
// 公開設定のsharedTripsだけを取得し、サインインなしで表示する
const publicTripsQuery = query(
  collection(db, "sharedTrips"),
  where("isPublic", "==", true),
  orderBy("createdAt", "desc"),
  limit(20)
);
```

さらに、「現在このページを見ている人数」をリアルタイムに表示するような小さな仕掛けを入れると、訪問者に「動いているサービスである」という信頼感を与えられます。Firestoreの`onSnapshot`（リアルタイムリスナー）と、一定間隔でのハートビート（自分の存在をpresenceコレクションに書き込み続ける）を組み合わせれば実装できます。

```typescript
// 5秒ごとに自分のpresenceを更新し、30秒以上更新のないpresenceは
// Cloud Functionsの定期実行（もしくはクライアント側のフィルタ）で除外する
setInterval(() => {
  setDoc(doc(db, "presence", sessionId), { lastSeen: serverTimestamp() });
}, 5000);
```

このような「今まさに他の誰かが見ている・使っている」という演出は、後述するマーケティング戦略における「社会的証明（Social Proof）」の一種であり、実装コストの割に訪問者の滞在時間・信頼感に寄与します。

### 10-4. GitHub ActionsによるCI/CDの自動化

Web版の変更を毎回手動デプロイするのは週末開発では手間がかかりすぎます。GitHub Actionsを使い、`main`ブランチへのpushをトリガーにFirebase Hostingへ自動デプロイする仕組みを最初期に作っておくと、以後の開発速度が大きく変わります。

```yaml
# .github/workflows/deploy-web.yml
name: Deploy Web
on:
  push:
    branches: [main]
    paths:
      - "web/**"
      - "firebase.json"
      - "firebase/**"
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
        working-directory: web
      - run: npm run build
        working-directory: web
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: your-project-id
```

デプロイ用のサービスアカウントは、Hosting・Firestore/Storageルールのデプロイだけができる最小権限で発行することを強く推奨します。過剰な権限を持つキーがGitHub Secretsから漏洩した場合のリスクを最小化するためです。

---

## 第11章　ソーシャル機能とバイラリティの設計（第12週末）

### 11-1. いいね・コメント機能

WebとiOSの両方から同じ`sharedTrips/{tripId}/likes`・`/comments`サブコレクションを参照・更新することで、「アプリで付けたいいねがWebにも反映される」「Webで書いたコメントがアプリにも表示される」という双方向の連動を実現します。

```typescript
// web/src/lib/useTripLikes.ts（概念コード）
export function useTripLikes(tripId: string) {
  const [count, setCount] = useState(0);
  const [hasLiked, setHasLiked] = useState(false);

  useEffect(() => {
    const likesRef = collection(db, "sharedTrips", tripId, "likes");
    return onSnapshot(likesRef, (snapshot) => {
      setCount(snapshot.size);
      setHasLiked(snapshot.docs.some((d) => d.id === auth.currentUser?.uid));
    });
  }, [tripId]);

  const toggleLike = async () => {
    if (!auth.currentUser) {
      // 未サインインの場合はサインインへ誘導する
      return;
    }
    const likeDocRef = doc(db, "sharedTrips", tripId, "likes", auth.currentUser.uid);
    if (hasLiked) {
      await deleteDoc(likeDocRef);
    } else {
      await setDoc(likeDocRef, { createdAt: serverTimestamp() });
    }
  };

  return { count, hasLiked, toggleLike };
}
```

### 11-2. なぜソーシャル機能が収益化に直結するのか

いいね・コメントといった機能は、単なる「賑やかし」ではありません。次のような形でグロース（成長）に寄与します。

- **エンゲージメントの可視化**：他人の記録に反応が付いていると、自分も記録を残したい・公開したいという動機になる
- **UGC（ユーザー生成コンテンツ）の蓄積**：ユーザーが投稿した写真・物語・感想が、開発者が用意しなくてもコンテンツとして積み上がっていく
- **シェアの起点**：「いいねが付いた」という通知や実績が、SNSでのシェアのきっかけになる

### 11-3. 共有しやすい導線を作る

古地図を歩いた記録を、SNSにシェアしたくなるようなビジュアル（軌跡の描画、獲得した御朱印の一覧、AIが生成した物語の一節）としてまとめて出力できる「シェア画像生成」機能は、実装コストの割に広告効果が高い投資です。

```swift
func renderShareImage(route: WalkRoute, mapSnapshot: UIImage) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1080))
    return renderer.image { context in
        mapSnapshot.draw(in: CGRect(x: 0, y: 0, width: 1080, height: 1080))
        let text = "歩いた距離: \(route.distanceText) / 獲得した御朱印: \(route.stampCount)"
        text.draw(at: CGPoint(x: 40, y: 980), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 32), .foregroundColor: UIColor.white])
    }
}
```

このような機能は「開発者が広告費を払わなくても、ユーザーが勝手に広告塔になってくれる」仕組みそのものです。第II部のマーケティング編で、この考え方をさらに掘り下げます。

---

## 第12章　テスト・デバッグ・リリース準備（第13週末以降）

### 12-1. テストすべき優先順位

個人開発ですべての機能に自動テストを書く時間はありません。優先順位をつけるなら次の順番です。

1. **お金・データ消失に関わる箇所**（課金処理、クラウド同期の書き込みロジック）
2. **位置情報の座標変換・距離計算**（バグが起きても気づきにくく、コアゲームプレイに直結する）
3. **UIロジックの分岐が多い箇所**（サインイン状態・オフライン状態・空データの表示分岐）

```swift
import XCTest
@testable import Komap

final class ProximityTests: XCTestCase {
    func testWithinRadiusReturnsSite() {
        let site = HistoricSite(id: "1", mapId: "edo", name: "Test", coordinate: .init(latitude: 35.68, longitude: 139.75), storyPrompt: "")
        let nearby = CLLocationCoordinate2D(latitude: 35.6801, longitude: 139.7501)
        XCTAssertNotNil(checkProximity(currentLocation: nearby, sites: [site]))
    }
}
```

### 12-2. TestFlightによる実地テスト

シミュレータでは検出できない不具合（GPSの実際の揺れ、バックグラウンド遷移、Watchとの実機連携）を洗い出すには、TestFlightでの実地テストが欠かせません。友人・家族に「実際に外を歩いてみてもらう」ことで、机上では気づけない体験の粗さが見つかります。

また、Web版のGoogleサインインをきっかけに、TestFlightの外部テスター招待メールをCloud Functions経由で自動送信する仕組みを作っておくと、「Web公開ページを見た人が、そのままテスターとして誘導される」という導線を作れます。App Store Connect APIキー（Issuer ID・Key ID・秘密鍵）を発行し、Firebase Functionsのシークレットとして安全に保管します。

### 12-3. App Store申請時の注意点

App Store審査で個人開発者がつまずきやすいポイントをまとめます。

- **プライバシー説明文の不足**：位置情報、写真ライブラリ、HealthKitなど、使用する権限すべてに対応する`Usage Description`を`Info.plist`に用意する。読み取りのみの利用でも、HealthKitのように「Update（書き込み）」の説明文まで要求されるAPIがある点に注意（第9章参照）。
- **App Privacy（プライバシー「栄養成分表示」）の申告漏れ**：App Store Connect上で、収集するデータの種類（位置情報、写真、識別子など）を正確に申告する。
- **外部AIサービスの利用に関する説明**：AIが生成したコンテンツを含む場合、その旨をアプリ内・審査担当者向けのメモに明記しておくとスムーズ。
- **サインイン方法の代替手段**：Googleサインインのみを提供する場合、Sign in with Appleの必須要件に抵触しないか確認する（外部アカウントサービスでのサインインを提供する場合、Appleは原則Sign in with Appleの提供も求めるが、条件によって免除されるケースもあるため、最新のガイドラインを確認すること）。

### 12-4. リリースノートと初速の作り方

初回リリース時のバージョンノートは、機能の羅列ではなく「このアプリで何が体験できるか」を一文で伝えることを意識します。

> 「江戸の古地図を持って、今日の散歩をタイムトラベルに変えよう。」

このような一文は、後述するApp Storeのプロダクトページやスクリーンショットのキャッチコピーにも転用できます。

---

# 第II部　収益化・マーケティング編

## 第13章　地図ゲームアプリの収益化モデルを選ぶ

### 13-1. 収益化の4つの型

個人開発アプリの収益化モデルは、大きく4つに分類できます。

| モデル | 特徴 | 地図ゲームとの相性 |
|---|---|---|
| 買い切り課金 | 初回に一括で支払ってもらう | ダウンロード数が伸びにくい。ニッチな古地図テーマでは母数不足になりがち |
| アプリ内課金（消費型） | 追加の古地図パック、AI生成回数の追加購入など | 相性が良い。コンテンツを「地域パック」として売れる |
| サブスクリプション | 月額・年額で全古地図・無制限AI生成を提供 | 継続利用が前提のウォーキングゲームと非常に相性が良い |
| 広告 | バナー・インタースティシャル・リワード広告 | 単体では収益性が低いが、無料ユーザーの母数を活かす補完的手段として有効 |

### 13-2. おすすめの組み合わせ：フリーミアム＋地域パック課金

本書で推奨するのは、次のようなハイブリッドモデルです。

- **無料で使える範囲**：1〜2エリアの古地図、基本的な記録・チェックポイント機能
- **アプリ内課金（消費型・非消耗型）**：地域ごとの古地図パック（例：「本郷・谷中エリアパック」「東海道パック」）を1つずつ購入できるようにする
- **サブスクリプション（任意）**：全エリア古地図の解放＋AI生成物語を無制限に使えるプランを月額で提供
- **広告（任意・補完的）**：無料ユーザー向けに、チェックポイント到達時のリワード広告（視聴すると追加ポイント）を選択制で提供

このモデルの利点は、「無料で試して、気に入ったエリアだけ課金する」という体験が、地図ゲームというジャンルの性質（地域性・観光性）と自然に噛み合う点です。全国一律のサブスクリプションだけを提示するよりも、「自分の住んでいる街、旅行に行く街のパックだけ買う」という選択肢の方が、心理的なハードルが低くなります。

### 13-3. StoreKitでのアプリ内課金実装の要点

```swift
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []

    func loadProducts(ids: [String]) async {
        products = (try? await Product.products(for: ids)) ?? []
    }

    func purchase(_ product: Product) async {
        guard let result = try? await product.purchase() else { return }
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
            }
        default:
            break
        }
    }
}
```

課金対象のプロダクトIDは、App Store Connect側で「地域パック」ごとに設定し、購入済みIDのセットに応じて`OldMapCatalog`のロック状態を制御します。

### 13-4. 「無料枠」の設計は慎重に

無料枠を広げすぎると課金の動機がなくなり、狭めすぎると初回の体験価値が伝わらずアンインストールされます。目安として、「無料ユーザーが最初のセッションで“これは面白い”と感じられるだけの古地図・チェックポイント数（3〜5箇所程度）」を無料開放し、それ以上の物量を課金対象にする設計から始め、実際の利用データ（後述の分析）を見ながら調整するのが現実的です。

---

## 第14章　ASO（App Store最適化）の基本

### 14-1. アプリ名・サブタイトルの設計

App Storeでの検索流入は、広告費をかけない個人開発者にとって最も重要な集客チャネルです。アプリ名とサブタイトルには、検索されるであろうキーワードを自然な形で含めます。

- アプリ名：ブランド名＋差別化ワード（例：「Komap - 古地図で街歩き」）
- サブタイトル：機能や体験を端的に（例：「古地図×GPSウォーキング記録」）

「地図」「散歩」「ウォーキング」「観光」「歴史」「御朱印」「聖地巡礼」など、実際にユーザーが検索しそうな語彙を洗い出し、App Store Connectの「キーワード」欄（100バイトまで）に、アプリ名・サブタイトルと重複しない形で詰め込みます。

### 14-2. スクリーンショットは「体験」を見せる

スクリーンショットは機能一覧ではなく、「使うとどんな気持ちになるか」を1枚ごとに伝えるべきです。

1. 1枚目：一番魅力的な体験の瞬間（古地図が重なった地図のビジュアル）＋キャッチコピー
2. 2枚目：チェックポイントに近づいて御朱印を獲得する瞬間
3. 3枚目：AIが生成した物語を読んでいる画面
4. 4枚目：歩いた軌跡が地図上に描かれた達成感のある画面
5. 5枚目：Web版やApple Watch連携など、エコシステムの広さを示す画面

### 14-3. アプリプレビュー動画

15〜30秒のプレビュー動画は、テキストや静止画よりコンバージョン率を高める傾向があります。実際に外を歩いて記録している様子、透過度スライダーを操作して古地図が浮かび上がる瞬間など、「動きがあるからこそ伝わる」体験を優先的に収録します。

### 14-4. レビューと評価への向き合い方

- アプリ内の適切なタイミング（記録を保存し終えた直後、御朱印を複数獲得した直後など、ポジティブな体験の直後）で`SKStoreReviewController`によるレビュー依頼を表示する
- ネガティブなレビューには、可能な範囲で開発者からの返信を行い、改善につなげている姿勢を見せる（新規ユーザーはレビューへの返信も判断材料にする）

---

## 第15章　低予算マーケティング戦略

### 15-1. 個人開発者が使える広報チャネル

大きな広告予算を持たない個人開発者でも、次のようなチャネルは無料または低コストで活用できます。

- **SNS（X／Instagram／TikTok）**：実際に古地図を持って街を歩く様子を動画で発信する。「Before/After」（現在の風景⇔古地図の重ね合わせ）は視覚的にバズりやすいフォーマット
- **note・ブログでの開発記録公開**：「個人開発でここまで作った」というプロセス自体がコンテンツになる（本書のような開発記もその一例）
- **地域メディア・観光協会への持ち込み**：古地図・郷土史というテーマは、地方紙やローカルテレビ、観光協会のSNSと相性が良く、取材してもらえる可能性がある
- **Product Hunt／個人開発者コミュニティでの公開**：エンジニア・アーリーアダプター層への露出に有効
- **プレスリリース配信サービス**：無料〜低価格のプレスリリース配信サービスを使い、「◯◯市の古地図アプリ」のような地域性のあるニュースとして配信する

### 15-2. 「Before/After」コンテンツの作り方

古地図オーバーレイの透過度を0%（現在の地図）から100%（古地図のみ）へスライドさせる様子を録画するだけで、視覚的にインパクトのあるショート動画が作れます。これはアプリの核となる機能そのものを、追加の演出なしでマーケティングコンテンツに変換できる、非常にコストパフォーマンスの高い手法です。

```swift
// スクリーン録画用に、透過度アニメーションを自動再生するデバッグモードを用意しておくと
// プロモーション動画の撮影が格段に楽になる
func playOverlayDemo() {
    withAnimation(.easeInOut(duration: 3)) {
        overlayOpacity = overlayOpacity > 0.5 ? 0.0 : 1.0
    }
}
```

### 15-3. コミュニティ・ローカルパートナーシップ

- 地域の史跡ガイドボランティア団体、郷土資料館、観光案内所などに、アプリの存在を伝える（無料掲載や協力を打診できる可能性がある）
- 学校の郷土学習・総合学習の教材としての活用を提案する（教育目的の利用は、収益に直結しなくても口コミの起点になる）
- ウォーキングイベント、スタンプラリーイベントの主催者に、アプリを「デジタルスタンプラリー」として提供する提案をする

### 15-4. ローンチ時の「初速」を作る施策

App Storeのランキングアルゴリズムは、短期間でのダウンロード数・エンゲージメントの伸びを重視する傾向があります。個人開発者でも次のような工夫で初速を作れます。

- リリース日を事前に告知し、SNSのフォロワーに「リリース当日にダウンロード」を呼びかける
- ローンチ記念として、期間限定で全古地図パックを無料開放する
- TestFlightで先行体験したテスターに、正式リリース日にレビュー投稿を依頼する（自然な形での複数レビューの獲得）

---

## 第16章　グロースサイクルと継続的改善

### 16-1. 計測すべき指標

収益化・マーケティングを継続的に改善するには、次の指標を最低限追う体制を作ります。

- **DAU/MAU（デイリー／マンスリーアクティブユーザー）**：継続利用の指標
- **リテンション率（1日後・7日後・30日後）**：初回体験の質、ゲーミフィケーションの効果を測る
- **課金率（無料ユーザーのうち課金に至った割合）とARPU（ユーザーあたり平均収益）**
- **チェックポイント到達率、古地図ごとの利用比率**：どのコンテンツが人気か把握し、次に作る古地図の優先順位付けに使う

Firebase Analyticsを導入すれば、これらの指標の多くを追加の開発コストをほとんどかけずに計測できます。

```swift
import FirebaseAnalytics

Analytics.logEvent("checkpoint_reached", parameters: [
    "map_id": site.mapId,
    "site_id": site.id,
])
```

### 16-2. リテンションを上げる小さな改善の積み重ね

本書のロードマップで紹介した「マイ時空旅の一覧」「直近3件だけ表示して折りたたむ」「日付表記をM/D形式に短縮する」といった細かなUI改善は、単体では地味に見えますが、日々の利用体験の摩擦を減らし、結果的にリテンションに寄与します。個人開発では大きな新機能よりも、こうした小さな改善のサイクルを高速に回せることが強みになります。

### 16-3. コンテンツの継続的な追加

地図ゲームアプリのコンテンツ（古地図・史跡チェックポイント）は、一度作って終わりではなく、継続的に追加していくことでユーザーの「まだ知らない場所がある」という好奇心を維持できます。

- 季節ごとのイベント（花見シーズンに合わせた古地図の追加、夏祭りにちなんだ史跡の追加）
- ユーザーからのリクエストを募る仕組み（「次にどのエリアの古地図が欲しいですか？」というアンケート機能）
- ユーザー自身が史跡候補を投稿できる仕組み（UGC化によるコンテンツのスケール）

### 16-4. 価格・プラン改定のテスト

App Store Connectの価格帯変更や、サブスクリプションのイントロ価格（初回割引）機能を使い、小規模なA/Bテストに近い形で価格施策を試すことができます。個人開発では厳密なA/Bテスト基盤を持つことは難しいため、「一定期間ごとに価格・訴求文言を変えて、コンバージョン率の変化を観察する」という簡易的なPDCAで十分です。

---

## 第17章　ケーススタディ：週末開発から一つのアプリができるまで

本章では、これまでの章で紹介した技術・考え方を、実際に1つのアプリとして組み立てていった記録を時系列でたどります（本書執筆にあたって参照した、実在のプロジェクトの開発履歴に基づく再構成です）。

### 17-1. 最小限のプロトタイプ期

最初の数週末は、Google Maps SDKの導入、現在地表示、1枚の古地図オーバーレイの表示に費やされました。この段階ではUIも粗く、古地図の位置合わせも大まかな仮の値でしたが、「古地図が現在の地図に重なって見える」という核となる体験は、この時点ですでに成立していました。

### 17-2. コア体験の拡張期

古地図のカタログ化、チェックポイントと御朱印の仕組み、GPSによる徒歩ルートの記録・保存が実装され、「歩く」という行為そのものがゲームになっていきました。この段階で、テクスチャアトラスの制約や、SwiftUIの`Menu`の表示件数問題など、SDK・フレームワーク特有の制約に何度も遭遇し、その都度「表示件数の制限」「画像の事前縮小」「UIコンポーネントの構成変更」といった実務的な回避策で対処していきました。

### 17-3. AIとクラウドによる体験の深化期

OpenAI APIによる物語生成、Firebaseによるクラウド同期、Firebase Storageを使った写真投稿機能が加わり、単なる記録アプリから「その場所の物語に出会えるアプリ」へと体験が深まりました。この段階でセキュリティルールの設計、APIキーの安全な管理など、個人開発者が見落としがちなセキュリティ面の作業が発生しています。

### 17-4. エコシステム拡張期

Apple Watch単体アプリ、Webアプリ版が追加され、「iPhoneがなくても記録できる」「ブラウザからも記録を見返せる」という形でエコシステムが広がりました。この段階で、Watch単体記録の連動状態の整合性、Web版での自分の記録の編集機能、いいね・コメントといったソーシャル機能が実装され、単一デバイスのアプリから「複数の接点を持つサービス」へと進化しています。

### 17-5. 継続的な磨き込み期

リリース後も、「マイ時空旅の一覧の折りたたみ表示」「日付表記の短縮」「プレビュー地図の軽量化」「回転が必要な古地図の向きのずれ修正」といった細かな改善が継続的に行われています。これらは派手な新機能ではありませんが、実際に使ってみて初めて気づく体験の粗さを一つずつ潰していく作業であり、個人開発における「磨き込み」の重要性を象徴しています。

### 17-6. このケーススタディから学べること

- 完璧な設計を最初から目指さず、「仮の値」「大まかな実装」で動くものを先に作る
- SDK・フレームワークの制約は、ドキュメントよりも実際に手を動かして発見することが多い。遭遇したら記録し、再発防止の仕組み（縮小処理の共通化、UIコンポーネントの置き換えなど）に落とし込む
- 機能追加の合間に、細かなUI改善・不具合修正を挟み込むことで、リリース後も「育て続けているアプリ」であることをユーザーに伝えられる

---

## 第18章　法務・プライバシー・倫理面の留意点

### 18-1. 位置情報の取り扱い

位置情報は個人を特定しうるセンシティブなデータです。次の点に留意してください。

- プライバシーポリシーに、収集する位置情報の種類・利用目的・第三者提供の有無を明記する
- 必要最小限の精度・頻度でのみ位置情報を取得する（常時バックグラウンドで高精度取得を行う必要が本当にあるか、都度見直す）
- クラウドに保存する位置情報（軌跡データ）は、本人以外がアクセスできない設計を徹底する（第8章のセキュリティルール参照）

### 18-2. 著作権・史料の扱い

古地図や歴史資料を使う場合、著作権の状況を必ず確認してください。

- パブリックドメインとなっている歴史地図（発行から一定年数が経過し著作権が消滅しているもの）は、出典を明記した上で利用可能な場合が多いですが、配布元・アーカイブのライセンス条件も別途確認する必要があります
- 現在の地図画像（Google Maps、OpenStreetMapなど）を加工して「古地図風」に仕立てる場合も、各サービスの利用規約・ライセンス（例：OpenStreetMapのODbLライセンスでは帰属表示が必要）を遵守してください
- 実在の史跡・地名を扱う場合、地域住民や関係団体への配慮（誤った歴史情報を断定的に発信しない、宗教施設への配慮など）も忘れずに

### 18-3. AI生成コンテンツの取り扱い

AIが生成する物語やエピソードには、事実と異なる内容が含まれる可能性があります。アプリ内に「AIによる生成コンテンツを含みます。史実と異なる場合があります」といった注意書きを設けることは、ユーザーへの誠実さであると同時に、後のトラブル回避にもつながります。

### 18-4. 未成年ユーザーへの配慮

位置情報や写真投稿機能を含むアプリは、未成年ユーザーが利用する可能性も考慮する必要があります。App Storeの年齢区分設定を適切に行い、必要に応じて保護者の同意フローや、投稿内容のモデレーション（不適切な投稿の通報・削除機能）を検討してください。

---

## 第19章　よくある質問（FAQ）

**Q. プログラミング未経験でも本書の内容を実践できますか？**

A. Swift・SwiftUIの基礎的な文法（変数、関数、クラス、SwiftUIのView構文）を理解していることを前提としています。未経験の場合は、まずSwiftUIの入門教材で基礎を固めてから本書に取り組むことをお勧めします。一方、Web版やマーケティング編は、非エンジニアの方が「外注する際に何を発注すればよいか」を理解する目的で読むこともできます。

**Q. Google Maps SDKは無料で使えますか？**

A. Google Maps Platformには無料利用枠があります（利用状況やタイミングによって条件は変わるため、必ずGoogle Cloud Platformの最新の料金ページを確認してください）。個人開発の検証段階であれば無料枠内に収まることが多いですが、リリース後にユーザー数が増えた場合の請求額の上限設定（予算アラート）を必ず行っておきましょう。

**Q. Firebaseの無料枠だけで運用できますか？**

A. Firestoreの読み書き回数、Cloud Functionsの実行回数、Storageの容量にはいずれも無料枠（Sparkプラン）がありますが、Cloud Functionsを使った外部API呼び出し（メール送信など）にはBlazeプラン（従量課金）への切り替えが必要です。ユーザー数が少ない初期段階では無料枠内に収まることが多いですが、予算アラートの設定は必須です。

**Q. 古地図の著作権が心配です。オリジナル画像で代替できますか？**

A. 可能です。本書で紹介した「現在の地図をセピア調に加工して古地図"風"に仕立てる」手法や、AI画像生成サービスでイラスト風の地図を作る手法であれば、著作権の懸念を大きく減らせます。ただし、加工元となる地図タイル画像自体の利用規約（帰属表示の要否など）は確認してください。

**Q. 収益化まで、実際どれくらいの期間がかかりますか？**

A. 開発ボリューム・マーケティング施策の実行度合いによって大きく異なりますが、本書のロードマップに沿って週末だけで進めた場合、最小限の機能でのリリースまでに3〜4ヶ月、収益化モデルの導入とマーケティング施策の実行を経て初めての売上が立つまでにはさらに数ヶ月を見込むのが現実的です。焦らず、まずは「自分が使いたいと思えるアプリ」を作り切ることを優先してください。

---

## 付録A　用語集

- **GMSGroundOverlay**：Google Maps SDKで、指定した緯度経度範囲に画像を貼り付けるためのクラス
- **ジオリファレンス**：地図画像に対して、実世界の座標（緯度経度）を対応付ける作業
- **テクスチャアトラス**：GPU上で複数の画像をまとめて扱うための領域。上限を超えると描画不具合が起きる
- **Chaikinのコーナーカット法**：折れ線の角を滑らかにするアルゴリズム
- **SwiftData**：iOS 17以降の標準永続化フレームワーク
- **Firestore**：Firebaseが提供するNoSQL型のリアルタイムデータベース
- **WCSession**：iPhoneとApple Watch間の通信を担うWatchConnectivityフレームワークの中核クラス
- **HKWorkoutSession**：HealthKitでワークアウト（運動）セッションを管理するクラス
- **ASO（App Store Optimization）**：App Store内検索での見つけやすさを高めるための最適化施策
- **UGC（User Generated Content）**：ユーザーが生成するコンテンツ（投稿写真、コメントなど）
- **社会的証明（Social Proof）**：他者の行動・評価が、自分の意思決定に影響を与える心理効果

## 付録B　開発チェックリスト

**設計・企画**
- [ ] 誰が、どんな場面で使うアプリかを一文で説明できる
- [ ] 地図に重ねるレイヤーの種類（古地図／オリジナルマップ等）を決めた
- [ ] 収集要素（御朱印／バッジ等）の設計を決めた

**技術基盤**
- [ ] XcodeGenで`project.yml`を管理し、`.xcodeproj`は`.gitignore`済み
- [ ] Google Maps APIキーを`.xcconfig`で管理し、Bundle ID制限をかけた
- [ ] 位置情報のUsage Descriptionをすべて用意した
- [ ] HealthKitを使う場合、Update用の説明文も用意した

**セキュリティ**
- [ ] Firestoreセキュリティルールで「本人のみ書き込み可」を徹底した
- [ ] APIキー・サービスアカウントの秘密鍵をGitにコミットしていない
- [ ] 画像アップロード前にリサイズ・圧縮している

**リリース前**
- [ ] TestFlightで実地テストを行った
- [ ] App Privacyの申告内容が実際の実装と一致している
- [ ] プライバシーポリシーを公開URLとして用意した
- [ ] スクリーンショット・プレビュー動画で「体験」を伝えられている

**マーケティング**
- [ ] SNSでBefore/Afterコンテンツを準備した
- [ ] リリース日を告知し、初速を作る施策を用意した
- [ ] Firebase Analyticsで主要指標を計測できる状態にした

## 付録C　参考リソース

- Google Maps Platform 公式ドキュメント（Maps SDK for iOS）
- Apple Developer Documentation（CoreLocation、HealthKit、WatchConnectivity、SwiftData、StoreKit）
- Firebase公式ドキュメント（Authentication、Firestore、Storage、Cloud Functions、Hosting）
- OpenAI Platform ドキュメント（Chat Completions API）
- XcodeGen公式リポジトリ（GitHub: yonaskolb/XcodeGen）
- Wikimedia Commons（パブリックドメインの歴史地図史料）
- OpenStreetMap（地図タイルデータ、ODbLライセンス）

---

## おわりに

地図ゲームアプリという企画は、技術的な難易度と、得られる体験の豊かさのバランスが非常に優れたジャンルです。Google Maps SDKという成熟した基盤の上に、古地図という文化的なコンテンツを重ね、GPSによる「歩く」という現実の行動をゲーム化する——このアイデアは、週末という限られた時間の中でも、着実に前進させることができます。

本書で紹介した技術も、マーケティング手法も、完璧である必要はありません。「仮の値」で始めた位置合わせが、後から少しずつ精度を上げていけるように、収益化モデルもマーケティング施策も、リリース後に少しずつ磨いていくものです。

大切なのは、最初の週末に「動くもの」を1つ作ること。そして、その小さな一歩を、次の週末、また次の週末へとつなげていくことです。

あなたの街の、あなたが選んだ古地図（あるいはオリジナルのマップ）が、誰かの週末の散歩を、小さな時空旅に変える日を楽しみにしています。

---

*本書に掲載したコードはすべて解説目的の簡略化されたサンプルです。実際のプロダクションコードでは、エラーハンドリング、パフォーマンス最適化、最新のSDK仕様への追従など、追加の実装が必要になる点にご留意ください。また、各種APIの料金体系・利用規約は変更される可能性があるため、実装前に必ず公式ドキュメントの最新情報をご確認ください。*
