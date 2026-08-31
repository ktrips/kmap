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
    let imageAssetName: String?
    /// `StampPhotoStore`に保存したファイル名。検索して追加した古地図で使う。
    let imageFileName: String?
    /// 画像の左下（南西）に対応する緯度経度
    let southWest: CLLocationCoordinate2D
    /// 画像の右上（北東）に対応する緯度経度
    let northEast: CLLocationCoordinate2D

    init(
        id: String,
        title: String,
        era: String,
        summary: String,
        imageAssetName: String? = nil,
        imageFileName: String? = nil,
        southWest: CLLocationCoordinate2D,
        northEast: CLLocationCoordinate2D
    ) {
        self.id = id
        self.title = title
        self.era = era
        self.summary = summary
        self.imageAssetName = imageAssetName
        self.imageFileName = imageFileName
        self.southWest = southWest
        self.northEast = northEast
    }

    /// この古地図がカバーする範囲の中心（初期表示時のカメラ位置に使う）
    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (southWest.latitude + northEast.latitude) / 2,
            longitude: (southWest.longitude + northEast.longitude) / 2
        )
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
        summary: "江戸城の内堀・外堀と大名屋敷が広がっていたエリア。現在の皇居・大手町・丸の内周辺に相当します。",
        imageAssetName: "OldMap_EdoCastle",
        southWest: CLLocationCoordinate2D(latitude: 35.674, longitude: 139.740),
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

    // 以下6枚は「東京實測全圖」（1891年・明治24年、Geographicus発行）の実画像を
    // エリアごとに切り出したもの。1931年より前に発行されたためパブリックドメイン
    // （出典: Wikimedia Commons）。位置合わせは地図上の目印（不忍池・皇居のお堀等）
    // を基準に手作業で行った概算で、史料的に厳密な測量座標ではない。

    static let meijiWriters = HistoricalOverlayMap(
        id: "meiji-writers",
        title: "明治の文豪の家（本郷・谷中）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "夏目漱石・森鴎外・樋口一葉など、明治の文豪たちが暮らした本郷・千駄木・谷中周辺のエリアです。帝国大学（現・東京大学）や不忍池も見えます。",
        imageAssetName: "OldMap_MeijiWriters",
        // 谷中七福神のうち田端・西日暮里側の3社寺も収まるよう、北側を少し広げている
        // （元画像自体の解像度はそのままのため、北端付近はやや引き伸ばされた表示になる）。
        southWest: CLLocationCoordinate2D(latitude: 35.6929, longitude: 139.7484),
        northEast: CLLocationCoordinate2D(latitude: 35.7395, longitude: 139.7895)
    )

    static let ueno = HistoricalOverlayMap(
        id: "ueno-edo",
        title: "上野（寛永寺・不忍池周辺）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "徳川将軍家の菩提寺・寛永寺と不忍池を中心に広がっていたエリア。現在の上野公園周辺に相当します。",
        imageAssetName: "OldMap_Ueno",
        southWest: CLLocationCoordinate2D(latitude: 35.6968, longitude: 139.7573),
        northEast: CLLocationCoordinate2D(latitude: 35.7311, longitude: 139.7984)
    )

    static let nihonbashi = HistoricalOverlayMap(
        id: "nihonbashi-edo",
        title: "日本橋（商人の町）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "五街道の起点・日本橋を中心に、商人たちの店が軒を連ねた経済の中心地。",
        imageAssetName: "OldMap_Nihonbashi",
        southWest: CLLocationCoordinate2D(latitude: 35.6638, longitude: 139.7505),
        northEast: CLLocationCoordinate2D(latitude: 35.6981, longitude: 139.7916)
    )

    static let shiba = HistoricalOverlayMap(
        id: "shiba-edo",
        title: "芝（増上寺周辺）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "徳川将軍家の菩提寺のひとつ・増上寺を中心に広がっていたエリア。現在の芝公園周辺に相当します。",
        imageAssetName: "OldMap_Shiba",
        southWest: CLLocationCoordinate2D(latitude: 35.6379, longitude: 139.7262),
        northEast: CLLocationCoordinate2D(latitude: 35.6722, longitude: 139.7673)
    )

    static let kanda = HistoricalOverlayMap(
        id: "kanda-edo",
        title: "神田（神田明神周辺）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "江戸総鎮守・神田明神の門前町として栄えたエリア。現在の神田・御茶ノ水周辺に相当します。",
        imageAssetName: "OldMap_Kanda",
        southWest: CLLocationCoordinate2D(latitude: 35.6823, longitude: 139.7518),
        northEast: CLLocationCoordinate2D(latitude: 35.7166, longitude: 139.7929)
    )

    static let roppongi = HistoricalOverlayMap(
        id: "roppongi-meiji",
        title: "麻布・六本木周辺（明治時代）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "大名屋敷が置かれていた麻布・六本木の町割りが広がっていたエリア。現在の六本木ヒルズ（毛利庭園）・乃木神社周辺に相当します。",
        imageAssetName: "OldMap_Roppongi",
        southWest: CLLocationCoordinate2D(latitude: 35.655, longitude: 139.720),
        northEast: CLLocationCoordinate2D(latitude: 35.672, longitude: 139.740)
    )

    // 以下2枚は「1891 Meiji Map of Tokyo or Edo, Japan」（Geographicus発行、東京實測全圖の英語版）
    // の実画像を、地域を絞らず広域のまま使ったもの。1931年より前に発行されたためパブリックドメイン
    // （出典: Wikimedia Commons）。目黒・世田谷・豊島など東京十五区の外側にあたるエリアも含むため、
    // 他の6枚に比べて図の密度は粗く、位置合わせもより概算になる。

    static let goshikiFudo = HistoricalOverlayMap(
        id: "goshiki-fudo-meiji",
        title: "五色不動めぐり（目黒・目白・目赤・目青・目黄）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "江戸の町を鬼門から守るとされた五色不動を東西南北にめぐる、広域の古地図です。目黒区・豊島区・文京区・世田谷区・台東区にまたがります。",
        imageAssetName: "OldMap_TokyoMeiji1891",
        southWest: CLLocationCoordinate2D(latitude: 35.615, longitude: 139.660),
        northEast: CLLocationCoordinate2D(latitude: 35.755, longitude: 139.825)
    )

    static let bashoOkuNoHosomichi = HistoricalOverlayMap(
        id: "basho-oku-no-hosomichi-meiji",
        title: "松尾芭蕉ゆかりの地（深川〜千住）",
        era: "明治時代（1891年・明治24年頃）",
        summary: "松尾芭蕉が『おくのほそ道』へ旅立った深川の芭蕉庵から、矢立初めの地とされる千住までをたどる古地図です。",
        imageAssetName: "OldMap_TokyoMeiji1891",
        southWest: CLLocationCoordinate2D(latitude: 35.615, longitude: 139.660),
        northEast: CLLocationCoordinate2D(latitude: 35.755, longitude: 139.825)
    )

    /// 選択可能な古地図の一覧
    static let all: [HistoricalOverlayMap] = [
        edoCastle, asakusa, meijiWriters, ueno, nihonbashi, shiba, kanda, roppongi,
        goshikiFudo, bashoOkuNoHosomichi,
    ]

    /// 同梱の古地図 + ユーザーが検索して追加した古地図。
    static var allIncludingCustom: [HistoricalOverlayMap] {
        all + CustomOverlayMapStore.all()
    }
}
