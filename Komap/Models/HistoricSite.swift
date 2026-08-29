import CoreLocation
import Foundation

/// 地図上にチェックポイントとして強調表示する史跡1件分の情報。
///
/// - Important: 座標はこのサンプルアプリ用のおおよその位置です。
///   正確な参拝・観光情報については各史跡の公式情報をご確認ください。
struct HistoricSite: Identifiable, Hashable {
    let id: String
    let name: String
    /// 御朱印帳カードに添える一言（時代・由来など）
    let summary: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: HistoricSite, rhs: HistoricSite) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// アプリに同梱している史跡チェックポイントのカタログ。
enum HistoricSiteCatalog {
    static let all: [HistoricSite] = [
        HistoricSite(
            id: "edo-castle",
            name: "江戸城(皇居)",
            summary: "徳川将軍家の居城。現在は皇居として使われています。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6852, longitude: 139.7528)
        ),
        HistoricSite(
            id: "sensoji",
            name: "浅草寺",
            summary: "都内最古の寺院と伝わる、雷門と仲見世通りで知られる名刹。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7148, longitude: 139.7967)
        ),
        HistoricSite(
            id: "kanda-myojin",
            name: "神田明神",
            summary: "江戸総鎮守として庶民に親しまれてきた神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7020, longitude: 139.7671)
        ),
        HistoricSite(
            id: "yushima-tenmangu",
            name: "湯島天満宮",
            summary: "学問の神様・菅原道真公を祀る、梅の名所としても有名な神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7075, longitude: 139.7686)
        ),
        HistoricSite(
            id: "zojoji",
            name: "増上寺",
            summary: "徳川将軍家の菩提寺のひとつ。東京タワーを背景にした大殿で知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6572, longitude: 139.7492)
        ),
        HistoricSite(
            id: "yasukuni-shrine",
            name: "靖国神社",
            summary: "幕末以来の歴史を持つ、桜の名所としても知られる神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6938, longitude: 139.7434)
        ),
        HistoricSite(
            id: "tomioka-hachimangu",
            name: "富岡八幡宮",
            summary: "江戸最大級の八幡様。深川の総鎮守として栄えた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6720, longitude: 139.7972)
        ),
        HistoricSite(
            id: "shiba-daijingu",
            name: "芝大神宮",
            summary: "「関東のお伊勢さま」と呼ばれ、江戸時代から篤く信仰された神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6559, longitude: 139.7573)
        ),
    ]

    static func site(withID id: String) -> HistoricSite? {
        all.first { $0.id == id }
    }
}
