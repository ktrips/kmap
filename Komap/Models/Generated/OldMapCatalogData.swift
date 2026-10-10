// このファイルは scripts/generate-catalog.mjs が catalog/old_maps.json から生成したものです。直接編集しないでください。

import CoreLocation

extension OldMapCatalog {
    static let edoCastle = HistoricalOverlayMap(
        id: "edo-castle-1850s",
        title: "江戸城周辺（安政期）",
        era: "江戸時代後期（1850年代・安政期）",
        summary: "江戸城の内堀・外堀と大名屋敷が広がっていたエリア。現在の皇居・大手町・丸の内に加え、九段下・千鳥ヶ淵（靖国神社周辺）、霞ヶ関・虎ノ門一帯も含みます。",
        imageAssetName: "OldMap_EdoCastle",
        // 元々は皇居周辺のみの範囲だったが、九段下・千鳥ヶ淵（`kudanshitaChidorigafuchi`）と
        // 霞ヶ関・虎ノ門（`kasumigasekiToranomon`）を統合したため、南側を少し広げている
        // （イラスト画像自体はそのままのため、南端付近はやや引き伸ばされた表示になる）。
        southWest: CLLocationCoordinate2D(latitude: 35.6653, longitude: 139.74),
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
    //
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
        southWest: CLLocationCoordinate2D(latitude: 35.6531, longitude: 139.713),
        northEast: CLLocationCoordinate2D(latitude: 35.755, longitude: 139.838)
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
        southWest: CLLocationCoordinate2D(latitude: 35.68, longitude: 139.7),
        northEast: CLLocationCoordinate2D(latitude: 35.755, longitude: 139.79)
    )

    // 銀座・歌舞伎座は、当初は自作のオリジナル「古地図風」イラスト（`OldMap_GinzaKabukiza`）
    // だったが、日本橋・神田明神と同じ「東京實測全圖」実写版（`OldMap_Nihonbashi`）を
    // 使うよう変更した。日本橋のすぐ南に銀座・築地があり、この画像自体がもともと
    // 銀座エリアも含む範囲で撮影・位置合わせされているため、南側（浜離宮・大門）まで
    // 範囲を広げて日本橋と同じ画像・同じ位置合わせをそのまま使っている。
    static let ginzaKabukiza = HistoricalOverlayMap(
        id: "ginza-kabukiza",
        title: "銀座・歌舞伎座",
        era: "明治時代（1891年・明治24年頃）",
        summary: "文明開化とともに煉瓦街が築かれ、柳並木が象徴となった銀座と、歌舞伎の殿堂・歌舞伎座を中心としたエリアです。京橋から新橋、浜離宮・大門にかけてをたどります。",
        imageAssetName: "OldMap_Nihonbashi",
        southWest: CLLocationCoordinate2D(latitude: 35.652, longitude: 139.7505),
        northEast: CLLocationCoordinate2D(latitude: 35.7166, longitude: 139.7929)
    )

    // 現在の地図（OpenStreetMap）から、赤坂〜明治神宮〜二子玉川間の大山街道沿いを取得し、
    // セピア調フィルターをかけて古地図風に加工した画像。実際の歴史史料ではない
    // （`akasakaKioicho`と同じ「現在の地図から加工した古地図風画像」の扱い）。
    // ピンアイコン等が写り込んでいない素の地図から作成したため、inpaintによる除去は行っていない。
    static let oyamaKaido = HistoricalOverlayMap(
        id: "oyama-kaido",
        title: "大山街道（赤坂〜明治神宮〜二子）",
        era: "古地図風（現在の地図をもとに加工）",
        summary: "江戸時代の大山詣でで賑わった大山街道（矢倉沢往還）のうち、赤坂から明治神宮・渋谷・三軒茶屋を経て、多摩川の渡し場があった二子玉川までをたどる、現在の地図をもとにした古地図風の画像です。",
        imageAssetName: "OldMap_OyamaKaido",
        southWest: CLLocationCoordinate2D(latitude: 35.585851593232356, longitude: 139.6142578125),
        northEast: CLLocationCoordinate2D(latitude: 35.6929946320988, longitude: 139.74609375)
    )

