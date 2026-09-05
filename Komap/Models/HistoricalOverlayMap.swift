import CoreLocation
import Foundation
import UIKit

/// 古地図1枚分の情報（画像・時代・位置合わせ範囲）を表す。
///
/// - Important: `southWest` / `northEast` はこのサンプルアプリ用に用意した
///   仮の位置合わせ座標です。実際の古地図画像を使う場合は、当時の絵図を
///   現代の緯度経度に正確に対応させた座標に置き換えてください。
struct HistoricalOverlayMap: Identifiable, Hashable {
    let id: String
    /// 一覧・ピッカーに表示する名称（例: 「江戸城 安政期」）
    let title: String
    /// AIへの物語生成プロンプトに渡す時代表現（例: 「江戸時代後期（1850年代・安政期）」）
    let era: String
    /// 短い紹介文（ピッカーやカード表示用）
    let summary: String
    /// Assets.xcassets 内の画像名。同梱の古地図で使う。
    ///
    /// - Important: 画像は必ず1024×1024pxの正方形にしておくこと（縦横比が違う元画像は
    ///   白背景でレターボックス/ピラーボックスして正方形にする）。1024×1024以外のサイズ
    ///   （1536×1536のような正方形でも、1200×895のような長方形でも）だと、Google Maps SDKの
    ///   `GMSGroundOverlay`がこの環境では画像を一切描画しない（チェックポイントや base map は
    ///   正常なのに、古地図の帯だけ完全に透明になる）不具合を確認している。原因はSDK内部の
    ///   テクスチャ処理側にあると見られ、アプリ側のコードでは検出できない（エラーもログも出ない）。
    let imageAssetName: String?
    /// `StampPhotoStore`に保存したファイル名。検索して追加した古地図で使う。
    let imageFileName: String?
    /// 画像の左下（南西）に対応する緯度経度。`bearing`が0でない場合、実際に画像が
    /// 覆う範囲はこの矩形を`bearing`の分だけ中心を軸に回転させたものになる
    /// （`GMSGroundOverlay.bearing`と同じ仕様）。
    let southWest: CLLocationCoordinate2D
    /// 画像の右上（北東）に対応する緯度経度
    let northEast: CLLocationCoordinate2D
    /// 画像の「上」が指す方角（真北から時計回りの度数）。0なら回転なし（画像の上＝北）。
    /// 手描きの古地図は必ずしも北を上にして描かれていないため、実際の地理と重ねる際に
    /// 画像そのものを回転させたい場合に使う。
    let bearing: CLLocationDirection

    init(
        id: String,
        title: String,
        era: String,
        summary: String,
        imageAssetName: String? = nil,
        imageFileName: String? = nil,
        southWest: CLLocationCoordinate2D,
        northEast: CLLocationCoordinate2D,
        bearing: CLLocationDirection = 0
    ) {
        self.id = id
        self.title = title
        self.era = era
        self.summary = summary
        self.imageAssetName = imageAssetName
        self.imageFileName = imageFileName
        self.southWest = southWest
        self.northEast = northEast
        self.bearing = bearing
    }

    /// この古地図がカバーする範囲の中心（初期表示時のカメラ位置に使う）
    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (southWest.latitude + northEast.latitude) / 2,
            longitude: (southWest.longitude + northEast.longitude) / 2
        )
    }

    /// 地図上部のラベルなど、短い表示が必要な場所で使う名称。
    /// 「東海道（日本橋・芝増上寺・品川）」のような、括弧で補足を添えた`title`から
    /// 括弧部分を取り除いたもの（括弧が無ければ`title`のまま）。
    var shortTitle: String {
        guard let openRange = title.range(of: "（") else { return title }
        return String(title[title.startIndex..<openRange.lowerBound])
    }

    /// 同梱アセット・検索で追加した画像のどちらかから、表示用の画像を読み込む。
    var image: UIImage? {
        if let imageAssetName, let image = UIImage(named: imageAssetName) {
            return image
        }
        if let imageFileName {
            return StampPhotoStore.load(imageFileName)
        }
        return nil
    }

    static func == (lhs: HistoricalOverlayMap, rhs: HistoricalOverlayMap) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// アプリに同梱している古地図のカタログ。
