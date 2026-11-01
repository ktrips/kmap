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

        // プラハ（カフカと『プラハの春』）
        "prague-kafka-birthplace": CrestBadge(symbolName: "house.fill", tint: sable),
        "prague-golden-lane": CrestBadge(symbolName: "pencil", tint: goldBright),
        "prague-charles-bridge": CrestBadge(symbolName: "building.columns.fill", tint: azure),
        "prague-kafka-museum": CrestBadge(symbolName: "book.fill", tint: sable),
        "prague-wenceslas-square": CrestBadge(symbolName: "flag.fill", tint: gules),
        "prague-kafka-head": CrestBadge(symbolName: "person.fill", tint: teal),

        // ウィーン（『第三の男』の街）
        "vienna-schreyvogelgasse": CrestBadge(symbolName: "lightbulb.fill", tint: goldBright),
        "vienna-josefsplatz": CrestBadge(symbolName: "car.fill", tint: sable),
        "vienna-cafe-mozart": CrestBadge(symbolName: "cup.and.saucer.fill", tint: gules),
        "vienna-am-hof": CrestBadge(symbolName: "drop.fill", tint: azure),
        "vienna-stephansdom": CrestBadge(symbolName: "cross.fill", tint: gules),
        "vienna-riesenrad": CrestBadge(symbolName: "circle.circle", tint: goldBright),

        // ヴェネツィア（『ヴェニスの商人』）
        "venice-rialto": CrestBadge(symbolName: "scalemass.fill", tint: goldBright),
        "venice-ghetto": CrestBadge(symbolName: "key.fill", tint: sable),
        "venice-san-marco": CrestBadge(symbolName: "crown.fill", tint: gules),
        "venice-doge-palace": CrestBadge(symbolName: "building.columns.fill", tint: gules),
        "venice-arsenale": CrestBadge(symbolName: "sailboat.fill", tint: azure),
        "venice-accademia": CrestBadge(symbolName: "paintpalette.fill", tint: teal),

        // ローマ（『天使と悪魔』の道）
        "rome-santa-maria-del-popolo": CrestBadge(symbolName: "mountain.2.fill", tint: vert),
        "rome-st-peters-square": CrestBadge(symbolName: "wind", tint: azure),
        "rome-santa-maria-della-vittoria": CrestBadge(symbolName: "flame.fill", tint: gules),
        "rome-piazza-navona": CrestBadge(symbolName: "drop.fill", tint: teal),
        "rome-castel-sant-angelo": CrestBadge(symbolName: "sun.max.fill", tint: goldBright),
        "rome-pantheon": CrestBadge(symbolName: "building.columns.fill", tint: sable),

        // フィレンツェ（『冷静と情熱のあいだ』）
        "florence-duomo-cupola": CrestBadge(symbolName: "heart.fill", tint: gules),
        "florence-ponte-vecchio": CrestBadge(symbolName: "sparkles", tint: goldBright),
        "florence-uffizi": CrestBadge(symbolName: "paintbrush.fill", tint: azure),
        "florence-santa-croce": CrestBadge(symbolName: "cross.fill", tint: sable),
        "florence-palazzo-pitti": CrestBadge(symbolName: "hammer.fill", tint: vert),
        "florence-piazzale-michelangelo": CrestBadge(symbolName: "sunset.fill", tint: gules),

        // パリ・シテ島と左岸（ユゴーの物語）
        "paris-notre-dame": CrestBadge(symbolName: "bell.fill", tint: sable),
        "paris-place-des-vosges": CrestBadge(symbolName: "pencil", tint: azure),
        "paris-pantheon": CrestBadge(symbolName: "building.columns.fill", tint: goldBright),
        "paris-luxembourg": CrestBadge(symbolName: "leaf.fill", tint: vert),
        "paris-saint-sulpice": CrestBadge(symbolName: "heart.fill", tint: gules),
        "paris-saint-eustache": CrestBadge(symbolName: "flag.fill", tint: gules),

        // ロンドン（シャーロック・ホームズの時代）
        "london-baker-street": CrestBadge(symbolName: "magnifyingglass", tint: sable),
        "london-langham": CrestBadge(symbolName: "crown.fill", tint: goldBright),
        "london-montague-street": CrestBadge(symbolName: "books.vertical.fill", tint: azure),
        "london-criterion": CrestBadge(symbolName: "wineglass.fill", tint: gules),
        "london-lyceum": CrestBadge(symbolName: "theatermasks.fill", tint: teal),

        // エディンバラ旧市街（ジキルとハイド、ハリー・ポッター）
        "edinburgh-castle": CrestBadge(symbolName: "shield.fill", tint: sable),
        "edinburgh-writers-museum": CrestBadge(symbolName: "book.fill", tint: azure),
        "edinburgh-victoria-street": CrestBadge(symbolName: "wand.and.stars", tint: goldBright),
        "edinburgh-deacon-brodie": CrestBadge(symbolName: "moon.fill", tint: sable),
        "edinburgh-elephant-house": CrestBadge(symbolName: "cup.and.saucer.fill", tint: gules),
        "edinburgh-balmoral": CrestBadge(symbolName: "star.fill", tint: goldBright),

        // ダブリン（ジョイス『ユリシーズ』）
        "dublin-eccles-street": CrestBadge(symbolName: "house.fill", tint: vert),
        "dublin-joyce-centre": CrestBadge(symbolName: "book.fill", tint: vert),
        "dublin-ormond-hotel": CrestBadge(symbolName: "music.note", tint: goldBright),
        "dublin-trinity-college": CrestBadge(symbolName: "graduationcap.fill", tint: azure),
        "dublin-davy-byrnes": CrestBadge(symbolName: "fork.knife", tint: gules),
        "dublin-sweny": CrestBadge(symbolName: "bubbles.and.sparkles.fill", tint: teal),

        // ベルリン（森鷗外『舞姫』）
        "berlin-brandenburg-gate": CrestBadge(symbolName: "tree.fill", tint: vert),
        "berlin-kaiserhof": CrestBadge(symbolName: "crown.fill", tint: sable),
        "berlin-university": CrestBadge(symbolName: "graduationcap.fill", tint: azure),
        "berlin-mori-ogai-memorial": CrestBadge(symbolName: "pencil", tint: gules),
        "berlin-klosterstrasse": CrestBadge(symbolName: "figure.dance", tint: gules),
    ]

    static func badge(for siteID: String) -> CrestBadge? {
        byID[siteID]
    }
}