    // 「アニメ・映画聖地巡礼」向けは、他の古地図（史実の古地図・現在の地図をセピア加工したもの）と
    // 区別するため、実在の道路データを使わないオリジナルのイラストを使う。特定作品の
    // キャラクター・場面・絵柄を再現せず、あくまで作品の雰囲気（この地図は黄昏時の彗星と
    // 山並み）だけを表現した完全オリジナルデザイン。位置合わせ座標は、実際の緯度経度に
    // 対して正方形（縦横比1:1、GMSGroundOverlayの引き伸ばしを避けるため）になるよう計算している。
    static let kiminonaSeichi = HistoricalOverlayMap(
        id: "kiminona-seichi",
        title: "「君の名は。」聖地巡礼",
        era: "現代（映画『君の名は。』の聖地巡礼スポット）",
        summary: "須賀神社の男坂石段や四ツ谷駅など、映画『君の名は。』の舞台として知られる新宿・四谷・原宿・渋谷一帯の聖地巡礼スポットをめぐります。",
        imageAssetName: "OldMap_KiminonaSeichi",
        southWest: CLLocationCoordinate2D(latitude: 35.6535, longitude: 139.6881),
        northEast: CLLocationCoordinate2D(latitude: 35.6985, longitude: 139.7433)
    )

    // ジブリ作品の聖地は三鷹・小金井・多摩・港区など東京都内に広く点在するため、
    // `goshikiFudo`と同様に広域を1枚でカバーする画像にしている。`kiminonaSeichi`と同じく、
    // 特定作品を再現しない、緑豊かな丘と大樹の完全オリジナルイラスト。
    static let ghibliSeichi = HistoricalOverlayMap(
        id: "ghibli-seichi",
        title: "ジブリ映画の聖地巡り",
        era: "現代（スタジオジブリ作品の聖地巡礼スポット）",
        summary: "三鷹の森ジブリ美術館や「耳をすませば」の聖蹟桜ヶ丘、「千と千尋の神隠し」の参考地とされる江戸東京たてもの園など、東京都内に点在するジブリ作品ゆかりのスポットをめぐります。",
        imageAssetName: "OldMap_GhibliSeichi",
        southWest: CLLocationCoordinate2D(latitude: 35.5439, longitude: 139.44),
        northEast: CLLocationCoordinate2D(latitude: 35.8112, longitude: 139.768)
    )

    // 「東京トイレット（Perfect Days）」も、`kiminonaSeichi`/`ghibliSeichi`と同じく
    // 実在の道路データ・建築デザインを再現しないオリジナルイラスト（渋谷区内に点在する
    // 「THE TOKYO TOILET」の各施設を、装飾的なピクトグラムのマーカーで示した冒険地図風）。
    static let tokyoToilet = HistoricalOverlayMap(
        id: "tokyo-toilet-perfect-days",
        title: "東京トイレット（Perfect Days）",
        era: "現代（映画『PERFECT DAYS』の聖地巡礼スポット）",
        summary: "世界的建築家・クリエイターが手がけた渋谷区内の公共トイレ群「THE TOKYO TOILET」。映画『PERFECT DAYS』の舞台としても知られる、恵比寿から幡ヶ谷・広尾にかけての各施設をめぐります。",
        imageAssetName: "OldMap_TokyoToilet",
        southWest: CLLocationCoordinate2D(latitude: 35.645, longitude: 139.663),
        northEast: CLLocationCoordinate2D(latitude: 35.678, longitude: 139.724)
    )