///
/// ユーザーは後からここに新しい古地図（画像 + 位置合わせ座標）を
/// 追加するだけで、選択肢を増やすことができる。
enum OldMapCatalog {
    static let edoCastle = HistoricalOverlayMap(
        id: "edo-castle-1850s",
        title: "江戸城周辺（安政期）",
        era: "江戸時代後期（1850年代・安政期）",
        summary: "江戸城の内堀・外堀と大名屋敷が広がっていたエリア。現在の皇居・大手町・丸の内に加え、九段下・千鳥ヶ淵（靖国神社周辺）、霞ヶ関・虎ノ門一帯も含みます。",
        imageAssetName: "OldMap_EdoCastle",
        // 元々は皇居周辺のみの範囲だったが、九段下・千鳥ヶ淵（`kudanshitaChidorigafuchi`）と
        // 霞ヶ関・虎ノ門（`kasumigasekiToranomon`）を統合したため、南側を少し広げている
        // （イラスト画像自体はそのままのため、南端付近はやや引き伸ばされた表示になる）。
        southWest: CLLocationCoordinate2D(latitude: 35.6653, longitude: 139.740),
        northEast: CLLocationCoordinate2D(latitude: 35.696, longitude: 139.767)
    )

    static let asakusa = HistoricalOverlayMap(
        id: "asakusa-edo",
        title: "浅草・浅草寺周辺（江戸時代）",
        era: "江戸時代（浅草寺門前町が賑わった時期）",
        summary: "浅草寺の門前町として庶民の娯楽街が広がっていたエリア。現在の浅草・雷門・仲見世通り周辺に相当します。",
        imageAssetName: "OldMap_Asakusa",
        southWest: CLLocationCoordinate2D(latitude: 35.708, longitude: 139.788),
        northEast: CLLocationCoordinate2D(latitude: 35.723, longitude: 139.806)
    )

    // 以下2枚（+ 東海道`tokaido`が使う`OldMap_Shiba`）は「東京實測全圖」
    // （1891年・明治24年、Geographicus発行）の実画像をエリアごとに切り出したもの。
    // 1931年より前に発行されたためパブリックドメイン（出典: Wikimedia Commons）。
    // 位置合わせは地図上の目印（不忍池・皇居のお堀等）を基準に手作業で行った概算で、
    // 史料的に厳密な測量座標ではない。かつて別々の古地図だった「神田」「上野」「芝」は、
    // それぞれ日本橋・本郷・東海道の古地図に統合済み（統合の経緯は各エントリのコメント参照）。

    static let meijiWriters = HistoricalOverlayMap(
        id: "meiji-writers",
        title: "明治の文豪（本郷・上野）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "夏目漱石・森鴎外・樋口一葉など、明治の文豪たちが暮らした本郷・千駄木・谷中と、寛永寺・不忍池を中心とした上野周辺をあわせたエリアです。帝国大学（現・東京大学）も見えます。",
        imageAssetName: "OldMap_MeijiWriters",
        // 谷中七福神のうち田端・西日暮里側の3社寺、および上野（寛永寺・不忍池周辺、
        // 旧`ueno`エントリ）のチェックポイントも収まるよう、範囲を広げている
        // （元画像自体の解像度はそのままのため、特に東端・北端付近はやや引き伸ばされた表示になる）。
        southWest: CLLocationCoordinate2D(latitude: 35.6929, longitude: 139.7484),
        northEast: CLLocationCoordinate2D(latitude: 35.7395, longitude: 139.7984)
    )

    static let nihonbashi = HistoricalOverlayMap(
        id: "nihonbashi-edo",
        title: "日本橋・神田明神",
        era: "明治時代（1891年・明治24年頃）",
        summary: "五街道の起点・日本橋を中心に、商人たちの店が軒を連ねた経済の中心地。北の神田明神門前町までを含みます。",
        imageAssetName: "OldMap_Nihonbashi",
        // もともと別の古地図だった「神田（神田明神周辺）」を統合したため、北側に範囲を
        // 広げている（画像自体はそのままのため、北端付近はやや引き伸ばされた表示になる）。
        southWest: CLLocationCoordinate2D(latitude: 35.6638, longitude: 139.7505),
        northEast: CLLocationCoordinate2D(latitude: 35.7166, longitude: 139.7929)
    )

    // 以下1枚は「1891 Meiji Map of Tokyo or Edo, Japan」（Geographicus発行、東京實測全圖の英語版）
    // の実画像を、地域を絞らず広域のまま使ったもの。1931年より前に発行されたためパブリックドメイン
    // （出典: Wikimedia Commons）。目黒・世田谷・豊島など東京十五区の外側にあたるエリアも含むため、
    // 他の実測図に比べて図の密度は粗く、位置合わせもより概算になる。

