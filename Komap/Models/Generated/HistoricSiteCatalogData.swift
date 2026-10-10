// このファイルは scripts/generate-catalog.mjs が catalog/historic_sites.json から生成したものです。直接編集しないでください。

import CoreLocation

extension HistoricSiteCatalog {
    /// 同梱の史跡チェックポイント（古地図ごとに、`catalog/historic_sites.json`の順。この順が地図上の番号になる）。
    static let all: [HistoricSite] = [
        // 江戸城周辺（安政期・1850年代）
        HistoricSite(
            id: "edo-castle-sakuradamon",
            overlayMapID: "edo-castle-1850s",
            name: "桜田門",
            summary: "江戸城外桜田門。桜田門外の変の舞台としても知られる、城の南西を守る門。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6773, longitude: 139.7539)
        ),
        HistoricSite(
            id: "edo-castle-wadakuramon",
            overlayMapID: "edo-castle-1850s",
            name: "和田倉門",
            summary: "大名行列も通った、江戸城内堀に面した門のひとつ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.7565)
        ),
        HistoricSite(
            id: "edo-castle-otemon",
            overlayMapID: "edo-castle-1850s",
            name: "大手門",
            summary: "江戸城の正面玄関にあたる、最も格式の高い門。",
            // 以前の座標は大手町のオフィス街内で、実際には入れない位置だったため、
            // 皇居東御苑の入口として実際に入場できる大手門の位置に修正した。
            coordinate: CLLocationCoordinate2D(latitude: 35.685893, longitude: 139.760429)
        ),
        // 浅草・浅草寺周辺（江戸時代）
        HistoricSite(
            id: "asakusa-kaminarimon",
            overlayMapID: "asakusa-edo",
            name: "雷門",
            summary: "浅草寺の総門。大提灯で知られる、浅草のシンボル的な門。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7107, longitude: 139.7964)
        ),
        HistoricSite(
            id: "asakusa-nakamise",
            overlayMapID: "asakusa-edo",
            name: "仲見世通り",
            summary: "雷門から宝蔵門まで続く、江戸時代から続く日本最古級の商店街。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7115, longitude: 139.7967)
        ),
        HistoricSite(
            id: "asakusa-sensoji",
            overlayMapID: "asakusa-edo",
            name: "浅草寺本堂",
            summary: "都内最古の寺院と伝わる、浅草の中心的な信仰の場。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7148, longitude: 139.7967)
        ),
        HistoricSite(
            id: "asakusa-gojunoto",
            overlayMapID: "asakusa-edo",
            name: "五重塔",
            summary: "浅草寺の境内にそびえる、江戸の町からも見えたという五重塔。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7143, longitude: 139.796)
        ),
        HistoricSite(
            id: "asakusa-hanayashiki",
            overlayMapID: "asakusa-edo",
            name: "花やしき",
            summary: "江戸末期に花園として開園した、日本最古級の遊園地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7157, longitude: 139.7943)
        ),
        // 明治の文豪の家（本郷・千駄木・谷中）
        HistoricSite(
            id: "writers-ogai",
            overlayMapID: "meiji-writers",
            name: "森鴎外の家（観潮楼跡）",
            summary: "森鴎外が晩年まで暮らした邸宅跡。現在は森鴎外記念館が建つ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7217, longitude: 139.7663)
        ),
        HistoricSite(
            id: "writers-soseki",
            overlayMapID: "meiji-writers",
            name: "夏目漱石旧居跡（猫の家）",
            summary: "『吾輩は猫である』を執筆した、漱石が暮らした借家の跡地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7215, longitude: 139.7654)
        ),
        HistoricSite(
            id: "writers-ichiyo",
            overlayMapID: "meiji-writers",
            name: "樋口一葉旧居跡",
            summary: "一葉が家族と暮らし、多くの作品を生み出した本郷菊坂の旧居跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7106, longitude: 139.7595)
        ),
        HistoricSite(
            id: "writers-takuboku",
            overlayMapID: "meiji-writers",
            name: "石川啄木の旧居",
            summary: "啄木が上京後に間借りした、本郷菊坂周辺の旧居跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7108, longitude: 139.7597)
        ),
        // 重複を避けてそちらだけ残している。
        HistoricSite(
            id: "ueno-toshogu",
            overlayMapID: "meiji-writers",
            name: "上野東照宮",
            summary: "徳川家康を祀る、金色殿で知られる荘厳な東照宮。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7161, longitude: 139.7724)
        ),
        // 日本橋（商人の町）
        HistoricSite(
            id: "nihonbashi-mitsukoshi",
            overlayMapID: "nihonbashi-edo",
            name: "三越日本橋本店",
            summary: "江戸時代の呉服店「越後屋」を起源とする老舗百貨店。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6852, longitude: 139.7734)
        ),
        HistoricSite(
            id: "nihonbashi-uoichiba",
            overlayMapID: "nihonbashi-edo",
            name: "日本橋魚市場発祥の地",
            summary: "江戸っ子の台所として栄えた、日本橋魚河岸の跡地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6837, longitude: 139.7738)
        ),
        HistoricSite(
            id: "nihonbashi-boj",
            overlayMapID: "nihonbashi-edo",
            name: "日本銀行本店",
            summary: "金座の跡地に建つ、日本の中央銀行本店。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6862, longitude: 139.7745)
        ),
        HistoricSite(
            id: "nihonbashi-edobashi",
            overlayMapID: "nihonbashi-edo",
            name: "江戸橋",
            summary: "日本橋川に架かる、江戸時代からの交通の要所。",
            coordinate: CLLocationCoordinate2D(latitude: 35.682, longitude: 139.7758)
        ),
        // 芝（増上寺周辺）※「東海道（日本橋・芝増上寺・品川）」に統合済み
        HistoricSite(
            id: "shiba-zojoji",
            overlayMapID: "tokaido-edo",
            name: "増上寺・芝東照宮",
            summary: "徳川将軍家の菩提寺・増上寺と、家康を祀る隣接の東照宮。東京タワーを背にそびえる大殿で知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6572, longitude: 139.7492)
        ),
        // 神田（神田明神周辺）※「日本橋・神田明神」に統合済み
        HistoricSite(
            id: "kanda-myojin-checkpoint",
            overlayMapID: "nihonbashi-edo",
            name: "神田明神",
            summary: "江戸総鎮守として庶民に親しまれてきた神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.702, longitude: 139.7671)
        ),
        HistoricSite(
            id: "kanda-seido",
            overlayMapID: "nihonbashi-edo",
            name: "湯島聖堂",
            summary: "儒学の学問所として栄えた、孔子廟を祀る史跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7009, longitude: 139.7659)
        ),
        HistoricSite(
            id: "kanda-nikolai-do",
            overlayMapID: "nihonbashi-edo",
            name: "ニコライ堂",
            summary: "明治時代に建てられた、ビザンチン様式の大聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6976, longitude: 139.7644)
        ),
        HistoricSite(
            id: "kanda-shohei-bridge",
            overlayMapID: "nihonbashi-edo",
            name: "昌平橋",
            summary: "神田川に架かる、湯島聖堂のそばの古くからの橋。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6989, longitude: 139.7659)
        ),
        // 谷中七福神（田端・西日暮里・谷中・上野公園）
        HistoricSite(
            id: "yanaka7-tokakuji",
            overlayMapID: "meiji-writers",
            name: "東覚寺（福禄寿）",
            summary: "谷中七福神の福禄寿を祀る、田端にある赤紙仁王で知られる寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7355, longitude: 139.7585)
        ),
        HistoricSite(
            id: "yanaka7-seiunji",
            overlayMapID: "meiji-writers",
            name: "青雲寺（恵比寿）",
            summary: "谷中七福神の恵比寿を祀る、西日暮里の花見寺のひとつ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7311, longitude: 139.766)
        ),
        HistoricSite(
            id: "yanaka7-shushoin",
            overlayMapID: "meiji-writers",
            name: "修性院（布袋尊）",
            summary: "谷中七福神の布袋尊を祀る、西日暮里の花見寺のひとつ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7301, longitude: 139.7661)
        ),
        HistoricSite(
            id: "yanaka7-choanji",
            overlayMapID: "meiji-writers",
            name: "長安寺（寿老人）",
            summary: "谷中七福神の寿老人を祀る、谷中霊園近くの寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7252, longitude: 139.7684)
        ),
        HistoricSite(
            id: "yanaka7-tennoji",
            overlayMapID: "meiji-writers",
            name: "天王寺（毘沙門天）",
            summary: "谷中七福神の毘沙門天を祀る、谷中霊園に隣接する古刹。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7267, longitude: 139.7712)
        ),
        HistoricSite(
            id: "yanaka7-gokokuin",
            overlayMapID: "meiji-writers",
            name: "護国院（大黒天）",
            summary: "谷中七福神の大黒天を祀る、上野公園内の寛永寺子院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7193, longitude: 139.7701)
        ),
        HistoricSite(
            id: "yanaka7-bentendo",
            overlayMapID: "meiji-writers",
            name: "不忍池辯天堂（弁才天）",
            summary: "谷中七福神の弁才天を祀る、不忍池に浮かぶお堂。江戸最古とされる七福神めぐりの終点。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7139, longitude: 139.7717)
        ),
        // 五色不動めぐり（目黒・目白・目赤・目青・目黄）
        HistoricSite(
            id: "goshiki-meguro",
            overlayMapID: "goshiki-fudo-meiji",
            name: "目黒不動（瀧泉寺）",
            summary: "五色不動のひとつ。目黒区下目黒にある、関東三大不動のひとつにも数えられる古刹。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6277, longitude: 139.7083)
        ),
        HistoricSite(
            id: "goshiki-mejiro",
            overlayMapID: "goshiki-fudo-meiji",
            name: "目白不動（金乗院）",
            summary: "五色不動のひとつ。豊島区高田にある、目白の地名の由来となった不動尊。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7163, longitude: 139.7148)
        ),
        HistoricSite(
            id: "goshiki-meaka",
            overlayMapID: "goshiki-fudo-meiji",
            name: "目赤不動（南谷寺）",
            summary: "五色不動のひとつ。文京区本駒込にある不動尊。もとは動坂にあったと伝わる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7262, longitude: 139.753)
        ),
        HistoricSite(
            id: "goshiki-meao",
            overlayMapID: "goshiki-fudo-meiji",
            name: "目青不動（教学院）",
            summary: "五色不動のひとつ。世田谷区太子堂、三軒茶屋近くにある不動尊。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6445, longitude: 139.6706)
        ),
        HistoricSite(
            id: "goshiki-meki",
            overlayMapID: "goshiki-fudo-meiji",
            name: "目黄不動（永久寺）",
            summary: "五色不動のひとつ。台東区三ノ輪にある不動尊。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7275, longitude: 139.7885)
        ),
        // 松尾芭蕉ゆかりの地（深川〜千住）
        HistoricSite(
            id: "basho-fukagawa-an",
            overlayMapID: "basho-oku-no-hosomichi-meiji",
            name: "深川芭蕉庵跡",
            summary: "芭蕉が『おくのほそ道』へ旅立つまで暮らした庵の跡。隅田川のほとりにある。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.8022)
        ),
        HistoricSite(
            id: "basho-kinenkan",
            overlayMapID: "basho-oku-no-hosomichi-meiji",
            name: "江東区芭蕉記念館",
            summary: "芭蕉庵跡のそばに立つ、芭蕉の生涯と作品を紹介する記念館。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6809, longitude: 139.8014)
        ),
        HistoricSite(
            id: "basho-saian",
            overlayMapID: "basho-oku-no-hosomichi-meiji",
            name: "采茶庵跡",
            summary: "芭蕉が『おくのほそ道』の旅へ実際に船出したとされる庵の跡。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.7989)
        ),
        HistoricSite(
            id: "basho-senju-ohashi",
            overlayMapID: "basho-oku-no-hosomichi-meiji",
            name: "千住大橋",
            summary: "芭蕉が舟を降り、江戸を離れて奥州への旅を歩き始めた地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7461, longitude: 139.7986)
        ),
        HistoricSite(
            id: "basho-yatate-hajime",
            overlayMapID: "basho-oku-no-hosomichi-meiji",
            name: "矢立初めの地",
            summary: "「行く春や鳥啼き魚の目は泪」の句とともに、旅の第一歩を記した記念碑が立つ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7466, longitude: 139.7983)
        ),
        HistoricSite(
            id: "basho-susanoo-shrine",
            overlayMapID: "basho-oku-no-hosomichi-meiji",
            name: "素盞雄神社",
            summary: "千住にある古社。境内には松尾芭蕉の句碑「奥の細道矢立初めの碑」が立つ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7458, longitude: 139.7965)
        ),
        // 霞ヶ関・虎ノ門（大名屋敷と社寺）※「江戸城周辺（安政期）」に統合済み
        HistoricSite(
            id: "kasumigaseki-hibiya-park",
            overlayMapID: "edo-castle-1850s",
            name: "日比谷公園",
            summary: "江戸時代は大名屋敷や陸軍練兵場だった地に、明治36年に開園した日本初の近代西洋式公園。",
            coordinate: CLLocationCoordinate2D(latitude: 35.674, longitude: 139.7565)
        ),
        HistoricSite(
            id: "kasumigaseki-atago-shrine",
            overlayMapID: "edo-castle-1850s",
            name: "愛宕神社",
            summary: "江戸時代から防火の神様として信仰された、都心随一の高台にある神社。出世の石段でも知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6653, longitude: 139.7494)
        ),
        HistoricSite(
            id: "kasumigaseki-toranomon-kotohira",
            overlayMapID: "edo-castle-1850s",
            name: "虎ノ門金刀比羅宮",
            summary: "万治3年（1660年）創建。丸亀藩の江戸藩邸内に、讃岐の金刀比羅宮を勧請したのが始まり。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6699, longitude: 139.7497)
        ),
        HistoricSite(
            id: "kasumigaseki-tameike",
            overlayMapID: "edo-castle-1850s",
            name: "溜池跡",
            summary: "江戸城の外堀を兼ねた人工の溜め池があった場所。現在の溜池交差点にその名を残す。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6693, longitude: 139.7413)
        ),
        // 赤坂・紀尾井町（大名屋敷跡）
        HistoricSite(
            id: "akasaka-hikawa-shrine",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "赤坂氷川神社",
            summary: "徳川吉宗が創建した、赤坂の総鎮守。江戸時代の姿を伝える社殿が残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6739, longitude: 139.7362)
        ),
        HistoricSite(
            id: "kioicho-geihinkan",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "迎賓館赤坂離宮（紀州藩邸跡）",
            summary: "紀伊徳川家の中屋敷があった地。「紀尾井町」の「紀」はこの紀州藩に由来する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6797, longitude: 139.7327)
        ),
        HistoricSite(
            id: "kioicho-sophia-univ",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "上智大学（尾張藩邸跡）",
            summary: "尾張徳川家の中屋敷があった地。「紀尾井町」の「尾」はこの尾張藩に由来する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6857, longitude: 139.7305)
        ),
        HistoricSite(
            id: "kioicho-new-otani",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "ホテルニューオータニ（彦根藩井伊家邸跡）",
            summary: "彦根藩井伊家の中屋敷があった地。「紀尾井町」の「井」はこの井伊家に由来する。庭園に往時の面影が残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6788, longitude: 139.7343)
        ),
        // 東海道（日本橋〜品川宿）
        HistoricSite(
            id: "tokaido-nihonbashi",
            overlayMapID: "tokaido-edo",
            name: "日本橋",
            summary: "五街道の起点。東海道はここから京の三条大橋まで続いていた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6835, longitude: 139.7742)
        ),
        HistoricSite(
            id: "tokaido-takanawa-okido",
            overlayMapID: "tokaido-edo",
            name: "高輪大木戸跡",
            summary: "江戸の南の入口を示した木戸の跡。ここから先が正式な「江戸」の外だった。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6335, longitude: 139.7402)
        ),
        HistoricSite(
            id: "tokaido-sengakuji",
            overlayMapID: "tokaido-edo",
            name: "泉岳寺",
            summary: "赤穂浪士（四十七士）の墓所として知られる、東海道沿いの寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6435, longitude: 139.7385)
        ),
        HistoricSite(
            id: "tokaido-shinagawa-juku",
            overlayMapID: "tokaido-edo",
            name: "品川宿本陣跡",
            summary: "東海道最初の宿場・品川宿の本陣（大名などの宿泊所）があった地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6247, longitude: 139.7397)
        ),
        HistoricSite(
            id: "tokaido-suzugamori",
            overlayMapID: "tokaido-edo",
            name: "鈴ヶ森刑場跡",
            summary: "江戸時代、東海道の入口に置かれた刑場の跡。街道を行き交う人々への見せしめの意味もあった。",
            coordinate: CLLocationCoordinate2D(latitude: 35.5865, longitude: 139.7377)
        ),
        // 中山道（日本橋〜板橋宿）
        HistoricSite(
            id: "nakasendo-nihonbashi",
            overlayMapID: "nakasendo-edo",
            name: "日本橋",
            summary: "五街道の起点。中山道はここから内陸を経て京の三条大橋まで続いていた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6835, longitude: 139.7742)
        ),
        HistoricSite(
            id: "nakasendo-kanda-myojin",
            overlayMapID: "nakasendo-edo",
            name: "神田明神",
            summary: "中山道が通っていた神田の総鎮守。多くの旅人が道中の無事を祈った。",
            coordinate: CLLocationCoordinate2D(latitude: 35.702, longitude: 139.7671)
        ),
        HistoricSite(
            id: "nakasendo-hongo-oiwake",
            overlayMapID: "nakasendo-edo",
            name: "本郷追分",
            summary: "中山道と日光御成道（岩槻街道）が分岐した地点。「追分」の地名はこの分かれ道に由来する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7183, longitude: 139.7592)
        ),
        HistoricSite(
            id: "nakasendo-sugamo-koshinzuka",
            overlayMapID: "nakasendo-edo",
            name: "巣鴨庚申塚",
            summary: "中山道沿いの庚申塚。旅人や地元の人々の信仰を集めた道中の目印。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7365, longitude: 139.7325)
        ),
        HistoricSite(
            id: "nakasendo-itabashi-juku",
            overlayMapID: "nakasendo-edo",
            name: "板橋宿本陣跡",
            summary: "中山道最初の宿場・板橋宿の本陣があった地。石神井川に架かる板橋が地名の由来。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7513, longitude: 139.7093)
        ),
        // 九段下・千鳥ヶ淵（靖国神社周辺）※「江戸城周辺（安政期）」に統合済み
        HistoricSite(
            id: "kudanshita-yasukuni-shrine",
            overlayMapID: "edo-castle-1850s",
            name: "靖国神社",
            summary: "明治2年（1869年）創建。国のために亡くなった人々を祀る神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6938, longitude: 139.7423)
        ),
        HistoricSite(
            id: "kudanshita-chidorigafuchi",
            overlayMapID: "edo-castle-1850s",
            name: "千鳥ヶ淵",
            summary: "江戸城の外堀のひとつ。桜の名所としても知られる、水面が美しい濠。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6913, longitude: 139.7457)
        ),
        HistoricSite(
            id: "kudanshita-shimizumon",
            overlayMapID: "edo-castle-1850s",
            name: "清水門",
            summary: "江戸城北の丸のもうひとつの門。枡形（ますがた）の形式が今も残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6912, longitude: 139.7508)
        ),
        // 麻布・六本木周辺 ※「赤坂・紀尾井町・六本木」に統合済み
        HistoricSite(
            id: "roppongi-hills-mori-garden",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "六本木ヒルズ（毛利庭園）",
            summary: "長州藩毛利家の下屋敷があった地。当時の庭園の一部が現在も毛利庭園として残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6604, longitude: 139.7292)
        ),
        HistoricSite(
            id: "roppongi-nogi-shrine",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "乃木神社",
            summary: "乃木希典・静子夫妻を祀る神社。乃木邸跡に隣接する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6667, longitude: 139.7268)
        ),
        HistoricSite(
            id: "roppongi-azabudai",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "麻布台（大名屋敷跡）",
            summary: "複数の大名屋敷が置かれていた高台。現在の麻布台ヒルズ周辺にあたる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6631, longitude: 139.7395)
        ),
        HistoricSite(
            id: "roppongi-azabujuban",
            overlayMapID: "akasaka-kioicho-meiji",
            name: "麻布十番",
            summary: "江戸時代から続く商店街。かつての古川沿いの町人地で、今も昔ながらの賑わいが残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6558, longitude: 139.735)
        ),
        // 大山街道（赤坂〜明治神宮〜二子）
        HistoricSite(
            id: "oyamakaido-akasaka",
            overlayMapID: "oyama-kaido",
            name: "赤坂見附",
            summary: "大山街道（矢倉沢往還）の江戸側の起点付近。江戸城の外堀に設けられた見附（門）のひとつがあった。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6775, longitude: 139.737)
        ),
        // 御朱印チェックポイントとして大山街道へ移動した。
        HistoricSite(
            id: "meijijingu-shrine",
            overlayMapID: "oyama-kaido",
            name: "明治神宮",
            summary: "明治天皇と昭憲皇太后を祀る神社。1920年（大正9年）創建。代々木の森は創建にあわせて全国から献木された人工林。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6764, longitude: 139.6993)
        ),
        HistoricSite(
            id: "meijijingu-gaien-gallery",
            overlayMapID: "oyama-kaido",
            name: "聖徳記念絵画館",
            summary: "明治天皇の事績を描いた絵画を収める、神宮外苑のシンボル的建物。1926年竣工。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6772, longitude: 139.7193)
        ),
        HistoricSite(
            id: "oyamakaido-shibuya-dogenzaka",
            overlayMapID: "oyama-kaido",
            name: "渋谷・道玄坂",
            summary: "大山街道が渋谷の谷を上る坂道。旅人相手の茶屋が並んでいたとされる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.658, longitude: 139.6975)
        ),
        HistoricSite(
            id: "oyamakaido-sangenjaya",
            overlayMapID: "oyama-kaido",
            name: "三軒茶屋（大山道の追分）",
            summary: "大山道と登戸道（世田谷通り）が分岐した地点。3軒の茶屋があったことが地名の由来とされる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6438, longitude: 139.6708)
        ),
        HistoricSite(
            id: "oyamakaido-komazawa",
            overlayMapID: "oyama-kaido",
            name: "駒沢",
            summary: "大山街道沿いの村。現在の駒沢オリンピック公園周辺にあたる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6252, longitude: 139.6553)
        ),
        HistoricSite(
            id: "oyamakaido-futakotamagawa",
            overlayMapID: "oyama-kaido",
            name: "二子玉川（多摩川の渡し）",
            summary: "大山街道が多摩川を渡った地点。江戸時代は「二子の渡し」と呼ばれる渡し船が使われていた。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6099, longitude: 139.6262)
        ),
        // 銀座・歌舞伎座
        HistoricSite(
            id: "ginza-brick-town",
            overlayMapID: "ginza-kabukiza",
            name: "銀座煉瓦街跡",
            summary: "明治初期の大火の後、不燃化のため築かれた西洋風の煉瓦街。銀座通り沿いに洋風建築が並んだ文明開化の象徴。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6741, longitude: 139.7712)
        ),
        HistoricSite(
            id: "ginza-kabukiza-theater",
            overlayMapID: "ginza-kabukiza",
            name: "歌舞伎座",
            summary: "1889年（明治22年）開場の歌舞伎の殿堂。破風屋根と定式幕が特徴的な、銀座を代表する劇場建築。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6693, longitude: 139.7663)
        ),
        HistoricSite(
            id: "ginza-4chome-crossing",
            overlayMapID: "ginza-kabukiza",
            name: "銀座四丁目交差点",
            summary: "和光の時計塔で知られる銀座のシンボル的な交差点。中央通りと晴海通りが交わる、銀座随一の賑わいの中心地。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6717, longitude: 139.766)
        ),
        HistoricSite(
            id: "ginza-willow-monument",
            overlayMapID: "ginza-kabukiza",
            name: "銀座柳の碑",
            summary: "「東京行進曲」にも歌われた銀座の柳並木を今に伝える記念碑。かつて銀座通りの舗道を彩った柳のシンボル。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6693, longitude: 139.7607)
        ),
        HistoricSite(
            id: "ginza-old-shimbashi-station",
            overlayMapID: "ginza-kabukiza",
            name: "旧新橋停車場跡",
            summary: "1872年（明治5年）、日本初の鉄道が新橋〜横浜間に開業した際の起点駅跡。現在は駅舎が復元されている。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6658, longitude: 139.7616)
        ),
        HistoricSite(
            id: "ginza-hamarikyu-gardens",
            overlayMapID: "ginza-kabukiza",
            name: "浜離宮恩賜庭園",
            summary: "徳川将軍家の別邸として造られた潮入りの回遊式庭園。海水を引き込む池と、高層ビルを望む景観が同居する。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6597, longitude: 139.7636)
        ),
        HistoricSite(
            id: "ginza-daimon",
            overlayMapID: "ginza-kabukiza",
            name: "大門",
            summary: "増上寺の総門として建てられた大きな門に由来する地名。現在も交差点や駅名にその名を残す。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6564, longitude: 139.7566)
        ),
        // 「君の名は。」聖地巡礼（新宿・四谷・原宿・渋谷）
        HistoricSite(
            id: "kiminona-suga-shrine",
            overlayMapID: "kiminona-seichi",
            name: "須賀神社",
            summary: "参道の男坂石段が、映画のラストシーンの舞台として知られる四谷の神社。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6863, longitude: 139.7217)
        ),
        HistoricSite(
            id: "kiminona-yotsuya-station",
            overlayMapID: "kiminona-seichi",
            name: "四ツ谷駅",
            summary: "須賀神社に近く、劇中の四谷周辺の風景に重なるターミナル駅。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6858, longitude: 139.7305)
        ),
        HistoricSite(
            id: "kiminona-docomo-tower",
            overlayMapID: "kiminona-seichi",
            name: "ドコモタワー（NTTドコモ代々木ビル）",
            summary: "劇中の東京の空を象徴する超高層ビル。代々木・新宿一帯から見渡せる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6844, longitude: 139.7031)
        ),
        HistoricSite(
            id: "kiminona-cafe-la-boheme",
            overlayMapID: "kiminona-seichi",
            name: "カフェ・ラ・ボエム（新宿御苑店）",
            summary: "瀧のアルバイト先のモデルとされる、新宿御苑そばのカフェ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6903, longitude: 139.7154)
        ),
        // 御朱印チェックポイントとして君の名は聖地巡礼へ移動した。
        HistoricSite(
            id: "kws-hanazono-shrine",
            overlayMapID: "kiminona-seichi",
            name: "花園神社",
            summary: "新宿の総鎮守として江戸時代から信仰を集める神社。酉の市でも知られる。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6931, longitude: 139.7043)
        ),
        HistoricSite(
            id: "kws-kagurazaka-zenkokuji",
            overlayMapID: "kiminona-seichi",
            name: "神楽坂・毘沙門天善國寺",
            summary: "江戸時代から続く花街・神楽坂のシンボル的な寺院。石畳の路地に今も花柳界の風情が残る。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7017, longitude: 139.7397)
        ),
        // ジブリ映画の聖地巡り（東京都内）
        HistoricSite(
            id: "ghibli-museum-mitaka",
            overlayMapID: "ghibli-seichi",
            name: "三鷹の森ジブリ美術館",
            summary: "スタジオジブリが手がけた、映画の世界観をそのまま体感できる美術館。井の頭恩賜公園の南側にある。",
            coordinate: CLLocationCoordinate2D(latitude: 35.696, longitude: 139.5704)
        ),
        HistoricSite(
            id: "ghibli-musashino-park",
            overlayMapID: "ghibli-seichi",
            name: "武蔵野公園（小金井）",
            summary: "野川沿いに広がる自然豊かな公園。スタジオジブリのアトリエ（小金井市）にほど近い。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6998, longitude: 139.521)
        ),
        HistoricSite(
            id: "ghibli-shirahige-cream-puff",
            overlayMapID: "ghibli-seichi",
            name: "白髭のシュークリーム（世田谷代田）",
            summary: "トトロの形をした大きなシュークリームで知られる、ジブリファンに人気の菓子店。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6636, longitude: 139.6634)
        ),
        HistoricSite(
            id: "ghibli-shinjuku-gyoen",
            overlayMapID: "ghibli-seichi",
            name: "新宿御苑",
            summary: "都心にありながら緑豊かな庭園が広がる、ジブリ作品の風景を思わせる憩いの場。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6852, longitude: 139.71)
        ),
        HistoricSite(
            id: "ghibli-edo-tokyo-open-air-museum",
            overlayMapID: "ghibli-seichi",
            name: "江戸東京たてもの園",
            summary: "移築復元された昭和期の建物群。「千と千尋の神隠し」の油屋の参考になった地としてスタジオジブリも認めている。",
            coordinate: CLLocationCoordinate2D(latitude: 35.7168, longitude: 139.5083)
        ),
        HistoricSite(
            id: "ghibli-seiseki-sakuragaoka",
            overlayMapID: "ghibli-seichi",
            name: "聖蹟桜ヶ丘駅前",
            summary: "「耳をすませば」の舞台。夕暮れ時の「耳丘」からの眺めは、物語のクライマックスと同じ景色。",
            coordinate: CLLocationCoordinate2D(latitude: 35.639, longitude: 139.4487)
        ),
        HistoricSite(
            id: "ghibli-shiodome-clock",
            overlayMapID: "ghibli-seichi",
            name: "日テレ大時計",
            summary: "日本テレビタワー2階に設置された、宮崎駿監督デザインのからくり時計。1日に数回、仕掛けが動き出す。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6607, longitude: 139.7597)
        ),
        // 東京トイレット（Perfect Days、渋谷区「THE TOKYO TOILET」）
        HistoricSite(
            id: "tokyo-toilet-ebisu-east-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "タコ公園のイカトイレ（恵比寿東公園）",
            summary: "赤いタコの滑り台で知られる「タコ公園」に立つ、槇文彦デザインの真っ白な「イカ」の形をしたトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6481754, longitude: 139.7112021)
        ),
        HistoricSite(
            id: "tokyo-toilet-nabeshima-shoto-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "森のコミチ（鍋島松濤公園）",
            summary: "緑豊かな鍋島松濤公園に溶け込む、隈研吾デザインの木漏れ日のようなトイレ「森のコミチ」。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6596047, longitude: 139.6915526)
        ),
        HistoricSite(
            id: "tokyo-toilet-yoyogi-fukamachi-mini-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "ザ・トウメイ・トイレット（代々木深町小公園）",
            summary: "坂茂デザイン。普段は透明なガラスの壁が、鍵をかけると不透明に変わる話題のトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6693949, longitude: 139.6906937)
        ),
        HistoricSite(
            id: "tokyo-toilet-yoyogi-hachiman",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "スリーマッシュルーム（代々木八幡）",
            summary: "伊東豊雄デザイン。代々木八幡の森からきのこが3本生えてきたような、可愛らしい3棟のトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6714521, longitude: 139.688015)
        ),
        HistoricSite(
            id: "tokyo-toilet-nishihara-itchome-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "アンドン・トイレット（西原一丁目公園）",
            summary: "坂倉竹之助デザイン。夜になると行灯のようにやわらかく光り、公園を優しく照らすトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6776468, longitude: 139.6796179)
        ),
        HistoricSite(
            id: "tokyo-toilet-jingu-dori-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "あまやどり（神宮通公園）",
            summary: "小林純子デザイン。大きな屋根が特徴的な、雨宿りできる東屋のようなトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6641929, longitude: 139.7020557)
        ),
        HistoricSite(
            id: "tokyo-toilet-ebisu-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "恵比寿公園トイレ",
            summary: "片山正通デザイン。通称「ロケット公園」に立つ、ロケットのような塔を持つユニークなトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6469527, longitude: 139.7069729)
        ),
        HistoricSite(
            id: "tokyo-toilet-higashi-sanchome",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "トライアングル（東三丁目）",
            summary: "田村奈穂デザイン。JR恵比寿駅の線路沿いに立つ、三角形のシルエットが目を引くトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6489871, longitude: 139.7091291)
        ),
        HistoricSite(
            id: "tokyo-toilet-jingumae",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "ザ・ハウス（神宮前）",
            summary: "NIGO®デザイン。原宿の路地に佇む、昔ながらの民家のような佇まいのトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6708, longitude: 139.7069)
        ),
        HistoricSite(
            id: "tokyo-toilet-ebisu-station-west-exit",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "ホワイト（恵比寿駅西口）",
            summary: "佐藤可士和デザイン。白いアルミルーバーに包まれた、清潔感あふれる箱のようなトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6473, longitude: 139.7095)
        ),
        HistoricSite(
            id: "tokyo-toilet-nanago-dori-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "ハイ・トイレット（七号通り公園）",
            summary: "佐藤カズオデザイン。声で「Hi」と話しかけると鍵が開く、手を使わないハイテクなトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6752, longitude: 139.6866)
        ),
        HistoricSite(
            id: "tokyo-toilet-sasazuka-greenway",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "まちのあかりのトイレ（笹塚緑道）",
            summary: "後藤達也（東京大学DLXデザインラボ）デザイン。夜には温かい灯りが緑道を照らす、街の明かりのようなトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.673372, longitude: 139.6667556)
        ),
        HistoricSite(
            id: "tokyo-toilet-hatagaya",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "ウィズ・トイレット（幡ヶ谷）",
            summary: "槇文彦デザイン。京王線幡ヶ谷〜笹塚間に立つ、中央の広場を囲むように個室が並ぶトイレ。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6798841, longitude: 139.6735301)
        ),
        HistoricSite(
            id: "tokyo-toilet-hiroo-higashi-park",
            overlayMapID: "tokyo-toilet-perfect-days",
            name: "モニュメンタム（広尾東公園）",
            summary: "マーク・ニューソンデザイン。公園に置かれた彫刻のようなモニュメントが、近づくとトイレだとわかる仕掛け。",
            coordinate: CLLocationCoordinate2D(latitude: 35.6516, longitude: 139.7213)
        ),
        // 実際のバッジ描画は`CrestBadgeCatalog.badge(for:)`（IDで引く）を参照。
        HistoricSite(
            id: "amsterdam-dam",
            overlayMapID: "amsterdam-medieval",
            name: "ダム広場・新教会",
            summary: "街の全ての道と運河がここから始まる、アムステルダムの心臓部。紋章は金の王冠。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3731, longitude: 4.8926)
        ),
        HistoricSite(
            id: "amsterdam-waag",
            overlayMapID: "amsterdam-medieval",
            name: "ヴァーグ（ニューマルクト旧計量所）",
            summary: "かつて商人が品を計った旧市門。紋章は公正な取引を見守る天秤。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3724, longitude: 4.901)
        ),
        HistoricSite(
            id: "amsterdam-begijnhof",
            overlayMapID: "amsterdam-medieval",
            name: "ベイナホフ",
            summary: "喧騒の街にひっそり佇む、祈りと静けさの中庭。紋章は銀の百合。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3699, longitude: 4.8907)
        ),
        HistoricSite(
            id: "amsterdam-montelbaanstoren",
            overlayMapID: "amsterdam-medieval",
            name: "モンテルバーンス塔",
            summary: "ウーデスハンス運河を見張り続けてきた塔。紋章は銀の塔。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3713, longitude: 4.9037)
        ),
        HistoricSite(
            id: "amsterdam-voc-harbor",
            overlayMapID: "amsterdam-medieval",
            name: "IJ港・VOC造船所",
            summary: "世界へ漕ぎ出した船団の記憶が残る港。紋章は波間に浮かぶ金の帆船。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3735, longitude: 4.9127)
        ),
        HistoricSite(
            id: "amsterdam-westerkerk",
            overlayMapID: "amsterdam-medieval",
            name: "西教会（ヴェステルケルク）",
            summary: "黄金時代に建てられた街いちばんの高い塔。頂には皇帝から授かった王冠を戴き、アンネ・フランクの家もすぐそば。紋章は青地に金の王冠。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3745, longitude: 4.884)
        ),
        HistoricSite(
            id: "amsterdam-munttoren",
            overlayMapID: "amsterdam-medieval",
            name: "ムント塔",
            summary: "中世の城門の名残りで、戦乱の時代に貨幣を鋳造したことから「貨幣の塔」と呼ばれる。紋章は赤地に金の時計。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3671, longitude: 4.8932)
        ),
        HistoricSite(
            id: "amsterdam-oude-kerk",
            overlayMapID: "amsterdam-medieval",
            name: "旧教会（アウデ・ケルク）",
            summary: "13世紀に始まる街最古の教会。船乗りたちの祈りを受け止めてきた鐘楼がそびえる。紋章は黒地に金の鐘。",
            coordinate: CLLocationCoordinate2D(latitude: 52.3744, longitude: 4.8981)
        ),
        // Europe — ヘルシンキ旧市街（帝政期）
        HistoricSite(
            id: "helsinki-senate-square",
            overlayMapID: "helsinki-old-town",
            name: "元老院広場・トゥオミオ教会",
            summary: "白亜のドームが街を見下ろす新古典様式の中心広場。紋章は白い聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9522)
        ),
        HistoricSite(
            id: "helsinki-suomenlinna",
            overlayMapID: "helsinki-old-town",
            name: "スオメンリンナ（海上要塞）",
            summary: "群島に築かれた星形要塞。紋章は金の星形要塞。",
            coordinate: CLLocationCoordinate2D(latitude: 60.1454, longitude: 24.988)
        ),
        HistoricSite(
            id: "helsinki-kauppatori",
            overlayMapID: "helsinki-old-town",
            name: "カウッパトリ（港の市場広場）",
            summary: "漁船とニシンの匂いが漂う港町の胃袋。紋章は銀地に青い魚。",
            coordinate: CLLocationCoordinate2D(latitude: 60.1677, longitude: 24.9535)
        ),
        HistoricSite(
            id: "helsinki-uspenski",
            overlayMapID: "helsinki-old-town",
            name: "ウスペンスキー大聖堂",
            summary: "赤レンガの丘に輝く金のタマネギ屋根の正教会。紋章は金の円屋根と十字架。",
            coordinate: CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9563)
        ),
        HistoricSite(
            id: "helsinki-vanhakaupunki",
            overlayMapID: "helsinki-old-town",
            name: "ヴァンハカウプンキ（最初の入植地）",
            summary: "1550年、川の畔に街が生まれた場所。紋章は緑地に金の麦束。",
            coordinate: CLLocationCoordinate2D(latitude: 60.2197, longitude: 24.9646)
        ),
        HistoricSite(
            id: "helsinki-railway-station",
            overlayMapID: "helsinki-old-town",
            name: "ヘルシンキ中央駅",
            summary: "エリエル・サーリネン設計、ナショナル・ロマンティシズムを代表する花崗岩の駅舎。ランプを抱く石の巨人が出迎える。紋章は緑地に金の機関車。",
            coordinate: CLLocationCoordinate2D(latitude: 60.1715, longitude: 24.9406)
        ),
        HistoricSite(
            id: "helsinki-temppeliaukio",
            overlayMapID: "helsinki-old-town",
            name: "テンペリアウキオ教会（岩の教会）",
            summary: "岩盤をくり抜いてつくられた教会。銅のドームの下、むき出しの岩肌に光が差し込む。紋章は黒地に銀の岩山。",
            coordinate: CLLocationCoordinate2D(latitude: 60.173, longitude: 24.9252)
        ),
        HistoricSite(
            id: "helsinki-sibelius",
            overlayMapID: "helsinki-old-town",
            name: "シベリウス・モニュメント",
            summary: "交響詩『フィンランディア』の作曲家をたたえる、600本の鋼管がパイプオルガンのように連なる記念碑。紋章は青地に銀の音符。",
            coordinate: CLLocationCoordinate2D(latitude: 60.182, longitude: 24.9134)
        ),
        // Europe — ストックホルム旧市街（ガムラスタン）
        HistoricSite(
            id: "stockholm-storkyrkan",
            overlayMapID: "stockholm-old-town",
            name: "ストールシルカン（大聖堂）",
            summary: "ガムラスタンの中心に鐘の音を響かせる、島の心臓。紋章は金の鐘楼。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3258, longitude: 18.0717)
        ),
        HistoricSite(
            id: "stockholm-riddarholmen",
            overlayMapID: "stockholm-old-town",
            name: "リッダーホルメン（王家墓所の島）",
            summary: "幾多の尖塔がそびえる、歴代の王が眠る島。紋章は銀の尖塔群。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3251, longitude: 18.0672)
        ),
        HistoricSite(
            id: "stockholm-royal-palace",
            overlayMapID: "stockholm-old-town",
            name: "クングリガ・スロッテット（王宮）",
            summary: "北の王国を象徴する王宮。紋章は青地に三つの金の王冠（トレ・クロノール）。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3268, longitude: 18.0717)
        ),
        HistoricSite(
            id: "stockholm-skeppsholmen",
            overlayMapID: "stockholm-old-town",
            name: "シェップスホルメン（造船の島）",
            summary: "王立艦隊が帆を休めた停泊地。紋章は銀地に青い帆船。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3258, longitude: 18.0847)
        ),
        HistoricSite(
            id: "stockholm-slussen",
            overlayMapID: "stockholm-old-town",
            name: "スルッセン（メーラレン湖への水門）",
            summary: "海と湖を隔てる水門。紋章は金地に黒い鍵。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3197, longitude: 18.0717)
        ),
        HistoricSite(
            id: "stockholm-stortorget",
            overlayMapID: "stockholm-old-town",
            name: "ストールトリエット（大広場）",
            summary: "ガムラスタンで最も古い広場。赤や黄の切妻の商家が囲み、1520年の「ストックホルムの血浴」の舞台にもなった。紋章は赤地に金の家。",
            coordinate: CLLocationCoordinate2D(latitude: 59.325, longitude: 18.0708)
        ),
        HistoricSite(
            id: "stockholm-riddarhuset",
            overlayMapID: "stockholm-old-town",
            name: "リッダルフーセット（貴族院）",
            summary: "17世紀、スウェーデン大国時代の貴族たちが議会を開いたオランダ・バロック様式の館。紋章は青地に金の盾。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3259, longitude: 18.0658)
        ),
        HistoricSite(
            id: "stockholm-marten-trotzig",
            overlayMapID: "stockholm-old-town",
            name: "マーテン・トロッツィグ小路",
            summary: "幅わずか90cmほどの、街でいちばん細い石段の路地。17世紀の商人の名が残る。紋章は黒地に銀の旅人。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3231, longitude: 18.0728)
        ),
        HistoricSite(
            id: "stockholm-city-hall",
            overlayMapID: "stockholm-old-town",
            name: "ストックホルム市庁舎（ストックホルムの象徴）",
            summary: "メーラレン湖のほとりにそびえる、三つの王冠を頂く塔の赤れんがの市庁舎。ストックホルムの象徴で、『魔女の宅急便』の舞台のモデルのひとつとされる。紋章は赤地に金の三つの王冠。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3275, longitude: 18.0542)
        ),
        HistoricSite(
            id: "stockholm-zum-franziskaner",
            overlayMapID: "stockholm-old-town",
            name: "ツム・フランツィスカーナー（ビアホール）",
            summary: "ドイツ商人の時代から続く、ガムラスタンの水辺の古いビアホール。『魔女の宅急便』の舞台のモデルのひとつとされる。紋章は金地に黒いジョッキ。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3224, longitude: 18.0742)
        ),
        HistoricSite(
            id: "stockholm-tyska-brinken",
            overlayMapID: "stockholm-old-town",
            name: "ティスカ・ブリンケン（ガムラスタンの石畳）",
            summary: "ドイツ教会へと上る、ガムラスタンの石畳の坂道。『魔女の宅急便』の舞台のモデルのひとつとされる。紋章は銀地に黒い石段。",
            coordinate: CLLocationCoordinate2D(latitude: 59.3233, longitude: 18.0695)
        ),
        // Europe — タリン旧市街（ハンザ同盟）
        HistoricSite(
            id: "tallinn-raekoja-plats",
            overlayMapID: "tallinn-old-town",
            name: "ラエコヤ広場（旧市庁舎広場）",
            summary: "風見鶏の下、商人たちが取引を交わした都の広場。紋章は銀地に黒い市庁舎塔。",
            coordinate: CLLocationCoordinate2D(latitude: 59.437, longitude: 24.7454)
        ),
        HistoricSite(
            id: "tallinn-toompea",
            overlayMapID: "tallinn-old-town",
            name: "トームペア（城の丘）",
            summary: "旗のはためく丘の上から旧市街を見張る、長いヘルマン塔。紋章は青地に金の旗塔。",
            coordinate: CLLocationCoordinate2D(latitude: 59.437, longitude: 24.7402)
        ),
        HistoricSite(
            id: "tallinn-viru-gate",
            overlayMapID: "tallinn-old-town",
            name: "ヴィル門",
            summary: "東からの旅人を迎える、双子の尖塔をもつ城門。紋章は黒地に銀の双塔。",
            coordinate: CLLocationCoordinate2D(latitude: 59.4376, longitude: 24.7484)
        ),
        HistoricSite(
            id: "tallinn-oleviste",
            overlayMapID: "tallinn-old-town",
            name: "オレヴィステ教会（聖オレフ教会）",
            summary: "かつて世界一高かったとされる尖塔。紋章は赤地に金の尖塔。",
            coordinate: CLLocationCoordinate2D(latitude: 59.4393, longitude: 24.7439)
        ),
        HistoricSite(
            id: "tallinn-paks-margareeta",
            overlayMapID: "tallinn-old-town",
            name: "太っちょマルガレータ（港の円塔）",
            summary: "大砲を構え、港へ入る船を見張ってきた丸々とした塔。紋章はティール地に銀の円塔。",
            coordinate: CLLocationCoordinate2D(latitude: 59.4425, longitude: 24.7456)
        ),
        HistoricSite(
            id: "tallinn-toomkirik",
            overlayMapID: "tallinn-old-town",
            name: "トームキリク（聖母マリア大聖堂）",
            summary: "トームペアの丘に建つエストニア最古の教会。壁にはバルト・ドイツ貴族の紋章板がずらりと掛かる。紋章は青地に銀の十字。",
            coordinate: CLLocationCoordinate2D(latitude: 59.437, longitude: 24.7392)
        ),
        HistoricSite(
            id: "tallinn-katariina-kaik",
            overlayMapID: "tallinn-old-town",
            name: "カタリーナの小路",
            summary: "中世の修道院の壁と墓石が残る石畳の路地。職人たちの工房が今も軒を連ねる。紋章は黒地に金の槌。",
            coordinate: CLLocationCoordinate2D(latitude: 59.4378, longitude: 24.748)
        ),
        HistoricSite(
            id: "tallinn-kohtuotsa",
            overlayMapID: "tallinn-old-town",
            name: "コフトゥオツァ展望台",
            summary: "トームペアの崖の上から、赤い屋根の下町と教会の尖塔、その先のバルト海を見渡す展望台。紋章はティール地に銀の遠眼鏡。",
            coordinate: CLLocationCoordinate2D(latitude: 59.4377, longitude: 24.7422)
        ),
        // Europe — パリ・モンマルトル（芸術家の家めぐり）
        HistoricSite(
            id: "paris-bateau-lavoir",
            overlayMapID: "paris-montmartre",
            name: "洗濯船（バトー・ラヴォワール）",
            summary: "ピカソが暮らし『アヴィニョンの娘たち』を描いた、古い木造のアトリエ長屋。",
            coordinate: CLLocationCoordinate2D(latitude: 48.8861, longitude: 2.3375)
        ),
        HistoricSite(
            id: "paris-van-gogh",
            overlayMapID: "paris-montmartre",
            name: "ゴッホの家（ルピック通り54番地）",
            summary: "1886〜88年、ゴッホが弟テオと暮らしたアパルトマン。",
            coordinate: CLLocationCoordinate2D(latitude: 48.8865, longitude: 2.3339)
        ),
        HistoricSite(
            id: "paris-musee-montmartre",
            overlayMapID: "paris-montmartre",
            name: "モンマルトル美術館（ルノワールのアトリエ）",
            summary: "ルノワールがアトリエを構え、ヴァラドンとユトリロの母子も暮らした館。",
            coordinate: CLLocationCoordinate2D(latitude: 48.888, longitude: 2.3406)
        ),
        HistoricSite(
            id: "paris-moulin-galette",
            overlayMapID: "paris-montmartre",
            name: "ムーラン・ド・ラ・ギャレット",
            summary: "ルノワールの名画に描かれた、風車のある野外のダンスホール。",
            coordinate: CLLocationCoordinate2D(latitude: 48.8877, longitude: 2.3363)
        ),
        HistoricSite(
            id: "paris-lapin-agile",
            overlayMapID: "paris-montmartre",
            name: "ラパン・アジル",
            summary: "ピカソやユトリロら、貧しい芸術家たちが集ったキャバレー。",
            coordinate: CLLocationCoordinate2D(latitude: 48.8886, longitude: 2.34)
        ),
        HistoricSite(
            id: "paris-moulin-rouge",
            overlayMapID: "paris-montmartre",
            name: "ムーラン・ルージュ",
            summary: "ロートレックがポスターと踊り子を描いた、赤い風車のキャバレー。",
            coordinate: CLLocationCoordinate2D(latitude: 48.8841, longitude: 2.3324)
        ),
        // Europe — ロンドン（シェイクスピアの時代）
        HistoricSite(
            id: "london-globe",
            overlayMapID: "london-shakespeare",
            name: "グローブ座",
            summary: "シェイクスピアの劇団が建てた円形劇場（今の建物は1997年の復元）。",
            coordinate: CLLocationCoordinate2D(latitude: 51.5081, longitude: -0.0972)
        ),
        HistoricSite(
            id: "london-rose",
            overlayMapID: "london-shakespeare",
            name: "ローズ座",
            summary: "テムズ南岸で最初期の劇場の一つ。シェイクスピアの初期の作品が上演された。",
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.0939)
        ),
        HistoricSite(
            id: "london-southwark-cathedral",
            overlayMapID: "london-shakespeare",
            name: "サザーク大聖堂",
            summary: "シェイクスピアの弟エドマンドが眠り、劇作家の記念碑がある大聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 51.5061, longitude: -0.0896)
        ),
        HistoricSite(
            id: "london-bridge",
            overlayMapID: "london-shakespeare",
            name: "ロンドン橋",
            summary: "当時は橋の上に家や店が建ち並び、南の門には反逆者の首がさらされた。",
            coordinate: CLLocationCoordinate2D(latitude: 51.508, longitude: -0.0877)
        ),
        HistoricSite(
            id: "london-st-pauls",
            overlayMapID: "london-shakespeare",
            name: "セント・ポール大聖堂",
            summary: "当時の境内には本屋が並び、シェイクスピアの戯曲も売られていた（今の聖堂は大火の後の再建）。",
            coordinate: CLLocationCoordinate2D(latitude: 51.5138, longitude: -0.0985)
        ),
        HistoricSite(
            id: "london-tower",
            overlayMapID: "london-shakespeare",
            name: "ロンドン塔",
            summary: "王の城塞であり牢獄。『リチャード三世』などの舞台にもなった。",
            coordinate: CLLocationCoordinate2D(latitude: 51.5082, longitude: -0.0762)
        ),
        // Europe — ブリュッセル（ベルギー王国の心臓部）
        HistoricSite(
            id: "brussels-grand-place",
            overlayMapID: "brussels-1850",
            name: "グランプラス",
            summary: "市庁舎とギルドハウスに囲まれた、ブリュッセルの中心の広場。ユゴーが「世界で最も美しい広場」と讃えた。",
            coordinate: CLLocationCoordinate2D(latitude: 50.8467, longitude: 4.3524)
        ),
        HistoricSite(
            id: "brussels-manneken-pis",
            overlayMapID: "brussels-1850",
            name: "小便小僧",
            summary: "17世紀から街角に立つ小さな噴水の像。街の人々に「最古の市民」と親しまれてきた。",
            coordinate: CLLocationCoordinate2D(latitude: 50.845, longitude: 4.35)
        ),
        HistoricSite(
            id: "brussels-galeries-saint-hubert",
            overlayMapID: "brussels-1850",
            name: "ギャルリ・サンチュベール",
            summary: "1847年に開業した、ガラス屋根のヨーロッパ最古級のアーケード。",
            coordinate: CLLocationCoordinate2D(latitude: 50.8478, longitude: 4.3548)
        ),
        HistoricSite(
            id: "brussels-cathedral",
            overlayMapID: "brussels-1850",
            name: "聖ミカエルと聖グドゥラ大聖堂",
            summary: "街の守護聖人をまつる、双塔のゴシック様式の大聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 50.8478, longitude: 4.36)
        ),
        HistoricSite(
            id: "brussels-mont-des-arts",
            overlayMapID: "brussels-1850",
            name: "芸術の丘",
            summary: "下町と王宮のある高台を結ぶ丘。昔は古い家並みが坂に連なっていた。",
            coordinate: CLLocationCoordinate2D(latitude: 50.8445, longitude: 4.3565)
        ),
        HistoricSite(
            id: "brussels-royal-palace",
            overlayMapID: "brussels-1850",
            name: "王宮とブリュッセル公園",
            summary: "独立後、初代国王レオポルド1世が使った王宮と、その前に広がる公園。1830年の革命では戦いの場になった。",
            coordinate: CLLocationCoordinate2D(latitude: 50.8418, longitude: 4.362)
        ),
        HistoricSite(
            id: "brussels-sainte-catherine",
            overlayMapID: "brussels-1850",
            name: "サント・カトリーヌ（旧港）",
            summary: "かつて運河の船着き場があった地区。魚市場が開かれ、今も魚料理の店が並ぶ。",
            coordinate: CLLocationCoordinate2D(latitude: 50.851, longitude: 4.3475)
        ),
        HistoricSite(
            id: "brussels-jeu-de-balle",
            overlayMapID: "brussels-1850",
            name: "ジュ・ド・バル広場（マロル地区）",
            summary: "職人や労働者が暮らした下町マロルの広場。毎朝、蚤の市が開かれる。",
            coordinate: CLLocationCoordinate2D(latitude: 50.8374, longitude: 4.3463)
        ),
        // 北京・紫禁城と内城（清代）
        HistoricSite(
            id: "beijing-forbidden-city",
            overlayMapID: "beijing-qing",
            name: "紫禁城（故宮）",
            summary: "明・清の皇帝が暮らした、黄色い瑠璃瓦が連なる世界最大級の宮殿。",
            coordinate: CLLocationCoordinate2D(latitude: 39.9163, longitude: 116.3908)
        ),
        HistoricSite(
            id: "beijing-tiananmen",
            overlayMapID: "beijing-qing",
            name: "天安門",
            summary: "紫禁城の正門として皇帝の詔が発せられた門。朱色の城楼が広場を見下ろす。",
            coordinate: CLLocationCoordinate2D(latitude: 39.9075, longitude: 116.391)
        ),
        HistoricSite(
            id: "beijing-temple-of-heaven",
            overlayMapID: "beijing-qing",
            name: "天壇・祈年殿",
            summary: "皇帝が五穀豊穣を天に祈った、三層の青い屋根の円形の殿堂。",
            coordinate: CLLocationCoordinate2D(latitude: 39.8822, longitude: 116.4007)
        ),
        HistoricSite(
            id: "beijing-jingshan",
            overlayMapID: "beijing-qing",
            name: "景山",
            summary: "紫禁城の北を守る人工の丘。頂の万春亭から宮殿の黄色い屋根の海を一望できる。",
            coordinate: CLLocationCoordinate2D(latitude: 39.9245, longitude: 116.3904)
        ),
        HistoricSite(
            id: "beijing-drum-bell-tower",
            overlayMapID: "beijing-qing",
            name: "鐘楼・鼓楼",
            summary: "鐘と太鼓で都に時を告げた二つの楼閣。周りには胡同が広がる。",
            coordinate: CLLocationCoordinate2D(latitude: 39.9393, longitude: 116.3897)
        ),
        // 西安・長安（明の西安府城）
        HistoricSite(
            id: "xian-bell-tower",
            overlayMapID: "xian-changan",
            name: "鐘楼",
            summary: "西安府城の中心、東西南北の大街が交わる所に立つ明代の楼閣。",
            coordinate: CLLocationCoordinate2D(latitude: 34.261, longitude: 108.9423)
        ),
        HistoricSite(
            id: "xian-drum-tower",
            overlayMapID: "xian-changan",
            name: "鼓楼",
            summary: "鐘楼と向かい合い、夕暮れに太鼓で時を告げた楼閣。北には回民街が続く。",
            coordinate: CLLocationCoordinate2D(latitude: 34.2618, longitude: 108.9388)
        ),
        HistoricSite(
            id: "xian-yongning-gate",
            overlayMapID: "xian-changan",
            name: "永寧門（南門）と城壁",
            summary: "周囲約14kmの明代の城壁の正門。城壁の上を歩いて一周できる。",
            coordinate: CLLocationCoordinate2D(latitude: 34.2531, longitude: 108.9423)
        ),
        HistoricSite(
            id: "xian-beilin",
            overlayMapID: "xian-changan",
            name: "碑林",
            summary: "唐代以来の石碑が林のように立ち並ぶ、書の聖地。",
            coordinate: CLLocationCoordinate2D(latitude: 34.255, longitude: 108.9481)
        ),
        HistoricSite(
            id: "xian-big-wild-goose-pagoda",
            overlayMapID: "xian-changan",
            name: "大雁塔",
            summary: "玄奘三蔵がインドから持ち帰った経典を納めるために建てられた唐代の塔。",
            coordinate: CLLocationCoordinate2D(latitude: 34.2198, longitude: 108.9594)
        ),
        // ラサ・ポタラ宮と聖都
        HistoricSite(
            id: "lhasa-potala",
            overlayMapID: "lhasa-holy-city",
            name: "ポタラ宮",
            summary: "歴代ダライ・ラマの宮殿。マルポリの丘に白宮と紅宮がそびえる。",
            coordinate: CLLocationCoordinate2D(latitude: 29.6576, longitude: 91.117)
        ),
        HistoricSite(
            id: "lhasa-jokhang",
            overlayMapID: "lhasa-holy-city",
            name: "ジョカン（大昭寺）",
            summary: "7世紀、ソンツェン・ガンポ王の時代に建てられたチベット仏教で最も聖なる寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 29.6529, longitude: 91.1318)
        ),
        HistoricSite(
            id: "lhasa-barkhor",
            overlayMapID: "lhasa-holy-city",
            name: "バルコル（八廓街）",
            summary: "ジョカンを囲む巡礼路。人々がマニ車を回しながら時計回りに歩く。",
            coordinate: CLLocationCoordinate2D(latitude: 29.652, longitude: 91.133)
        ),
        HistoricSite(
            id: "lhasa-norbulingka",
            overlayMapID: "lhasa-holy-city",
            name: "ノルブリンカ",
            summary: "ダライ・ラマの夏の離宮。「宝石の庭」を意味する緑豊かな庭園。",
            coordinate: CLLocationCoordinate2D(latitude: 29.6546, longitude: 91.09)
        ),
        HistoricSite(
            id: "lhasa-ramoche",
            overlayMapID: "lhasa-holy-city",
            name: "ラモチェ（小昭寺）",
            summary: "唐から嫁いだ文成公主ゆかりの寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 29.6586, longitude: 91.1304)
        ),
        // アンコール（クメール王朝の都）
        HistoricSite(
            id: "angkor-wat",
            overlayMapID: "angkor-yasodharapura",
            name: "アンコール・ワット",
            summary: "12世紀、スーリヤヴァルマン2世が建てた寺院。環濠に五つの塔が映る。",
            coordinate: CLLocationCoordinate2D(latitude: 13.4125, longitude: 103.8666)
        ),
        HistoricSite(
            id: "angkor-thom-south-gate",
            overlayMapID: "angkor-yasodharapura",
            name: "アンコール・トム南大門",
            summary: "四面に観世音菩薩の顔を刻んだ城門。参道の欄干には神々と阿修羅が並ぶ。",
            coordinate: CLLocationCoordinate2D(latitude: 13.4288, longitude: 103.8597)
        ),
        HistoricSite(
            id: "angkor-bayon",
            overlayMapID: "angkor-yasodharapura",
            name: "バイヨン",
            summary: "アンコール・トムの中心に建つ寺院。無数の「クメールの微笑み」が見下ろす。",
            coordinate: CLLocationCoordinate2D(latitude: 13.4412, longitude: 103.8591)
        ),
        HistoricSite(
            id: "angkor-ta-prohm",
            overlayMapID: "angkor-yasodharapura",
            name: "タ・プローム",
            summary: "巨大なガジュマルの根が遺跡を抱き込む、密林の寺院。",
            coordinate: CLLocationCoordinate2D(latitude: 13.4349, longitude: 103.8896)
        ),
        HistoricSite(
            id: "angkor-phnom-bakheng",
            overlayMapID: "angkor-yasodharapura",
            name: "プノン・バケン",
            summary: "都の最初の中心となった丘の上の寺院。夕日の名所。",
            coordinate: CLLocationCoordinate2D(latitude: 13.4238, longitude: 103.8562)
        ),
        // デリー・シャージャハーナーバード（ムガル帝国）
        HistoricSite(
            id: "delhi-red-fort",
            overlayMapID: "delhi-shahjahanabad",
            name: "ラール・キラー（赤い城）",
            summary: "ムガル皇帝シャー・ジャハーンが築いた赤砂岩の宮城。",
            coordinate: CLLocationCoordinate2D(latitude: 28.6561, longitude: 77.2408)
        ),
        HistoricSite(
            id: "delhi-jama-masjid",
            overlayMapID: "delhi-shahjahanabad",
            name: "ジャーマー・マスジド",
            summary: "インド最大級のモスク。赤砂岩と白大理石の三つのドームが並ぶ。",
            coordinate: CLLocationCoordinate2D(latitude: 28.6507, longitude: 77.233)
        ),
        HistoricSite(
            id: "delhi-chandni-chowk",
            overlayMapID: "delhi-shahjahanabad",
            name: "チャンドニー・チョーク",
            summary: "「月光の広場」と呼ばれたオールドデリーの目抜き通り。今も市場の熱気に満ちる。",
            coordinate: CLLocationCoordinate2D(latitude: 28.656, longitude: 77.2322)
        ),
        HistoricSite(
            id: "delhi-fatehpuri-masjid",
            overlayMapID: "delhi-shahjahanabad",
            name: "ファテープリー・マスジド",
            summary: "チャンドニー・チョークの西の端に建つ、皇妃が寄進したモスク。",
            coordinate: CLLocationCoordinate2D(latitude: 28.6567, longitude: 77.2223)
        ),
        HistoricSite(
            id: "delhi-kashmiri-gate",
            overlayMapID: "delhi-shahjahanabad",
            name: "カシミール門",
            summary: "城壁都市の北の門。カシミールへ向かう道の起点。",
            coordinate: CLLocationCoordinate2D(latitude: 28.6668, longitude: 77.2291)
        ),
        // イスファハーン（ペルシャ・サファヴィー朝）
        HistoricSite(
            id: "isfahan-naqsh-e-jahan",
            overlayMapID: "isfahan-safavid",
            name: "ナグシェ・ジャハーン広場",
            summary: "「世界の肖像」の名を持つ、サファヴィー朝の王都の巨大な広場。",
            coordinate: CLLocationCoordinate2D(latitude: 32.6581, longitude: 51.6774)
        ),
        HistoricSite(
            id: "isfahan-shah-mosque",
            overlayMapID: "isfahan-safavid",
            name: "イマーム・モスク（王のモスク）",
            summary: "青いタイルに覆われたドームと門が、広場の南を飾るモスク。",
            coordinate: CLLocationCoordinate2D(latitude: 32.6548, longitude: 51.6784)
        ),
        HistoricSite(
            id: "isfahan-chehel-sotoun",
            overlayMapID: "isfahan-safavid",
            name: "チェヘル・ソトゥーン",
            summary: "池に柱が映って「四十の柱」に見える宮殿。",
            coordinate: CLLocationCoordinate2D(latitude: 32.6574, longitude: 51.672)
        ),
        HistoricSite(
            id: "isfahan-si-o-se-pol",
            overlayMapID: "isfahan-safavid",
            name: "スィー・オ・セ橋",
            summary: "ザーヤンデ川に架かる33のアーチの橋。",
            coordinate: CLLocationCoordinate2D(latitude: 32.6446, longitude: 51.6675)
        ),
        HistoricSite(
            id: "isfahan-jameh-mosque",
            overlayMapID: "isfahan-safavid",
            name: "金曜モスク（マスジェデ・ジャーメ）",
            summary: "千年以上にわたって増築されてきた、イラン建築の博物館のようなモスク。",
            coordinate: CLLocationCoordinate2D(latitude: 32.67, longitude: 51.6855)
        ),
        // エルサレム旧市街
        HistoricSite(
            id: "jerusalem-dome-of-the-rock",
            overlayMapID: "jerusalem-old-city",
            name: "岩のドーム",
            summary: "金色のドームが旧市街を見下ろす、7世紀末に建てられたイスラームの聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 31.778, longitude: 35.2353)
        ),
        HistoricSite(
            id: "jerusalem-western-wall",
            overlayMapID: "jerusalem-old-city",
            name: "嘆きの壁",
            summary: "第二神殿を支えた西側の擁壁。ユダヤ教の祈りの場。",
            coordinate: CLLocationCoordinate2D(latitude: 31.7767, longitude: 35.2344)
        ),
        HistoricSite(
            id: "jerusalem-holy-sepulchre",
            overlayMapID: "jerusalem-old-city",
            name: "聖墳墓教会",
            summary: "イエスの磔刑と埋葬の地とされる、キリスト教の聖地。",
            coordinate: CLLocationCoordinate2D(latitude: 31.7784, longitude: 35.2298)
        ),
        HistoricSite(
            id: "jerusalem-jaffa-gate",
            overlayMapID: "jerusalem-old-city",
            name: "ヤッフォ門・ダビデの塔",
            summary: "地中海の港町ヤッフォへ向かう西の門。脇に城塞がそびえる。",
            coordinate: CLLocationCoordinate2D(latitude: 31.7766, longitude: 35.2273)
        ),
        HistoricSite(
            id: "jerusalem-damascus-gate",
            overlayMapID: "jerusalem-old-city",
            name: "ダマスカス門",
            summary: "スレイマン1世が築いた、北の最も壮麗な門。",
            coordinate: CLLocationCoordinate2D(latitude: 31.7817, longitude: 35.2305)
        ),
        // ボストン（独立戦争の時代）
        HistoricSite(
            id: "boston-old-state-house",
            overlayMapID: "boston-colonial",
            name: "旧州議事堂",
            summary: "1770年のボストン虐殺事件の現場。バルコニーから独立宣言が読み上げられた。",
            coordinate: CLLocationCoordinate2D(latitude: 42.3587, longitude: -71.0575)
        ),
        HistoricSite(
            id: "boston-faneuil-hall",
            overlayMapID: "boston-colonial",
            name: "ファニエル・ホール",
            summary: "「自由のゆりかご」と呼ばれた集会所。独立を求める演説が行われた。",
            coordinate: CLLocationCoordinate2D(latitude: 42.36, longitude: -71.0562)
        ),
        HistoricSite(
            id: "boston-paul-revere-house",
            overlayMapID: "boston-colonial",
            name: "ポール・リビアの家",
            summary: "1775年、英軍の進軍を夜通し馬で知らせた銀細工師の家。",
            coordinate: CLLocationCoordinate2D(latitude: 42.3637, longitude: -71.0537)
        ),
        HistoricSite(
            id: "boston-old-north-church",
            overlayMapID: "boston-colonial",
            name: "オールド・ノース教会",
            summary: "「陸なら一つ、海なら二つ」のランタンが掲げられた尖塔。",
            coordinate: CLLocationCoordinate2D(latitude: 42.3663, longitude: -71.0544)
        ),
        HistoricSite(
            id: "boston-common",
            overlayMapID: "boston-colonial",
            name: "ボストン・コモンと州議事堂",
            summary: "1634年に造られた米国最古の公園と、金色のドームの州議事堂。",
            coordinate: CLLocationCoordinate2D(latitude: 42.3586, longitude: -71.0639)
        ),
        // ニューヨーク（ニューアムステルダム）
        HistoricSite(
            id: "newyork-castle-clinton",
            overlayMapID: "newyork-new-amsterdam",
            name: "キャッスル・クリントン",
            summary: "マンハッタン南端の砦。移民の受け入れ所だった時代もある。",
            coordinate: CLLocationCoordinate2D(latitude: 40.7035, longitude: -74.0166)
        ),
        HistoricSite(
            id: "newyork-fraunces-tavern",
            overlayMapID: "newyork-new-amsterdam",
            name: "フランセス・タバーン",
            summary: "1783年、ワシントンが将校たちに別れを告げた酒場。",
            coordinate: CLLocationCoordinate2D(latitude: 40.7034, longitude: -74.0113)
        ),
        HistoricSite(
            id: "newyork-federal-hall",
            overlayMapID: "newyork-new-amsterdam",
            name: "フェデラル・ホール",
            summary: "1789年、ワシントンが初代大統領に就任した場所。前はウォール街。",
            coordinate: CLLocationCoordinate2D(latitude: 40.7073, longitude: -74.0103)
        ),
        HistoricSite(
            id: "newyork-trinity-church",
            overlayMapID: "newyork-new-amsterdam",
            name: "トリニティ教会",
            summary: "ウォール街の突き当たりに建つゴシックの教会。",
            coordinate: CLLocationCoordinate2D(latitude: 40.7081, longitude: -74.0122)
        ),
        HistoricSite(
            id: "newyork-city-hall",
            overlayMapID: "newyork-new-amsterdam",
            name: "ニューヨーク市庁舎",
            summary: "1812年に完成した、今も使われる米国最古級の市庁舎。",
            coordinate: CLLocationCoordinate2D(latitude: 40.7127, longitude: -74.0059)
        ),
        // メキシコシティ（テノチティトランの跡）
        HistoricSite(
            id: "mexico-zocalo",
            overlayMapID: "mexico-tenochtitlan",
            name: "ソカロ（憲法広場）",
            summary: "アステカの都テノチティトランの中心に築かれた、世界有数の大きな広場。",
            coordinate: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)
        ),
        HistoricSite(
            id: "mexico-cathedral",
            overlayMapID: "mexico-tenochtitlan",
            name: "メトロポリタン大聖堂",
            summary: "アステカの神殿の石を使って建てられた、ラテンアメリカ最大級の大聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: 19.4344, longitude: -99.1331)
        ),
        HistoricSite(
            id: "mexico-templo-mayor",
            overlayMapID: "mexico-tenochtitlan",
            name: "テンプロ・マヨール",
            summary: "アステカの大神殿の遺跡。1978年に偶然発見された。",
            coordinate: CLLocationCoordinate2D(latitude: 19.4351, longitude: -99.1314)
        ),
        HistoricSite(
            id: "mexico-bellas-artes",
            overlayMapID: "mexico-tenochtitlan",
            name: "ベジャス・アルテス宮殿",
            summary: "アール・ヌーヴォーの外観とアール・デコの内装を持つ劇場。",
            coordinate: CLLocationCoordinate2D(latitude: 19.4355, longitude: -99.1413)
        ),
        HistoricSite(
            id: "mexico-santo-domingo",
            overlayMapID: "mexico-tenochtitlan",
            name: "サント・ドミンゴ広場",
            summary: "植民地時代の代書屋が並んだ広場。赤いテソントレ石の教会が建つ。",
            coordinate: CLLocationCoordinate2D(latitude: 19.4373, longitude: -99.1339)
        ),
        // クスコ（インカ帝国の都）
        HistoricSite(
            id: "cusco-plaza-de-armas",
            overlayMapID: "cusco-inca",
            name: "アルマス広場",
            summary: "インカの儀式の広場ワカイパタの上に築かれた広場と大聖堂。",
            coordinate: CLLocationCoordinate2D(latitude: -13.5168, longitude: -71.9788)
        ),
        HistoricSite(
            id: "cusco-qorikancha",
            overlayMapID: "cusco-inca",
            name: "コリカンチャ（太陽の神殿）",
            summary: "金の板で覆われていたインカの太陽神殿。上にサント・ドミンゴ修道院が建つ。",
            coordinate: CLLocationCoordinate2D(latitude: -13.5203, longitude: -71.9751)
        ),
        HistoricSite(
            id: "cusco-hatun-rumiyoc",
            overlayMapID: "cusco-inca",
            name: "12角の石（ハトゥン・ルミヨク通り）",
            summary: "剃刀の刃も入らない、インカの精巧な石組み。",
            coordinate: CLLocationCoordinate2D(latitude: -13.5157, longitude: -71.9765)
        ),
        HistoricSite(
            id: "cusco-san-blas",
            overlayMapID: "cusco-inca",
            name: "サン・ブラス地区",
            summary: "職人の工房が集まる坂の街。",
            coordinate: CLLocationCoordinate2D(latitude: -13.5152, longitude: -71.9742)
        ),
        HistoricSite(
            id: "cusco-sacsayhuaman",
            overlayMapID: "cusco-inca",
            name: "サクサイワマン",
            summary: "巨石を三段に積んだインカの城塞。",
            coordinate: CLLocationCoordinate2D(latitude: -13.5068, longitude: -71.9802)
        ),
        // ブエノスアイレス（植民地時代の港町）
        HistoricSite(
            id: "buenosaires-plaza-de-mayo",
            overlayMapID: "buenosaires-colonial",
            name: "五月広場とカサ・ロサーダ",
            summary: "1810年の五月革命の舞台。桃色の大統領府が向かい合う。",
            coordinate: CLLocationCoordinate2D(latitude: -34.6084, longitude: -58.3722)
        ),
        HistoricSite(
            id: "buenosaires-cabildo",
            overlayMapID: "buenosaires-colonial",
            name: "カビルド（旧市参事会）",
            summary: "植民地時代の市政の中心だった、白い回廊の建物。",
            coordinate: CLLocationCoordinate2D(latitude: -34.6089, longitude: -58.3737)
        ),
        HistoricSite(
            id: "buenosaires-plaza-dorrego",
            overlayMapID: "buenosaires-colonial",
            name: "ドレーゴ広場（サン・テルモ）",
            summary: "石畳の古い街並みでタンゴが踊られる広場。",
            coordinate: CLLocationCoordinate2D(latitude: -34.6205, longitude: -58.3718)
        ),
        HistoricSite(
            id: "buenosaires-teatro-colon",
            overlayMapID: "buenosaires-colonial",
            name: "コロン劇場",
            summary: "世界三大劇場の一つに数えられるオペラハウス。",
            coordinate: CLLocationCoordinate2D(latitude: -34.6011, longitude: -58.3832)
        ),
        HistoricSite(
            id: "buenosaires-obelisco",
            overlayMapID: "buenosaires-colonial",
            name: "オベリスコ",
            summary: "市の創設400年を記念して建てられた、7月9日大通りの白い塔。",
            coordinate: CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816)
        ),
    ]

    /// 置き換えによって廃止されたチェックポイントID → 置き換え先IDの対応表（例: 個人の古地図を同梱の古地図に置き換えた時）。
    /// 過去の御朱印に残る廃止IDを、表示時・起動時の移行（`CatalogMigration`）で読み替える。
    static let mergedIntoID: [String: String] = [
        "E28E96A1-8694-42B7-A17B-A4811D4D1954-cp1": "brussels-grand-place",
        "E28E96A1-8694-42B7-A17B-A4811D4D1954-cp2": "brussels-manneken-pis",
        "E28E96A1-8694-42B7-A17B-A4811D4D1954-cp3": "brussels-cathedral",
        "E28E96A1-8694-42B7-A17B-A4811D4D1954-cp5": "brussels-mont-des-arts",
    ]
}
