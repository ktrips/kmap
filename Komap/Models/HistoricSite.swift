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
            id: "edo-castle-kitanomaru",
            overlayMapID: OldMapCatalog.edoCastle.id,
            name: "北の丸",
            summary: "江戸城の北を守った曲輪。現在は北の丸公園として整備されている。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6906, longitude: 139.7533)
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
        HistoricSite(
            id: "writers-koishikawa-garden",
            overlayMapID: OldMapCatalog.meijiWriters.id,
            name: "小石川植物園",
            summary: "文豪たちの作品にもたびたび登場する、東京大学の植物園。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7266, longitude: 139.7398)
        ),

        // 上野（寛永寺・不忍池周辺）
        HistoricSite(
            id: "ueno-kaneiji",
            overlayMapID: OldMapCatalog.ueno.id,
            name: "寛永寺根本中堂",
            summary: "徳川将軍家の菩提寺として栄えた、上野の中心的な寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7175, longitude: 139.7735)
        ),
        HistoricSite(
            id: "ueno-bentendo",
            overlayMapID: OldMapCatalog.ueno.id,
            name: "不忍池辯天堂",
            summary: "不忍池に浮かぶ中之島に建つ、弁財天を祀るお堂。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7139, longitude: 139.7717)
        ),
        HistoricSite(
            id: "ueno-toshogu",
            overlayMapID: OldMapCatalog.ueno.id,
            name: "上野東照宮",
            summary: "徳川家康を祀る、金色殿で知られる荘厳な東照宮。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7161, longitude: 139.7724)
        ),
        HistoricSite(
            id: "ueno-kiyomizu",
            overlayMapID: OldMapCatalog.ueno.id,
            name: "清水観音堂",
            summary: "京都の清水寺を模して建てられた、舞台造りのお堂。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7156, longitude: 139.7731)
        ),
        HistoricSite(
            id: "ueno-gojoten",
            overlayMapID: OldMapCatalog.ueno.id,
            name: "五条天神社",
            summary: "医薬の神様を祀る、上野の山に古くから鎮座する神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7150, longitude: 139.7728)
        ),

        // 日本橋（商人の町）
        HistoricSite(
            id: "nihonbashi-bridge",
            overlayMapID: OldMapCatalog.nihonbashi.id,
            name: "日本橋",
            summary: "五街道の起点として栄えた、江戸経済の中心地を象徴する橋。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6835, longitude: 139.7742)
        ),
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

        // 芝（増上寺周辺）
        HistoricSite(
            id: "shiba-zojoji",
            overlayMapID: OldMapCatalog.shiba.id,
            name: "増上寺大殿",
            summary: "徳川将軍家の菩提寺のひとつ。東京タワーを背にそびえる大殿。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6572, longitude: 139.7492)
        ),
        HistoricSite(
            id: "shiba-sangedatsumon",
            overlayMapID: OldMapCatalog.shiba.id,
            name: "三解脱門",
            summary: "増上寺の入口に建つ、江戸初期からの姿を残す重厚な門。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6579, longitude: 139.7488)
        ),
        HistoricSite(
            id: "shiba-toshogu",
            overlayMapID: OldMapCatalog.shiba.id,
            name: "芝東照宮",
            summary: "徳川家康を祀る、増上寺に隣接する東照宮。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6566, longitude: 139.7493)
        ),
        HistoricSite(
            id: "shiba-maruyama-kofun",
            overlayMapID: OldMapCatalog.shiba.id,
            name: "芝丸山古墳",
            summary: "都内有数の規模を誇る、芝公園内に残る前方後円墳。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6555, longitude: 139.7482)
        ),
        HistoricSite(
            id: "shiba-tokyo-tower",
            overlayMapID: OldMapCatalog.shiba.id,
            name: "東京タワー",
            summary: "増上寺のすぐそばにそびえる、東京のランドマーク。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6586, longitude: 139.7454)
        ),

        // 神田（神田明神周辺）
        HistoricSite(
            id: "kanda-myojin-checkpoint",
            overlayMapID: OldMapCatalog.kanda.id,
            name: "神田明神",
            summary: "江戸総鎮守として庶民に親しまれてきた神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7020, longitude: 139.7671)
        ),
        HistoricSite(
            id: "kanda-seido",
            overlayMapID: OldMapCatalog.kanda.id,
            name: "湯島聖堂",
            summary: "儒学の学問所として栄えた、孔子廟を祀る史跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7009, longitude: 139.7659)
        ),
        HistoricSite(
            id: "kanda-nikolai-do",
            overlayMapID: OldMapCatalog.kanda.id,
            name: "ニコライ堂",
            summary: "明治時代に建てられた、ビザンチン様式の大聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6976, longitude: 139.7644)
        ),
        HistoricSite(
            id: "kanda-jimbocho",
            overlayMapID: OldMapCatalog.kanda.id,
            name: "神保町古書店街",
            summary: "世界有数の規模を誇る、古書店が軒を連ねる街。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6958, longitude: 139.7573)
        ),
        HistoricSite(
            id: "kanda-shohei-bridge",
            overlayMapID: OldMapCatalog.kanda.id,
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

        // 霞ヶ関・虎ノ門（大名屋敷と社寺）
        HistoricSite(
            id: "kasumigaseki-sakuradamon",
            overlayMapID: OldMapCatalog.kasumigasekiToranomon.id,
            name: "桜田門",
            summary: "江戸城外桜田門。桜田門外の変の舞台としても知られ、霞ヶ関・虎ノ門エリアへの入口にあたる門。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6773, longitude: 139.7539)
        ),
        HistoricSite(
            id: "kasumigaseki-hibiya-park",
            overlayMapID: OldMapCatalog.kasumigasekiToranomon.id,
            name: "日比谷公園",
            summary: "江戸時代は大名屋敷や陸軍練兵場だった地に、明治36年に開園した日本初の近代西洋式公園。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6740, longitude: 139.7565)
        ),
        HistoricSite(
            id: "kasumigaseki-atago-shrine",
            overlayMapID: OldMapCatalog.kasumigasekiToranomon.id,
            name: "愛宕神社",
            summary: "江戸時代から防火の神様として信仰された、都心随一の高台にある神社。出世の石段でも知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6653, longitude: 139.7494)
        ),
        HistoricSite(
            id: "kasumigaseki-toranomon-kotohira",
            overlayMapID: OldMapCatalog.kasumigasekiToranomon.id,
            name: "虎ノ門金刀比羅宮",
            summary: "万治3年（1660年）創建。丸亀藩の江戸藩邸内に、讃岐の金刀比羅宮を勧請したのが始まり。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6699, longitude: 139.7497)
        ),
        HistoricSite(
            id: "kasumigaseki-tameike",
            overlayMapID: OldMapCatalog.kasumigasekiToranomon.id,
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