    // 皇居のお堀（中心）と不忍池・帝国大学（本郷、北東）の実際の緯度経度と、
    // 画像上のピクセル位置を照合して、回転（bearing）・縮尺・中心位置を計算した。
    // 元画像は北が上ではなく、真北から時計回り約325°（＝反時計回りに約35°）の方向を
    // 上にして描かれている（実測図でも、紙面に収めるために東京の海岸線の向きに合わせて
    // 回転して印刷されたとみられる）。それでも手描きの古地図のため、細部までの
    // 完全な精度は無い（皇居・不忍池・本郷を基準にした概算）。
    static let goshikiFudo = HistoricalOverlayMap(
        id: "goshiki-fudo-meiji",
        title: "五色不動めぐり（目黒・目白・目赤・目青・目黄）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "江戸の町を鬼門から守るとされた五色不動を東西南北にめぐる、広域の古地図です。目黒区・豊島区・文京区・世田谷区・台東区にまたがります。",
        imageAssetName: "OldMap_TokyoMeiji1891",
        southWest: CLLocationCoordinate2D(latitude: 35.63735, longitude: 139.71808),
        northEast: CLLocationCoordinate2D(latitude: 35.72185, longitude: 139.82213),
        bearing: 325.0
    )

    // 以下1枚（松尾芭蕉ゆかりの地）は、上記と同じ「1891 Meiji Map of Tokyo
    // or Edo, Japan」（Geographicus発行、Wikimedia Commonsより取得、パブリックドメイン）の
    // フル解像度画像（3500×2610px）から、ルートに合わせてエリアを切り出したもの
    // （切り出し済みの別画像のため、上記`goshikiFudo`のbearingの影響は受けない）。
    // 位置合わせは、切り出し前の画像に対して地図上の目印を基準に手作業で行った概算で、
    // 史料的に厳密な測量座標ではない。
    // （東海道はかつて同じグループの専用画像を使っていたが、現在は`shiba`統合により
    // 「東京實測全圖」実写版の増上寺クロップ画像を使っている。中山道は`OldMap_Nakasendo`
    // という同種の専用クロップ画像を引き続き使用。）

    static let bashoOkuNoHosomichi = HistoricalOverlayMap(
        id: "basho-oku-no-hosomichi-meiji",
        title: "松尾芭蕉ゆかりの地（深川〜千住）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "松尾芭蕉が『おくのほそ道』へ旅立った深川の芭蕉庵から、矢立初めの地とされる千住までをたどる古地図です。",
        imageAssetName: "OldMap_BashoOkuNoHosomichi",
        // 画像本体は正方形（1024×1024）のキャンバスに、実際の地図内容を横幅の半分弱に
        // 収めた状態（左右が白く余白）で書き出されている。以前は内容部分だけの
        // 実測に近い緯度経度（南北に長い、正方形とはかけ離れた範囲）を指定していたため、
        // GMSGroundOverlayが正方形画像をその細長い範囲へ引き伸ばし、地図が縦に
        // 間延びして見える不具合があった。南北の範囲はそのまま、東西の範囲を
        // 画像の余白比率に合わせて正方形になるまで広げ、引き伸ばしを解消している。
        southWest: CLLocationCoordinate2D(latitude: 35.6531, longitude: 139.7130),
        northEast: CLLocationCoordinate2D(latitude: 35.755, longitude: 139.8380)
    )

    // 赤坂・紀尾井町も同様に、現在の地図のスクリーンショットからピンアイコンを除去して
    // セピア調に加工した「古地図風」画像。実際の歴史史料のスキャンではない。
    // もともと別の古地図だった「麻布・六本木周辺」（`roppongi`）を統合したため、
    // 南側に範囲を広げている。
    static let akasakaKioicho = HistoricalOverlayMap(
        id: "akasaka-kioicho-meiji",
        title: "赤坂・紀尾井町・六本木",
        era: "古地図風（現在の地図をもとに加工）",
        summary: "紀伊徳川家・尾張徳川家・彦根井伊家の屋敷が並び、「紀尾井町」の地名の由来となったエリア。現在の地図をもとにした古地図風の画像で、赤坂の社寺周辺・麻布・六本木も含みます。",
        imageAssetName: "OldMap_AkasakaKioicho",
        southWest: CLLocationCoordinate2D(latitude: 35.64769, longitude: 139.72203),
        northEast: CLLocationCoordinate2D(latitude: 35.69024, longitude: 139.74098)
    )

