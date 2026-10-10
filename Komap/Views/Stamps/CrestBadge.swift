import SwiftUI

/// Europeリージョン（海外の旧市街）のチェックポイントで、御朱印（`seal.fill`）の代わりに表示する
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
        "amsterdam-westerkerk": CrestBadge(symbolName: "crown.fill", tint: azure),
        "amsterdam-munttoren": CrestBadge(symbolName: "clock.fill", tint: gules),
        "amsterdam-oude-kerk": CrestBadge(symbolName: "bell.fill", tint: sable),

        // ヘルシンキ
        "helsinki-senate-square": CrestBadge(symbolName: "building.columns.fill", tint: azure),
        "helsinki-suomenlinna": CrestBadge(symbolName: "star.fill", tint: sable),
        "helsinki-kauppatori": CrestBadge(symbolName: "fish.fill", tint: azure),
        "helsinki-uspenski": CrestBadge(symbolName: "cross.fill", tint: gules),
        "helsinki-vanhakaupunki": CrestBadge(symbolName: "leaf.fill", tint: vert),
        "helsinki-railway-station": CrestBadge(symbolName: "tram.fill", tint: vert),
        "helsinki-temppeliaukio": CrestBadge(symbolName: "mountain.2.fill", tint: sable),
        "helsinki-sibelius": CrestBadge(symbolName: "music.note", tint: azure),

        // ストックホルム
        "stockholm-storkyrkan": CrestBadge(symbolName: "bell.fill", tint: gules),
        "stockholm-riddarholmen": CrestBadge(symbolName: "building.columns.fill", tint: sable),
        "stockholm-royal-palace": CrestBadge(symbolName: "crown.fill", tint: azure),
        "stockholm-skeppsholmen": CrestBadge(symbolName: "sailboat.fill", tint: azure),
        "stockholm-slussen": CrestBadge(symbolName: "key.fill", tint: goldBright),
        "stockholm-stortorget": CrestBadge(symbolName: "house.fill", tint: gules),
        "stockholm-riddarhuset": CrestBadge(symbolName: "shield.lefthalf.filled", tint: azure),
        "stockholm-marten-trotzig": CrestBadge(symbolName: "figure.walk", tint: sable),
        "stockholm-city-hall": CrestBadge(symbolName: "crown.fill", tint: gules),
        "stockholm-zum-franziskaner": CrestBadge(symbolName: "mug.fill", tint: goldBright),
        "stockholm-tyska-brinken": CrestBadge(symbolName: "stairs", tint: sable),

        // タリン
        "tallinn-raekoja-plats": CrestBadge(symbolName: "building.columns.fill", tint: sable),
        "tallinn-toompea": CrestBadge(symbolName: "flag.fill", tint: azure),
        "tallinn-viru-gate": CrestBadge(symbolName: "building.2.fill", tint: sable),
        "tallinn-oleviste": CrestBadge(symbolName: "flame.fill", tint: gules),
        "tallinn-paks-margareeta": CrestBadge(symbolName: "shield.fill", tint: teal),
        "tallinn-toomkirik": CrestBadge(symbolName: "cross.fill", tint: azure),
        "tallinn-katariina-kaik": CrestBadge(symbolName: "hammer.fill", tint: sable),
        "tallinn-kohtuotsa": CrestBadge(symbolName: "binoculars.fill", tint: teal),

        // パリ・モンマルトル（芸術家の家めぐり）
        "paris-bateau-lavoir": CrestBadge(symbolName: "paintpalette.fill", tint: azure),
        "paris-van-gogh": CrestBadge(symbolName: "sun.max.fill", tint: goldBright),
        "paris-musee-montmartre": CrestBadge(symbolName: "paintbrush.pointed.fill", tint: gules),
        "paris-moulin-galette": CrestBadge(symbolName: "music.note", tint: azure),
        "paris-lapin-agile": CrestBadge(symbolName: "star.fill", tint: sable),
        "paris-moulin-rouge": CrestBadge(symbolName: "theatermasks.fill", tint: gules),

        // ロンドン（シェイクスピアの時代）
        "london-globe": CrestBadge(symbolName: "theatermasks.fill", tint: gules),
        "london-rose": CrestBadge(symbolName: "star.fill", tint: gules),
        "london-southwark-cathedral": CrestBadge(symbolName: "cross.fill", tint: azure),
        "london-bridge": CrestBadge(symbolName: "building.2.fill", tint: sable),
        "london-st-pauls": CrestBadge(symbolName: "book.fill", tint: azure),
        "london-tower": CrestBadge(symbolName: "crown.fill", tint: sable),

        // ブリュッセル（ベルギー王国の心臓部）
        "brussels-grand-place": CrestBadge(symbolName: "building.columns.fill", tint: goldBright),
        "brussels-manneken-pis": CrestBadge(symbolName: "drop.fill", tint: azure),
        "brussels-galeries-saint-hubert": CrestBadge(symbolName: "bag.fill", tint: sable),
        "brussels-cathedral": CrestBadge(symbolName: "cross.fill", tint: azure),
        "brussels-mont-des-arts": CrestBadge(symbolName: "paintpalette.fill", tint: gules),
        "brussels-royal-palace": CrestBadge(symbolName: "crown.fill", tint: gules),
        "brussels-sainte-catherine": CrestBadge(symbolName: "fish.fill", tint: azure),
        "brussels-jeu-de-balle": CrestBadge(symbolName: "cart.fill", tint: sable),
    ]

    static func badge(for siteID: String) -> CrestBadge? {
        byID[siteID]
    }
}