    // Europeリージョンの古地図。東京の実測図・古地図風画像とは異なり、
    // 各都市の旧市街の地形（運河環・島々・城壁など）を象った完全オリジナルイラストで、
    // 「御朱印」の代わりに紋章（クレスト）風のチェックポイントを集める体験にしている
    // （紋章の意匠は`HistoricSiteCatalog`各エントリの`crestSymbolName`/`crestTintHex`、
    // 実際の描画は`CrestBadgeCatalog`を参照）。
    static let amsterdam = HistoricalOverlayMap(
        id: "amsterdam-medieval",
        title: "アムステルダム旧市街（オランダ）",
        era: "中世〜17世紀（オランダ黄金時代）",
        summary: "ダム広場を中心に扇状に広がる運河環（グラフテンゴルデル）と、IJ湾から世界へ漕ぎ出したVOC（東インド会社）の記憶をたどる、オランダ黄金時代の古地図です。",
        imageAssetName: "OldMap_Amsterdam",
        southWest: CLLocationCoordinate2D(latitude: 52.36, longitude: 4.883),
        northEast: CLLocationCoordinate2D(latitude: 52.38, longitude: 4.916)
    )

    static let helsinki = HistoricalOverlayMap(
        id: "helsinki-old-town",
        title: "ヘルシンキ旧市街（フィンランド）",
        era: "18〜19世紀（スウェーデン統治末期〜ロシア帝政期）",
        summary: "ヴァンター川河口の開拓地から、元老院広場を中心とした新古典様式の街並みへ。海上要塞スオメンリンナと港の市場までをめぐります。",
        imageAssetName: "OldMap_Helsinki",
        southWest: CLLocationCoordinate2D(latitude: 60.141, longitude: 24.886),
        northEast: CLLocationCoordinate2D(latitude: 60.224, longitude: 25.053)
    )

    static let stockholm = HistoricalOverlayMap(
        id: "stockholm-old-town",
        title: "ストックホルム旧市街（スウェーデン）",
        era: "13世紀〜近世（ガムラスタン成立期）",
        summary: "メーラレン湖とバルト海が出会う島々に築かれた都。旧市街ガムラスタン・王家の眠るリッダーホルメン・王宮・造船の島をめぐります。",
        imageAssetName: "OldMap_Stockholm",
        southWest: CLLocationCoordinate2D(latitude: 59.317, longitude: 18.063),
        northEast: CLLocationCoordinate2D(latitude: 59.329, longitude: 18.089)
    )

    static let tallinn = HistoricalOverlayMap(
        id: "tallinn-old-town",
        title: "タリン旧市街（エストニア）",
        era: "13〜16世紀（ハンザ同盟の時代）",
        summary: "城壁と見張り塔に守られたハンザ同盟の商都。トームペアの丘・ヴィル門・聖オレフ教会・港を守る太っちょマルガレータ塔をめぐります。",
        imageAssetName: "OldMap_Tallinn",
        southWest: CLLocationCoordinate2D(latitude: 59.436, longitude: 24.736),
        northEast: CLLocationCoordinate2D(latitude: 59.444, longitude: 24.752)
    )

    // Europe（西ヨーロッパ）の古地図。OpenStreetMapのデータから、パリはアール・ヌーヴォー、
    // ロンドンはテューダー朝の様式で描いたオリジナル画像（`scripts/global_maps/render_world.py`）。
    static let paris = HistoricalOverlayMap(
        id: "paris-montmartre",
        title: "パリ・モンマルトル（芸術家の家めぐり）",
        era: "1900年頃（ベル・エポック）",
        summary: "ピカソ、ゴッホ、ルノワール、ロートレックらが暮らし、描いた丘の街。アトリエや名画の舞台となったダンスホール、キャバレーをめぐります。",
        imageAssetName: "OldMap_Paris",
        southWest: CLLocationCoordinate2D(latitude: 48.88, longitude: 2.329),
        northEast: CLLocationCoordinate2D(latitude: 48.892, longitude: 2.3472)
    )

    static let london = HistoricalOverlayMap(
        id: "london-shakespeare",
        title: "ロンドン（シェイクスピアの時代）",
        era: "1600年頃（エリザベス1世〜ジェームズ1世）",
        summary: "シェイクスピアが芝居を書き、演じたテムズ川のほとり。南岸の劇場街からロンドン橋、セント・ポール大聖堂、ロンドン塔までをめぐります。",
        imageAssetName: "OldMap_London",
        southWest: CLLocationCoordinate2D(latitude: 51.499, longitude: -0.108),
        northEast: CLLocationCoordinate2D(latitude: 51.5208, longitude: -0.073)
    )