    // もともと別の古地図だった「芝（増上寺周辺）」（`shiba`）の画像を、東海道の古地図として
    // 品川方面まで範囲を広げて使う形に統合した。画像自体は増上寺周辺のままのため、
    // 日本橋・品川に近い南北の端はやや引き伸ばされた表示になる。
    static let tokaido = HistoricalOverlayMap(
        id: "tokaido-edo",
        title: "東海道（日本橋・芝増上寺・品川）",
        era: "江戸時代（五街道が整備された時期）",
        summary: "五街道の起点・日本橋から、徳川将軍家の菩提寺・増上寺がある芝を経て、東海道最初の宿場・品川宿にかけてのエリアです。",
        imageAssetName: "OldMap_Shiba",
        southWest: CLLocationCoordinate2D(latitude: 35.5865, longitude: 139.7262),
        northEast: CLLocationCoordinate2D(latitude: 35.6835, longitude: 139.7742)
    )

    static let nakasendo = HistoricalOverlayMap(
        id: "nakasendo-edo",
        title: "中山道（本郷〜小石川・巣鴨）",
        era: "江戸時代（五街道が整備された時期）",
        summary: "神田明神・本郷追分など、五街道のひとつ中山道が通っていた本郷・小石川・巣鴨にかけてのエリアです。",
        imageAssetName: "OldMap_Nakasendo",
        southWest: CLLocationCoordinate2D(latitude: 35.680, longitude: 139.700),
        northEast: CLLocationCoordinate2D(latitude: 35.755, longitude: 139.790)
    )

    // 同じ「1891 Meiji Map of Tokyo or Edo, Japan」のフル解像度画像から、原宿・代々木周辺
    // （明治神宮・神宮外苑は当時まだ存在しないため、その前身にあたる代々木御料地・青山練兵場
    // 一帯の町割り）を切り出したもの。位置合わせは地図上の「原宿」等の地名表記を基準にした概算。
    static let meijiJinguOmotesando = HistoricalOverlayMap(
        id: "meiji-jingu-omotesando-meiji",
        title: "明治神宮・表参道",
        era: "明治時代（1891年・明治24年頃、社殿創建前の代々木御料地一帯）",
        summary: "後に明治神宮・表参道となる、代々木・原宿・青山練兵場一帯の古地図です。神宮の鎮座は1920年（大正9年）のため、この地図の時点ではまだ深い森と御料地・練兵場が広がっています。",
        imageAssetName: "OldMap_MeijiJinguOmotesando",
        southWest: CLLocationCoordinate2D(latitude: 35.65776, longitude: 139.69495),
        northEast: CLLocationCoordinate2D(latitude: 35.68296, longitude: 139.73031)
    )

    // 神楽坂・早稲田・新宿も、現在の地図のスクリーンショットからピンアイコンを除去して
    // セピア調に加工した「古地図風」画像。実際の歴史史料のスキャンではない
    // （`akasakaKioicho`/`oyamaKaido`と同じ扱い）。
    static let kagurazakaWasedaShinjuku = HistoricalOverlayMap(
        id: "kagurazaka-waseda-shinjuku-meiji",
        title: "神楽坂・早稲田",
        era: "古地図風（現在の地図をもとに加工）",
        summary: "早稲田大学の学生街と、江戸時代から続く花街・神楽坂をあわせたエリア。現在の地図をもとにした古地図風の画像です。",
        imageAssetName: "OldMap_KagurazakaWasedaShinjuku",
        southWest: CLLocationCoordinate2D(latitude: 35.685, longitude: 139.696),
        northEast: CLLocationCoordinate2D(latitude: 35.712, longitude: 139.744)
    )

    // 現在の地図（OpenStreetMap）から、赤坂〜二子玉川間の大山街道沿いを取得し、
    // セピア調フィルターをかけて古地図風に加工した画像。実際の歴史史料ではない
    // （`akasakaKioicho`と同じ「現在の地図から加工した古地図風画像」の扱い）。
    // ピンアイコン等が写り込んでいない素の地図から作成したため、inpaintによる除去は行っていない。
    static let oyamaKaido = HistoricalOverlayMap(
        id: "oyama-kaido",
        title: "大山街道（赤坂〜二子玉川）",
        era: "古地図風（現在の地図をもとに加工）",
        summary: "江戸時代の大山詣でで賑わった大山街道（矢倉沢往還）のうち、赤坂から青山・渋谷・三軒茶屋・用賀を経て、多摩川の渡し場があった二子玉川までをたどる、現在の地図をもとにした古地図風の画像です。",
        imageAssetName: "OldMap_OyamaKaido",
        southWest: CLLocationCoordinate2D(latitude: 35.585851593232356, longitude: 139.6142578125),
        northEast: CLLocationCoordinate2D(latitude: 35.6929946320988, longitude: 139.74609375)
    )

