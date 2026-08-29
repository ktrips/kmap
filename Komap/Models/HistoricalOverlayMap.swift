import CoreLocation
import Foundation

/// 古地図1枚分の情報（画像アセット・時代・位置合わせ範囲）を表す。
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
    /// Assets.xcassets 内の画像名
    let imageAssetName: String
    /// 画像の左下（南西）に対応する緯度経度
    let southWest: CLLocationCoordinate2D
    /// 画像の右上（北東）に対応する緯度経度
    let northEast: CLLocationCoordinate2D

    /// この古地図がカバーする範囲の中心（初期表示時のカメラ位置に使う）
    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (southWest.latitude + northEast.latitude) / 2,
            longitude: (southWest.longitude + northEast.longitude) / 2
        )
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
        title: "江戸城周辺（安政期・1850年代）",
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

    static let meijiWriters = HistoricalOverlayMap(
        id: "meiji-writers",
        title: "明治の文豪の家（本郷・千駄木・谷中）",
        era: "明治時代（文豪たちが暮らした頃）",
        summary: "夏目漱石・森鴎外・樋口一葉など、明治の文豪たちが暮らした本郷・千駄木・谷中周辺のエリアです。",
        imageAssetName: "OldMap_MeijiWriters",
        southWest: CLLocationCoordinate2D(latitude: 35.715, longitude: 139.760),
        northEast: CLLocationCoordinate2D(latitude: 35.728, longitude: 139.775)
    )

    static let ueno = HistoricalOverlayMap(
        id: "ueno-edo",
        title: "上野（寛永寺・不忍池周辺）",
        era: "江戸時代（寛永寺の門前として栄えた頃）",
        summary: "徳川将軍家の菩提寺・寛永寺と不忍池を中心に広がっていたエリア。現在の上野公園周辺に相当します。",
        imageAssetName: "OldMap_Ueno",
        southWest: CLLocationCoordinate2D(latitude: 35.710, longitude: 139.767),
        northEast: CLLocationCoordinate2D(latitude: 35.722, longitude: 139.780)
    )

    static let nihonbashi = HistoricalOverlayMap(
        id: "nihonbashi-edo",
        title: "日本橋（商人の町）",
        era: "江戸時代（五街道の起点として栄えた頃）",
        summary: "五街道の起点・日本橋を中心に、商人たちの店が軒を連ねた江戸の経済の中心地。",
        imageAssetName: "OldMap_Nihonbashi",
        southWest: CLLocationCoordinate2D(latitude: 35.678, longitude: 139.767),
        northEast: CLLocationCoordinate2D(latitude: 35.688, longitude: 139.780)
    )

    static let shiba = HistoricalOverlayMap(
        id: "shiba-edo",
        title: "芝（増上寺周辺）",
        era: "江戸時代（増上寺の門前町として栄えた頃）",
        summary: "徳川将軍家の菩提寺のひとつ・増上寺を中心に広がっていたエリア。現在の芝公園周辺に相当します。",
        imageAssetName: "OldMap_Shiba",
        southWest: CLLocationCoordinate2D(latitude: 35.650, longitude: 139.743),
        northEast: CLLocationCoordinate2D(latitude: 35.662, longitude: 139.756)
    )

    static let kanda = HistoricalOverlayMap(
        id: "kanda-edo",
        title: "神田（神田明神周辺）",
        era: "江戸時代（江戸総鎮守として栄えた頃）",
        summary: "江戸総鎮守・神田明神の門前町として栄えたエリア。現在の神田・御茶ノ水周辺に相当します。",
        imageAssetName: "OldMap_Kanda",
        southWest: CLLocationCoordinate2D(latitude: 35.696, longitude: 139.762),
        northEast: CLLocationCoordinate2D(latitude: 35.706, longitude: 139.772)
    )

    /// 選択可能な古地図の一覧
    static let all: [HistoricalOverlayMap] = [
        edoCastle, asakusa, meijiWriters, ueno, nihonbashi, shiba, kanda,
    ]
}