    static let brussels = HistoricalOverlayMap(
        id: "brussels-1850",
        title: "ブリュッセル（ベルギー王国の心臓部）",
        era: "1850年頃（ベルギー独立から20年）",
        summary: "1830年の独立で生まれたベルギー王国の首都。ギルドハウスに囲まれたグランプラス、小便小僧、大聖堂、王宮、完成したばかりのアーケード、ギャルリ・サンチュベールをめぐります。",
        imageAssetName: "OldMap_Brussels",
        southWest: CLLocationCoordinate2D(latitude: 50.8335, longitude: 4.334),
        northEast: CLLocationCoordinate2D(latitude: 50.8525, longitude: 4.3641)
    )

    // Asia・Americaリージョンの古地図。OpenStreetMapの現在の地図データ（海岸線・水面・通り・建物・城壁）を
    // もとに、各地域の古地図の様式で描いたオリジナル画像（`scripts/global_maps/render_world.py`）。
    // 中国の都市は、端末のGPSと同じ世界測地系（WGS84）の座標で描いている。
    static let beijing = HistoricalOverlayMap(
        id: "beijing-qing",
        title: "北京・紫禁城と内城（清代）",
        era: "清代（18世紀・乾隆期）",
        summary: "明・清の皇帝の都。紫禁城を中心に、城壁で囲まれた内城と外城に胡同（路地）が広がっていました。天壇・景山・鐘鼓楼までをめぐります。",
        imageAssetName: "OldMap_Beijing",
        southWest: CLLocationCoordinate2D(latitude: 39.862, longitude: 116.333),
        northEast: CLLocationCoordinate2D(latitude: 39.952, longitude: 116.45)
    )

    static let xian = HistoricalOverlayMap(
        id: "xian-changan",
        title: "西安・長安（明の西安府城）",
        era: "唐の長安〜明代（14〜17世紀）",
        summary: "シルクロードの起点として栄えた唐の都・長安。明代に築かれた周囲約14kmの城壁の中に、鐘楼と鼓楼が向かい合います。城外の大雁塔までをめぐります。",
        imageAssetName: "OldMap_Xian",
        southWest: CLLocationCoordinate2D(latitude: 34.212, longitude: 108.898),
        northEast: CLLocationCoordinate2D(latitude: 34.287, longitude: 108.9885)
    )

    static let lhasa = HistoricalOverlayMap(
        id: "lhasa-holy-city",
        title: "ラサ・ポタラ宮と聖都",
        era: "17〜18世紀（ダライ・ラマの時代）",
        summary: "標高約3,650mのチベットの聖都。マルポリの丘にそびえるポタラ宮と、巡礼者が集まるジョカン、バルコルの巡礼路、夏の離宮ノルブリンカをめぐります。",
        imageAssetName: "OldMap_Lhasa",
        southWest: CLLocationCoordinate2D(latitude: 29.632, longitude: 91.086),
        northEast: CLLocationCoordinate2D(latitude: 29.679, longitude: 91.14)
    )

    static let angkor = HistoricalOverlayMap(
        id: "angkor-yasodharapura",
        title: "アンコール（クメール王朝の都）",
        era: "9〜15世紀（クメール王朝）",
        summary: "密林の中に環濠と寺院が広がる、クメール王朝の都ヤショダラプラ。アンコール・ワットから城壁都市アンコール・トム、タ・プロームまでをめぐります。",
        imageAssetName: "OldMap_Angkor",
        southWest: CLLocationCoordinate2D(latitude: 13.404, longitude: 103.848),
        northEast: CLLocationCoordinate2D(latitude: 13.447, longitude: 103.8923)
    )

    static let delhi = HistoricalOverlayMap(
        id: "delhi-shahjahanabad",
        title: "デリー・シャージャハーナーバード（ムガル帝国）",
        era: "17〜18世紀（ムガル帝国）",
        summary: "ムガル皇帝シャー・ジャハーンが築いた城壁都市。赤い城から目抜き通りチャンドニー・チョーク、ジャーマー・マスジド、北のカシミール門までをめぐります。",
        imageAssetName: "OldMap_Delhi",
        southWest: CLLocationCoordinate2D(latitude: 28.64, longitude: 77.215),
        northEast: CLLocationCoordinate2D(latitude: 28.672, longitude: 77.2515)
    )