    // 現在の地図（OpenStreetMap）から新宿御苑・四谷・原宿・渋谷一帯を取得し、セピア調フィルターを
    // かけて古地図風に加工した画像。実際の歴史史料ではなく、映画『君の名は。』の聖地巡礼スポットを
    // めぐるための現代のチェックポイント集（`akasakaKioicho`等と同じ「現在の地図から加工した
    // 古地図風画像」の扱い）。
    static let kiminonaSeichi = HistoricalOverlayMap(
        id: "kiminona-seichi",
        title: "「君の名は。」聖地巡礼",
        era: "現代（映画『君の名は。』の聖地巡礼スポット）",
        summary: "須賀神社の男坂石段や四ツ谷駅など、映画『君の名は。』の舞台として知られる新宿・四谷・原宿・渋谷一帯の聖地巡礼スポットをめぐります。",
        imageAssetName: "OldMap_KiminonaSeichi",
        southWest: CLLocationCoordinate2D(latitude: 35.655, longitude: 139.696),
        northEast: CLLocationCoordinate2D(latitude: 35.697, longitude: 139.733)
    )

    /// 選択可能な古地図の一覧
    static let all: [HistoricalOverlayMap] = [
        edoCastle, asakusa, meijiWriters, nihonbashi,
        goshikiFudo, bashoOkuNoHosomichi, akasakaKioicho,
        tokaido, nakasendo,
        meijiJinguOmotesando, oyamaKaido, kagurazakaWasedaShinjuku,
        kiminonaSeichi,
    ]

    /// 古地図選択シートでの分類（`OldMapPickerSheet`のセクション分けに使う）。
    enum Category: String, CaseIterable {
        case historicSites = "旧跡・名所巡り"
        case kaido = "街道巡り"
        case animePilgrimage = "アニメ聖地巡礼"
    }

    private static let categoryByID: [String: Category] = [
        edoCastle.id: .historicSites,
        asakusa.id: .historicSites,
        meijiWriters.id: .historicSites,
        nihonbashi.id: .historicSites,
        akasakaKioicho.id: .historicSites,
        meijiJinguOmotesando.id: .historicSites,
        kagurazakaWasedaShinjuku.id: .historicSites,
        tokaido.id: .kaido,
        nakasendo.id: .kaido,
        oyamaKaido.id: .kaido,
        bashoOkuNoHosomichi.id: .kaido,
        goshikiFudo.id: .kaido,
        kiminonaSeichi.id: .animePilgrimage,
    ]

    /// この古地図が属する分類。同梱リストにない（ユーザーが検索して追加した）古地図は`nil`。
    static func category(of overlay: HistoricalOverlayMap) -> Category? {
        categoryByID[overlay.id]
    }

    /// 同梱の古地図 + ユーザーが検索して追加した古地図。
    static var allIncludingCustom: [HistoricalOverlayMap] {
        all + CustomOverlayMapStore.all()
    }

    /// 統合によって廃止されたID → 統合先IDの対応表。
    /// 過去の旅・保存した物語などに保存済みの廃止IDを、表示時に統合先の地図へ読み替える。
    private static let mergedIntoID: [String: String] = [
        "ueno-edo": "meiji-writers",
        "shiba-edo": "tokaido-edo",
        "kanda-edo": "nihonbashi-edo",
        "roppongi-meiji": "akasaka-kioicho-meiji",
        "kasumigaseki-toranomon-meiji": "edo-castle-1850s",
        "kudanshita-chidorigafuchi-meiji": "edo-castle-1850s",
    ]

    /// 保存されているIDを、廃止されていれば統合先のIDに読み替えてから古地図を探す。
    static func resolve(id: String?) -> HistoricalOverlayMap? {
        guard let id else { return nil }
        let resolvedID = mergedIntoID[id] ?? id
        return allIncludingCustom.first { $0.id == resolvedID }
    }
}
