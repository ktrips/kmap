import CoreLocation
import Foundation

/// 地図上にチェックポイントとして強調表示する史跡1件分の情報。
///
/// - Important: 座標はこのサンプルアプリ用のおおよその位置です。
///   正確な参拝・観光情報については各史跡の公式情報をご確認ください。
struct HistoricSite: Identifiable, Hashable {
    let id: String
    /// この史跡が属する古地図（`HistoricalOverlayMap.id`）。
    /// 地図タブでは、選択中の古地図と同じIDを持つ史跡だけをチェックポイントとして表示する。
    let overlayMapID: String
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
///
/// 古地図1枚につき5箇所程度、その地図のテーマに沿ったチェックポイントを用意している。
enum HistoricSiteCatalog {
    static let all: [HistoricSite] = [
        // 江戸城周辺（安政期・1850年代）
        HistoricSite(
            id: "edo-castle-sakuradamon",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "桜田門",
            summary: "江戸城外桜田門。桜田門外の変の舞台としても知られる、城の南西を守る門。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6773, longitude: 139.7539)
        ),
        HistoricSite(
            id: "edo-castle-wadakuramon",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "和田倉門",
            summary: "大名行列も通った、江戸城内堀に面した門のひとつ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.7565)
        ),
        HistoricSite(
            id: "edo-castle-nijubashi",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "二重橋",
            summary: "江戸城正門にあたる、皇居を象徴する橋。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6825, longitude: 139.7528)
        ),
        HistoricSite(
            id: "edo-castle-otemon",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "大手門",
            summary: "江戸城の正面玄関にあたる、最も格式の高い門。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6873, longitude: 139.7565)
        ),

        // 浅草・浅草寺周辺（江戸時代）
        HistoricSite(
            id: "asakusa-kaminarimon",
            overlayMapID: OldMapCatalog.asakusa.id,
            name: "雷門",
            summary: "浅草寺の総門。大提灯で知られる、浅草のシンボル的な門。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7107, longitude: 139.7964)
        ),
        HistoricSite(
            id: "asakusa-nakamise",
            overlayMapID: OldMapCatalog.asakusa.id,
            name: "仲見世通り",
            summary: "雷門から宝蔵門まで続く、江戸時代から続く日本最古級の商店街。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7115, longitude: 139.7967)
        ),
        HistoricSite(
            id: "asakusa-sensoji",
            overlayMapID: OldMapCatalog.asakusa.id,
            name: "浅草寺本堂",
            summary: "都内最古の寺院と伝わる、浅草の中心的な信仰の場。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7148, longitude: 139.7967)
        ),
        HistoricSite(
            id: "asakusa-gojunoto",
            overlayMapID: OldMapCatalog.asakusa.id,
            name: "五重塔",
            summary: "浅草寺の境内にそびえる、江戸の町からも見えたという五重塔。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7143, longitude: 139.7960)
        ),
        HistoricSite(
            id: "asakusa-hanayashiki",
            overlayMapID: OldMapCatalog.asakusa.id,
            name: "花やしき",
            summary: "江戸末期に花園として開園した、日本最古級の遊園地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7157, longitude: 139.7943)
        ),

        // 明治の文豪の家（本郷・千駄木・谷中）
        HistoricSite(
            id: "writers-ogai",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "森鴎外の家（観潮楼跡）",
            summary: "森鴎外が晩年まで暮らした邸宅跡。現在は森鴎外記念館が建つ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7217, longitude: 139.7663)
        ),
        HistoricSite(
            id: "writers-soseki",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "夏目漱石旧居跡（猫の家）",
            summary: "『吾輩は猫である』を執筆した、漱石が暮らした借家の跡地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7215, longitude: 139.7654)
        ),
        HistoricSite(
            id: "writers-ichiyo",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "樋口一葉旧居跡",
            summary: "一葉が家族と暮らし、多くの作品を生み出した本郷菊坂の旧居跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7106, longitude: 139.7595)
        ),
        HistoricSite(
            id: "writers-takuboku",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "石川啄木の旧居",
            summary: "啄木が上京後に間借りした、本郷菊坂周辺の旧居跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7108, longitude: 139.7597)
        ),
        // 上野（寛永寺・不忍池周辺）※「明治の文豪（本郷・上野）」に統合済み
        HistoricSite(
            id: "ueno-bentendo",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "不忍池辯天堂",
            summary: "不忍池に浮かぶ中之島に建つ、弁財天を祀るお堂。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7139, longitude: 139.7717)
        ),
        HistoricSite(
            id: "ueno-toshogu",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "上野東照宮",
            summary: "徳川家康を祀る、金色殿で知られる荘厳な東照宮。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7161, longitude: 139.7724)
        ),
        // 日本橋（商人の町）
        HistoricSite(
            id: "nihonbashi-mitsukoshi",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "三越日本橋本店",
            summary: "江戸時代の呉服店「越後屋」を起源とする老舗百貨店。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6852, longitude: 139.7734)
        ),
        HistoricSite(
            id: "nihonbashi-uoichiba",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "日本橋魚市場発祥の地",
            summary: "江戸っ子の台所として栄えた、日本橋魚河岸の跡地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6837, longitude: 139.7738)
        ),
        HistoricSite(
            id: "nihonbashi-boj",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "日本銀行本店",
            summary: "金座の跡地に建つ、日本の中央銀行本店。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6862, longitude: 139.7745)
        ),
        HistoricSite(
            id: "nihonbashi-edobashi",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "江戸橋",
            summary: "日本橋川に架かる、江戸時代からの交通の要所。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6820, longitude: 139.7758)
        ),

        // 芝（増上寺周辺）※「東海道（日本橋・芝増上寺・品川）」に統合済み
        HistoricSite(
            id: "shiba-zojoji",
            overlayMapID: OldMapCatalog.tokaido.id,
            name: "増上寺・芝東照宮",
            summary: "徳川将軍家の菩提寺・増上寺と、家康を祀る隣接の東照宮。東京タワーを背にそびえる大殿で知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6572, longitude: 139.7492)
        ),

        // 神田（神田明神周辺）※「日本橋・神田明神」に統合済み
        HistoricSite(
            id: "kanda-myojin-checkpoint",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "神田明神",
            summary: "江戸総鎮守として庶民に親しまれてきた神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7020, longitude: 139.7671)
        ),
        HistoricSite(
            id: "kanda-seido",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "湯島聖堂",
            summary: "儒学の学問所として栄えた、孔子廟を祀る史跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7009, longitude: 139.7659)
        ),
        HistoricSite(
            id: "kanda-nikolai-do",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "ニコライ堂",
            summary: "明治時代に建てられた、ビザンチン様式の大聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6976, longitude: 139.7644)
        ),
        HistoricSite(
            id: "kanda-shohei-bridge",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "昌平橋",
            summary: "神田川に架かる、湯島聖堂のそばの古くからの橋。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6989, longitude: 139.7659)
        ),

        // 谷中七福神（田端・西日暮里・谷中・上野公園）
        HistoricSite(
            id: "yanaka7-tokakuji",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "東覚寺（福禄寿）",
            summary: "谷中七福神の福禄寿を祀る、田端にある赤紙仁王で知られる寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7355, longitude: 139.7585)
        ),
        HistoricSite(
            id: "yanaka7-seiunji",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "青雲寺（恵比寿）",
            summary: "谷中七福神の恵比寿を祀る、西日暮里の花見寺のひとつ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7311, longitude: 139.7660)
        ),
        HistoricSite(
            id: "yanaka7-shushoin",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "修性院（布袋尊）",
            summary: "谷中七福神の布袋尊を祀る、西日暮里の花見寺のひとつ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7301, longitude: 139.7661)
        ),
        HistoricSite(
            id: "yanaka7-choanji",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "長安寺（寿老人）",
            summary: "谷中七福神の寿老人を祀る、谷中霊園近くの寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7252, longitude: 139.7684)
        ),
        HistoricSite(
            id: "yanaka7-tennoji",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "天王寺（毘沙門天）",
            summary: "谷中七福神の毘沙門天を祀る、谷中霊園に隣接する古刹。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7267, longitude: 139.7712)
        ),
        HistoricSite(
            id: "yanaka7-gokokuin",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "護国院（大黒天）",
            summary: "谷中七福神の大黒天を祀る、上野公園内の寛永寺子院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7193, longitude: 139.7701)
        ),
        HistoricSite(
            id: "yanaka7-bentendo",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "不忍池辯天堂（弁才天）",
            summary: "谷中七福神の弁才天を祀る、不忍池に浮かぶお堂。江戸最古とされる七福神めぐりの終点。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7139, longitude: 139.7717)
        ),

        // 五色不動めぐり（目黒・目白・目赤・目青・目黄）
        HistoricSite(
            id: "goshiki-meguro",
            overlayMapID: OldMapCatalog.goshikiFudo.id,
            name: "目黒不動（瀧泉寺）",
            summary: "五色不動のひとつ。目黒区下目黒にある、関東三大不動のひとつにも数えられる古刹。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6277, longitude: 139.7083)
        ),
        HistoricSite(
            id: "goshiki-mejiro",
            overlayMapID: OldMapCatalog.goshikiFudo.id,
            name: "目白不動（金乗院）",
            summary: "五色不動のひとつ。豊島区高田にある、目白の地名の由来となった不動尊。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7163, longitude: 139.7148)
        ),
        HistoricSite(
            id: "goshiki-meaka",
            overlayMapID: OldMapCatalog.goshikiFudo.id,
            name: "目赤不動（南谷寺）",
            summary: "五色不動のひとつ。文京区本駒込にある不動尊。もとは動坂にあったと伝わる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7262, longitude: 139.7530)
        ),
        HistoricSite(
            id: "goshiki-meao",
            overlayMapID: OldMapCatalog.goshikiFudo.id,
            name: "目青不動（教学院）",
            summary: "五色不動のひとつ。世田谷区太子堂、三軒茶屋近くにある不動尊。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6445, longitude: 139.6706)
        ),
        HistoricSite(
            id: "goshiki-meki",
            overlayMapID: OldMapCatalog.goshikiFudo.id,
            name: "目黄不動（永久寺）",
            summary: "五色不動のひとつ。台東区三ノ輪にある不動尊。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7275, longitude: 139.7885)
        ),

        // 松尾芭蕉ゆかりの地（深川〜千住）
        HistoricSite(
            id: "basho-fukagawa-an",
            overlayMapID: OldMapCatalog.bashoOkuNoHosomichi.id,
            name: "深川芭蕉庵跡",
            summary: "芭蕉が『おくのほそ道』へ旅立つまで暮らした庵の跡。隅田川のほとりにある。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.8022)
        ),
        HistoricSite(
            id: "basho-kinenkan",
            overlayMapID: OldMapCatalog.bashoOkuNoHosomichi.id,
            name: "江東区芭蕉記念館",
            summary: "芭蕉庵跡のそばに立つ、芭蕉の生涯と作品を紹介する記念館。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6809, longitude: 139.8014)
        ),
        HistoricSite(
            id: "basho-saian",
            overlayMapID: OldMapCatalog.bashoOkuNoHosomichi.id,
            name: "采茶庵跡",
            summary: "芭蕉が『おくのほそ道』の旅へ実際に船出したとされる庵の跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.7989)
        ),
        HistoricSite(
            id: "basho-senju-ohashi",
            overlayMapID: OldMapCatalog.bashoOkuNoHosomichi.id,
            name: "千住大橋",
            summary: "芭蕉が舟を降り、江戸を離れて奥州への旅を歩き始めた地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7461, longitude: 139.7986)
        ),
        HistoricSite(
            id: "basho-yatate-hajime",
            overlayMapID: OldMapCatalog.bashoOkuNoHosomichi.id,
            name: "矢立初めの地",
            summary: "「行く春や鳥啼き魚の目は泪」の句とともに、旅の第一歩を記した記念碑が立つ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7466, longitude: 139.7983)
        ),
        HistoricSite(
            id: "basho-susanoo-shrine",
            overlayMapID: OldMapCatalog.bashoOkuNoHosomichi.id,
            name: "素盞雄神社",
            summary: "千住にある古社。境内には松尾芭蕉の句碑「奥の細道矢立初めの碑」が立つ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7458, longitude: 139.7965)
        ),

        // 霞ヶ関・虎ノ門（大名屋敷と社寺）※「江戸城周辺（安政期）」に統合済み
        HistoricSite(
            id: "kasumigaseki-hibiya-park",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "日比谷公園",
            summary: "江戸時代は大名屋敷や陸軍練兵場だった地に、明治36年に開園した日本初の近代西洋式公園。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6740, longitude: 139.7565)
        ),
        HistoricSite(
            id: "kasumigaseki-atago-shrine",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "愛宕神社",
            summary: "江戸時代から防火の神様として信仰された、都心随一の高台にある神社。出世の石段でも知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6653, longitude: 139.7494)
        ),
        HistoricSite(
            id: "kasumigaseki-toranomon-kotohira",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "虎ノ門金刀比羅宮",
            summary: "万治3年（1660年）創建。丸亀藩の江戸藩邸内に、讃岐の金刀比羅宮を勧請したのが始まり。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6699, longitude: 139.7497)
        ),
        HistoricSite(
            id: "kasumigaseki-tameike",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "溜池跡",
            summary: "江戸城の外堀を兼ねた人工の溜め池があった場所。現在の溜池交差点にその名を残す。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6693, longitude: 139.7413)
        ),

        // 赤坂・紀尾井町（大名屋敷跡）
        HistoricSite(
            id: "akasaka-hikawa-shrine",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "赤坂氷川神社",
            summary: "徳川吉宗が創建した、赤坂の総鎮守。江戸時代の姿を伝える社殿が残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6739, longitude: 139.7362)
        ),
        HistoricSite(
            id: "akasaka-hie-shrine",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "日枝神社",
            summary: "徳川将軍家の産土神として篤く崇敬された、江戸三大祭のひとつ山王祭で知られる神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6733, longitude: 139.7392)
        ),
        HistoricSite(
            id: "kioicho-geihinkan",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "迎賓館赤坂離宮（紀州藩邸跡）",
            summary: "紀伊徳川家の中屋敷があった地。「紀尾井町」の「紀」はこの紀州藩に由来する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6797, longitude: 139.7327)
        ),
        HistoricSite(
            id: "kioicho-sophia-univ",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "上智大学（尾張藩邸跡）",
            summary: "尾張徳川家の中屋敷があった地。「紀尾井町」の「尾」はこの尾張藩に由来する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6857, longitude: 139.7305)
        ),
        HistoricSite(
            id: "kioicho-new-otani",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "ホテルニューオータニ（彦根藩井伊家邸跡）",
            summary: "彦根藩井伊家の中屋敷があった地。「紀尾井町」の「井」はこの井伊家に由来する。庭園に往時の面影が残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6788, longitude: 139.7343)
        ),

        // 東海道（日本橋〜品川宿）
        HistoricSite(
            id: "tokaido-nihonbashi",
            overlayMapID: OldMapCatalog.tokaido.id,
            name: "日本橋",
            summary: "五街道の起点。東海道はここから京の三条大橋まで続いていた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6835, longitude: 139.7742)
        ),
        HistoricSite(
            id: "tokaido-takanawa-okido",
            overlayMapID: OldMapCatalog.tokaido.id,
            name: "高輪大木戸跡",
            summary: "江戸の南の入口を示した木戸の跡。ここから先が正式な「江戸」の外だった。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6335, longitude: 139.7402)
        ),
        HistoricSite(
            id: "tokaido-sengakuji",
            overlayMapID: OldMapCatalog.tokaido.id,
            name: "泉岳寺",
            summary: "赤穂浪士（四十七士）の墓所として知られる、東海道沿いの寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6435, longitude: 139.7385)
        ),
        HistoricSite(
            id: "tokaido-shinagawa-juku",
            overlayMapID: OldMapCatalog.tokaido.id,
            name: "品川宿本陣跡",
            summary: "東海道最初の宿場・品川宿の本陣（大名などの宿泊所）があった地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6247, longitude: 139.7397)
        ),
        HistoricSite(
            id: "tokaido-suzugamori",
            overlayMapID: OldMapCatalog.tokaido.id,
            name: "鈴ヶ森刑場跡",
            summary: "江戸時代、東海道の入口に置かれた刑場の跡。街道を行き交う人々への見せしめの意味もあった。",
            coordinate: CLLocationCoordinate2D(latitude: 35.5865, longitude: 139.7377)
        ),

        // 中山道（日本橋〜板橋宿）
        HistoricSite(
            id: "nakasendo-nihonbashi",
            overlayMapID: OldMapCatalog.nakasendo.id,
            name: "日本橋",
            summary: "五街道の起点。中山道はここから内陸を経て京の三条大橋まで続いていた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6835, longitude: 139.7742)
        ),
        HistoricSite(
            id: "nakasendo-kanda-myojin",
            overlayMapID: OldMapCatalog.nakasendo.id,
            name: "神田明神",
            summary: "中山道が通っていた神田の総鎮守。多くの旅人が道中の無事を祈った。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7020, longitude: 139.7671)
        ),
        HistoricSite(
            id: "nakasendo-hongo-oiwake",
            overlayMapID: OldMapCatalog.nakasendo.id,
            name: "本郷追分",
            summary: "中山道と日光御成道（岩槻街道）が分岐した地点。「追分」の地名はこの分かれ道に由来する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7183, longitude: 139.7592)
        ),
        HistoricSite(
            id: "nakasendo-sugamo-koshinzuka",
            overlayMapID: OldMapCatalog.nakasendo.id,
            name: "巣鴨庚申塚",
            summary: "中山道沿いの庚申塚。旅人や地元の人々の信仰を集めた道中の目印。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7365, longitude: 139.7325)
        ),
        HistoricSite(
            id: "nakasendo-itabashi-juku",
            overlayMapID: OldMapCatalog.nakasendo.id,
            name: "板橋宿本陣跡",
            summary: "中山道最初の宿場・板橋宿の本陣があった地。石神井川に架かる板橋が地名の由来。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7513, longitude: 139.7093)
        ),

        // 九段下・千鳥ヶ淵（靖国神社周辺）※「江戸城周辺（安政期）」に統合済み
        HistoricSite(
            id: "kudanshita-yasukuni-shrine",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "靖国神社",
            summary: "明治2年（1869年）創建。国のために亡くなった人々を祀る神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6938, longitude: 139.7423)
        ),
        HistoricSite(
            id: "kudanshita-chidorigafuchi",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "千鳥ヶ淵",
            summary: "江戸城の外堀のひとつ。桜の名所としても知られる、水面が美しい濠。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6913, longitude: 139.7457)
        ),
        HistoricSite(
            id: "kudanshita-tayasumon",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "田安門",
            summary: "江戸城北の丸を守った門のひとつ。現存する江戸城の城門としては最古級とされる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6942, longitude: 139.7499)
        ),
        HistoricSite(
            id: "kudanshita-shimizumon",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "清水門",
            summary: "江戸城北の丸のもうひとつの門。枡形（ますがた）の形式が今も残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6912, longitude: 139.7508)
        ),

        // 麻布・六本木周辺 ※「赤坂・紀尾井町・六本木」に統合済み
        HistoricSite(
            id: "roppongi-hills-mori-garden",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "六本木ヒルズ（毛利庭園）",
            summary: "長州藩毛利家の下屋敷があった地。当時の庭園の一部が現在も毛利庭園として残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6604, longitude: 139.7292)
        ),
        HistoricSite(
            id: "roppongi-nogi-shrine",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "乃木神社",
            summary: "乃木希典・静子夫妻を祀る神社。乃木邸跡に隣接する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6667, longitude: 139.7268)
        ),
        HistoricSite(
            id: "roppongi-azabudai",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "麻布台（大名屋敷跡）",
            summary: "複数の大名屋敷が置かれていた高台。現在の麻布台ヒルズ周辺にあたる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6631, longitude: 139.7395)
        ),
        HistoricSite(
            id: "roppongi-azabujuban",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "麻布十番",
            summary: "江戸時代から続く商店街。かつての古川沿いの町人地で、今も昔ながらの賑わいが残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6558, longitude: 139.7350)
        ),
        HistoricSite(
            id: "roppongi-arisugawa-park",
            overlayMapID: OldMapCatalog.akasakaKioicho.id,
            name: "有栖川宮記念公園",
            summary: "盛岡藩南部家の下屋敷、後に有栖川宮家の御用地となった地。起伏に富んだ地形が名残を伝える。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6553, longitude: 139.7236)
        ),

        // 明治神宮・表参道・神宮外苑
        HistoricSite(
            id: "meijijingu-shrine",
            overlayMapID: OldMapCatalog.meijiJinguOmotesando.id,
            name: "明治神宮",
            summary: "明治天皇と昭憲皇太后を祀る神社。1920年（大正9年）創建。代々木の森は創建にあわせて全国から献木された人工林。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6764, longitude: 139.6993)
        ),
        HistoricSite(
            id: "meijijingu-harajuku-station",
            overlayMapID: OldMapCatalog.meijiJinguOmotesando.id,
            name: "原宿駅",
            summary: "明治神宮の最寄駅として1906年開業。この地図が描かれた1891年時点では、まだ原宿村ののどかな風景が広がっていた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6702, longitude: 139.7027)
        ),
        HistoricSite(
            id: "meijijingu-omotesando-hills",
            overlayMapID: OldMapCatalog.meijiJinguOmotesando.id,
            name: "表参道ヒルズ",
            summary: "明治神宮の参道として整備された表参道沿い。ケヤキ並木は神宮創建にあわせて植えられた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6672, longitude: 139.7106)
        ),
        HistoricSite(
            id: "meijijingu-gaien-gallery",
            overlayMapID: OldMapCatalog.meijiJinguOmotesando.id,
            name: "聖徳記念絵画館",
            summary: "明治天皇の事績を描いた絵画を収める、神宮外苑のシンボル的建物。1926年竣工。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6772, longitude: 139.7193)
        ),

        // 大山街道（赤坂〜二子玉川）
        HistoricSite(
            id: "oyamakaido-akasaka",
            overlayMapID: OldMapCatalog.oyamaKaido.id,
            name: "赤坂見附",
            summary: "大山街道（矢倉沢往還）の江戸側の起点付近。江戸城の外堀に設けられた見附（門）のひとつがあった。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6775, longitude: 139.7370)
        ),
        HistoricSite(
            id: "oyamakaido-aoyama",
            overlayMapID: OldMapCatalog.oyamaKaido.id,
            name: "青山（青山通り）",
            summary: "大山街道の道筋がそのまま現在の青山通り（国道246号）として残るエリア。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6725, longitude: 139.7256)
        ),
        HistoricSite(
            id: "oyamakaido-shibuya-dogenzaka",
            overlayMapID: OldMapCatalog.oyamaKaido.id,
            name: "渋谷・道玄坂",
            summary: "大山街道が渋谷の谷を上る坂道。旅人相手の茶屋が並んでいたとされる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6580, longitude: 139.6975)
        ),
        HistoricSite(
            id: "oyamakaido-sangenjaya",
            overlayMapID: OldMapCatalog.oyamaKaido.id,
            name: "三軒茶屋（大山道の追分）",
            summary: "大山道と登戸道（世田谷通り）が分岐した地点。3軒の茶屋があったことが地名の由来とされる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6438, longitude: 139.6708)
        ),
        HistoricSite(
            id: "oyamakaido-komazawa",
            overlayMapID: OldMapCatalog.oyamaKaido.id,
            name: "駒沢",
            summary: "大山街道沿いの村。現在の駒沢オリンピック公園周辺にあたる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6252, longitude: 139.6553)
        ),
        HistoricSite(
            id: "oyamakaido-youga",
            overlayMapID: OldMapCatalog.oyamaKaido.id,
            name: "用賀",
            summary: "大山街道の宿駅的な役割を担った村。旧道の道筋が今も一部残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6229, longitude: 139.6321)
        ),
        HistoricSite(
            id: "oyamakaido-futakotamagawa",
            overlayMapID: OldMapCatalog.oyamaKaido.id,
            name: "二子玉川（多摩川の渡し）",
            summary: "大山街道が多摩川を渡った地点。江戸時代は「二子の渡し」と呼ばれる渡し船が使われていた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6099, longitude: 139.6262)
        ),

        // 神楽坂・早稲田
        HistoricSite(
            id: "kws-hanazono-shrine",
            overlayMapID: OldMapCatalog.kagurazakaWasedaShinjuku.id,
            name: "花園神社",
            summary: "新宿の総鎮守として江戸時代から信仰を集める神社。酉の市でも知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6931, longitude: 139.7043)
        ),
        HistoricSite(
            id: "kws-waseda-okuma",
            overlayMapID: OldMapCatalog.kagurazakaWasedaShinjuku.id,
            name: "早稲田大学 大隈講堂",
            summary: "大隈重信が創設した早稲田大学の象徴的な講堂。周辺には学生街が広がる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7089, longitude: 139.7197)
        ),
        HistoricSite(
            id: "kws-anahachimangu",
            overlayMapID: OldMapCatalog.kagurazakaWasedaShinjuku.id,
            name: "穴八幡宮",
            summary: "早稲田の高台に鎮座する古社。江戸時代から金運・出世の御利益で知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7078, longitude: 139.7213)
        ),
        HistoricSite(
            id: "kws-kagurazaka-zenkokuji",
            overlayMapID: OldMapCatalog.kagurazakaWasedaShinjuku.id,
            name: "神楽坂・毘沙門天善國寺",
            summary: "江戸時代から続く花街・神楽坂のシンボル的な寺院。石畳の路地に今も花柳界の風情が残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7017, longitude: 139.7397)
        ),

        // 「君の名は。」聖地巡礼（新宿・四谷・原宿・渋谷）
        HistoricSite(
            id: "kiminona-suga-shrine",
            overlayMapID: OldMapCatalog.kiminonaSeichi.id,
            name: "須賀神社",
            summary: "参道の男坂石段が、映画のラストシーンの舞台として知られる四谷の神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6863, longitude: 139.7217)
        ),
        HistoricSite(
            id: "kiminona-yotsuya-station",
            overlayMapID: OldMapCatalog.kiminonaSeichi.id,
            name: "四ツ谷駅",
            summary: "須賀神社に近く、劇中の四谷周辺の風景に重なるターミナル駅。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6858, longitude: 139.7305)
        ),
        HistoricSite(
            id: "kiminona-docomo-tower",
            overlayMapID: OldMapCatalog.kiminonaSeichi.id,
            name: "ドコモタワー（NTTドコモ代々木ビル）",
            summary: "劇中の東京の空を象徴する超高層ビル。代々木・新宿一帯から見渡せる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6844, longitude: 139.7031)
        ),
        HistoricSite(
            id: "kiminona-busta-shinjuku",
            overlayMapID: OldMapCatalog.kiminonaSeichi.id,
            name: "バスタ新宿",
            summary: "新宿駅南口の高速バスターミナル。三葉が東京へ降り立つ場面のモデルとされる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6886, longitude: 139.7008)
        ),
        HistoricSite(
            id: "kiminona-cafe-la-boheme",
            overlayMapID: OldMapCatalog.kiminonaSeichi.id,
            name: "カフェ・ラ・ボエム（新宿御苑店）",
            summary: "瀧のアルバイト先のモデルとされる、新宿御苑そばのカフェ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6903, longitude: 139.7154)
        ),
        HistoricSite(
            id: "kiminona-shibuya-tsutaya",
            overlayMapID: OldMapCatalog.kiminonaSeichi.id,
            name: "SHIBUYA TSUTAYA",
            summary: "渋谷スクランブル交差点に面する複合施設。劇中の渋谷の雑踏シーンのモデル地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6597, longitude: 139.7016)
        ),
    ]

    static func site(withID id: String) -> HistoricSite? {
        all.first { $0.id == id }
    }

    /// 指定した古地図に属するチェックポイントだけを返す。
    /// `overlayMapID`が`nil`（古地図を表示していない）場合は空配列を返す。
    static func sites(forOverlayID overlayMapID: String?) -> [HistoricSite] {
        guard let overlayMapID else { return [] }
        return all.filter { $0.overlayMapID == overlayMapID }
    }
}