    static let isfahan = HistoricalOverlayMap(
        id: "isfahan-safavid",
        title: "イスファハーン（ペルシャ・サファヴィー朝）",
        era: "16〜17世紀（サファヴィー朝）",
        summary: "「イスファハーンは世界の半分」と称えられたペルシャの王都。青いタイルのモスクが囲む広場から、宮殿、ザーヤンデ川の橋、金曜モスクまでをめぐります。",
        imageAssetName: "OldMap_Isfahan",
        southWest: CLLocationCoordinate2D(latitude: 32.64, longitude: 51.656),
        northEast: CLLocationCoordinate2D(latitude: 32.674, longitude: 51.6965)
    )

    static let jerusalem = HistoricalOverlayMap(
        id: "jerusalem-old-city",
        title: "エルサレム旧市街",
        era: "16世紀〜（オスマン帝国の城壁）",
        summary: "オスマン帝国のスレイマン1世が築いた城壁に囲まれた、ユダヤ教・キリスト教・イスラームの聖地。城門と聖所をめぐります。",
        imageAssetName: "OldMap_Jerusalem",
        southWest: CLLocationCoordinate2D(latitude: 31.767, longitude: 35.2185),
        northEast: CLLocationCoordinate2D(latitude: 31.789, longitude: 35.2444)
    )

    static let boston = HistoricalOverlayMap(
        id: "boston-colonial",
        title: "ボストン（独立戦争の時代）",
        era: "18世紀（1775年頃）",
        summary: "アメリカ独立革命の舞台となった港町。レンガの道「フリーダム・トレイル」に沿って、議事堂・集会所・教会をめぐります。",
        imageAssetName: "OldMap_Boston",
        southWest: CLLocationCoordinate2D(latitude: 42.348, longitude: -71.0745),
        northEast: CLLocationCoordinate2D(latitude: 42.372, longitude: -71.042)
    )

    static let newYork = HistoricalOverlayMap(
        id: "newyork-new-amsterdam",
        title: "ニューヨーク（ニューアムステルダム）",
        era: "17〜18世紀（オランダ・英国植民地）",
        summary: "オランダの植民地ニューアムステルダムとして始まったマンハッタン南端。砦の跡からウォール街、初代大統領の就任の地、市庁舎までをめぐります。",
        imageAssetName: "OldMap_NewYork",
        southWest: CLLocationCoordinate2D(latitude: 40.698, longitude: -74.024),
        northEast: CLLocationCoordinate2D(latitude: 40.718, longitude: -73.9977)
    )

    static let mexicoCity = HistoricalOverlayMap(
        id: "mexico-tenochtitlan",
        title: "メキシコシティ（テノチティトランの跡）",
        era: "14〜17世紀（アステカ〜スペイン植民地）",
        summary: "湖上の都テノチティトランの上に築かれたスペイン植民地の首都。大広場ソカロ、大聖堂、アステカの大神殿の遺跡をめぐります。",
        imageAssetName: "OldMap_Mexico",
        southWest: CLLocationCoordinate2D(latitude: 19.425, longitude: -99.1478),
        northEast: CLLocationCoordinate2D(latitude: 19.445, longitude: -99.1266)
    )

    static let cusco = HistoricalOverlayMap(
        id: "cusco-inca",
        title: "クスコ（インカ帝国の都）",
        era: "15〜17世紀（インカ〜スペイン植民地）",
        summary: "標高約3,400mのインカ帝国の都。インカの石組みの上にスペインの教会が建つ街を、広場・太陽の神殿・丘の上の城塞までめぐります。",
        imageAssetName: "OldMap_Cusco",
        southWest: CLLocationCoordinate2D(latitude: -13.527, longitude: -71.9895),
        northEast: CLLocationCoordinate2D(latitude: -13.504, longitude: -71.9659)
    )

