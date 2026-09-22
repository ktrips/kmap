import SwiftUI

/// 「Komap Global」のチェックポイントで、御朱印（`seal.fill`）の代わりに表示する
/// 紋章（クレスト）風バッジ。SFシンボル + 地の彩色（tincture）の組み合わせだけで表現する
/// 軽量な仕組みで、`HistoricSite`ごとの専用画像は用意していない。
struct CrestBadge {
    let symbolName: String
    let tint: Color
}

extension Color {
    /// "8F2233" のような6桁の16進文字列からRGB各成分を作る。紋章の彩色は
    /// コンセプトのSVGクレストと揃えた固定値なので、パース失敗時のフォールバックは考慮していない。
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// `HistoricSite.id` → 紋章バッジの対応表。同梱の東京版チェックポイントは載せておらず、
/// `badge(for:)`が`nil`を返した場合は呼び出し側で従来の金の御朱印（`seal.fill`）を表示する。
enum CrestBadgeCatalog {
    private static let gules = Color(hex: "8F2233")
    private static let azure = Color(hex: "2E4F6E")
    private static let sable = Color(hex: "3A332A")
    private static let vert = Color(hex: "3C5A34")
    private static let teal = Color(hex: "2C5651")
    private static let goldBright = Color(hex: "C99A3A")

    private static let byID: [String: CrestBadge] = [
        // アムステルダム
        "amsterdam-dam": CrestBadge(symbolName: "crown.fill", tint: gules),
        "amsterdam-waag": CrestBadge(symbolName: "scalemass.fill", tint: sable),
        "amsterdam-begijnhof": CrestBadge(symbolName: "leaf.fill", tint: azure),
        "amsterdam-montelbaanstoren": CrestBadge(symbolName: "building.fill", tint: sable),
        "amsterdam-voc-harbor": CrestBadge(symbolName: "sailboat.fill", tint: azure),

        // ヘルシンキ
        "helsinki-senate-square": CrestBadge(symbolName: "building.columns.fill", tint: azure),
        "helsinki-suomenlinna": CrestBadge(symbolName: "star.fill", tint: sable),
        "helsinki-kauppatori": CrestBadge(symbolName: "fish.fill", tint: azure),
        "helsinki-uspenski": CrestBadge(symbolName: "cross.fill", tint: gules),
        "helsinki-vanhakaupunki": CrestBadge(symbolName: "leaf.fill", tint: vert),

        // ストックホルム
        "stockholm-storkyrkan": CrestBadge(symbolName: "bell.fill", tint: gules),
        "stockholm-riddarholmen": CrestBadge(symbolName: "building.columns.fill", tint: sable),
        "stockholm-royal-palace": CrestBadge(symbolName: "crown.fill", tint: azure),
        "stockholm-skeppsholmen": CrestBadge(symbolName: "sailboat.fill", tint: azure),
        "stockholm-slussen": CrestBadge(symbolName: "key.fill", tint: goldBright),

        // タリン
        "tallinn-raekoja-plats": CrestBadge(symbolName: "building.columns.fill", tint: sable),
        "tallinn-toompea": CrestBadge(symbolName: "flag.fill", tint: azure),
        "tallinn-viru-gate": CrestBadge(symbolName: "building.2.fill", tint: sable),
        "tallinn-oleviste": CrestBadge(symbolName: "flame.fill", tint: gules),
        "tallinn-paks-margareeta": CrestBadge(symbolName: "shield.fill", tint: teal),
    ]

    static func badge(for siteID: String) -> CrestBadge? {
        byID[siteID]
    }
}