    static let buenosAires = HistoricalOverlayMap(
        id: "buenosaires-colonial",
        title: "ブエノスアイレス（植民地時代の港町）",
        era: "18〜19世紀（スペイン植民地〜独立）",
        summary: "ラ・プラタ川の港町として栄えたスペイン植民地の都。五月革命の広場から、石畳のサン・テルモ、コロン劇場、オベリスコまでをめぐります。",
        imageAssetName: "OldMap_BuenosAires",
        southWest: CLLocationCoordinate2D(latitude: -34.626, longitude: -58.389),
        northEast: CLLocationCoordinate2D(latitude: -34.597, longitude: -58.354)
    )

    /// 選択可能な古地図の一覧（`catalog/old_maps.json`の順）。
    static let all: [HistoricalOverlayMap] = [
        edoCastle,
        asakusa,
        meijiWriters,
        nihonbashi,
        goshikiFudo,
        bashoOkuNoHosomichi,
        akasakaKioicho,
        tokaido,
        nakasendo,
        ginzaKabukiza,
        oyamaKaido,
        kiminonaSeichi,
        ghibliSeichi,
        tokyoToilet,
        amsterdam,
        helsinki,
        stockholm,
        tallinn,
        paris,
        london,
        brussels,
        beijing,
        xian,
        lhasa,
        angkor,
        delhi,
        isfahan,
        jerusalem,
        boston,
        newYork,
        mexicoCity,
        cusco,
        buenosAires,
    ]

    /// 古地図の分類（古地図選択シートのセクション分け）。同梱リストにない古地図は分類なし。
    static let categoryByID: [String: Category] = [
        "edo-castle-1850s": .historicSites,
        "asakusa-edo": .historicSites,
        "meiji-writers": .historicSites,
        "nihonbashi-edo": .historicSites,
        "goshiki-fudo-meiji": .kaido,
        "basho-oku-no-hosomichi-meiji": .kaido,
        "akasaka-kioicho-meiji": .historicSites,
        "tokaido-edo": .kaido,
        "nakasendo-edo": .kaido,
        "ginza-kabukiza": .historicSites,
        "oyama-kaido": .kaido,
        "kiminona-seichi": .animePilgrimage,
        "ghibli-seichi": .animePilgrimage,
        "tokyo-toilet-perfect-days": .animePilgrimage,
        "amsterdam-medieval": .oldTowns,
        "helsinki-old-town": .oldTowns,
        "stockholm-old-town": .oldTowns,
        "tallinn-old-town": .oldTowns,
        "paris-montmartre": .westernEurope,
        "london-shakespeare": .westernEurope,
        "brussels-1850": .westernEurope,
        "beijing-qing": .ancientCapitals,
        "xian-changan": .ancientCapitals,
        "lhasa-holy-city": .ancientCapitals,
        "angkor-yasodharapura": .ancientCapitals,
        "delhi-shahjahanabad": .ancientCapitals,
        "isfahan-safavid": .ancientCapitals,
        "jerusalem-old-city": .ancientCapitals,
        "boston-colonial": .colonialCities,
        "newyork-new-amsterdam": .colonialCities,
        "mexico-tenochtitlan": .colonialCities,
        "cusco-inca": .colonialCities,
        "buenosaires-colonial": .colonialCities,
    ]

    /// 統合によって廃止されたID → 統合先IDの対応表。過去の記録に残る廃止IDを表示時に読み替える。
    static let mergedIntoID: [String: String] = [
        "ueno-edo": "meiji-writers",
        "shiba-edo": "tokaido-edo",
        "kanda-edo": "nihonbashi-edo",
        "roppongi-meiji": "akasaka-kioicho-meiji",
        "kasumigaseki-toranomon-meiji": "edo-castle-1850s",
        "kudanshita-chidorigafuchi-meiji": "edo-castle-1850s",
        "meiji-jingu-omotesando-meiji": "oyama-kaido",
        "kagurazaka-waseda-shinjuku-meiji": "kiminona-seichi",
        "E28E96A1-8694-42B7-A17B-A4811D4D1954": "brussels-1850",
    ]
}
