/**
 * iOS側の `Komap/Models/HistoricSite.swift` と対になる史跡チェックポイントの一覧。
 * Web側では御朱印（siteID）に紐づく史跡名をラベル表示するほか、時空旅の地図
 * （`TripMapView`）にチェックポイントのマーカーを重ねて表示するために使う。
 */
export interface HistoricSiteEntry {
  id: string;
  name: string;
  /** この史跡が属する古地図（`OldMapEntry.id`）。 */
  overlayMapID: string;
  coordinate: { lat: number; lng: number };
}

export const HISTORIC_SITE_CATALOG: HistoricSiteEntry[] = [
  { id: "edo-castle-sakuradamon", name: "桜田門", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6773, lng: 139.7539 } },
  { id: "edo-castle-wadakuramon", name: "和田倉門", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6822, lng: 139.7565 } },
  { id: "edo-castle-nijubashi", name: "二重橋", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6825, lng: 139.7528 } },
  { id: "edo-castle-otemon", name: "大手門", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6873, lng: 139.7565 } },
  { id: "asakusa-kaminarimon", name: "雷門", overlayMapID: "asakusa-edo", coordinate: { lat: 35.7107, lng: 139.7964 } },
  { id: "asakusa-nakamise", name: "仲見世通り", overlayMapID: "asakusa-edo", coordinate: { lat: 35.7115, lng: 139.7967 } },
  { id: "asakusa-sensoji", name: "浅草寺本堂", overlayMapID: "asakusa-edo", coordinate: { lat: 35.7148, lng: 139.7967 } },
  { id: "asakusa-gojunoto", name: "五重塔", overlayMapID: "asakusa-edo", coordinate: { lat: 35.7143, lng: 139.7960 } },
  { id: "asakusa-hanayashiki", name: "花やしき", overlayMapID: "asakusa-edo", coordinate: { lat: 35.7157, lng: 139.7943 } },
  { id: "writers-ogai", name: "森鴎外の家（観潮楼跡）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7217, lng: 139.7663 } },
  { id: "writers-soseki", name: "夏目漱石旧居跡（猫の家）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7215, lng: 139.7654 } },
  { id: "writers-ichiyo", name: "樋口一葉旧居跡", overlayMapID: "meiji-writers", coordinate: { lat: 35.7106, lng: 139.7595 } },
  { id: "writers-takuboku", name: "石川啄木の旧居", overlayMapID: "meiji-writers", coordinate: { lat: 35.7108, lng: 139.7597 } },
  { id: "ueno-bentendo", name: "不忍池辯天堂", overlayMapID: "meiji-writers", coordinate: { lat: 35.7139, lng: 139.7717 } },
  { id: "ueno-toshogu", name: "上野東照宮", overlayMapID: "meiji-writers", coordinate: { lat: 35.7161, lng: 139.7724 } },
  { id: "nihonbashi-mitsukoshi", name: "三越日本橋本店", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.6852, lng: 139.7734 } },
  { id: "nihonbashi-uoichiba", name: "日本橋魚市場発祥の地", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.6837, lng: 139.7738 } },
  { id: "nihonbashi-boj", name: "日本銀行本店", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.6862, lng: 139.7745 } },
  { id: "nihonbashi-edobashi", name: "江戸橋", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.6820, lng: 139.7758 } },
  { id: "shiba-zojoji", name: "増上寺・芝東照宮", overlayMapID: "tokaido-edo", coordinate: { lat: 35.6572, lng: 139.7492 } },
  { id: "kanda-myojin-checkpoint", name: "神田明神", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.7020, lng: 139.7671 } },
  { id: "kanda-seido", name: "湯島聖堂", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.7009, lng: 139.7659 } },
  { id: "kanda-nikolai-do", name: "ニコライ堂", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.6976, lng: 139.7644 } },
  { id: "kanda-shohei-bridge", name: "昌平橋", overlayMapID: "nihonbashi-edo", coordinate: { lat: 35.6989, lng: 139.7659 } },
  { id: "yanaka7-tokakuji", name: "東覚寺（福禄寿）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7355, lng: 139.7585 } },
  { id: "yanaka7-seiunji", name: "青雲寺（恵比寿）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7311, lng: 139.7660 } },
  { id: "yanaka7-shushoin", name: "修性院（布袋尊）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7301, lng: 139.7661 } },
  { id: "yanaka7-choanji", name: "長安寺（寿老人）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7252, lng: 139.7684 } },
  { id: "yanaka7-tennoji", name: "天王寺（毘沙門天）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7267, lng: 139.7712 } },
  { id: "yanaka7-gokokuin", name: "護国院（大黒天）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7193, lng: 139.7701 } },
  { id: "yanaka7-bentendo", name: "不忍池辯天堂（弁才天）", overlayMapID: "meiji-writers", coordinate: { lat: 35.7139, lng: 139.7717 } },
  { id: "goshiki-meguro", name: "目黒不動（瀧泉寺）", overlayMapID: "goshiki-fudo-meiji", coordinate: { lat: 35.6277, lng: 139.7083 } },
  { id: "goshiki-mejiro", name: "目白不動（金乗院）", overlayMapID: "goshiki-fudo-meiji", coordinate: { lat: 35.7163, lng: 139.7148 } },
  { id: "goshiki-meaka", name: "目赤不動（南谷寺）", overlayMapID: "goshiki-fudo-meiji", coordinate: { lat: 35.7262, lng: 139.7530 } },
  { id: "goshiki-meao", name: "目青不動（教学院）", overlayMapID: "goshiki-fudo-meiji", coordinate: { lat: 35.6445, lng: 139.6706 } },
  { id: "goshiki-meki", name: "目黄不動（永久寺）", overlayMapID: "goshiki-fudo-meiji", coordinate: { lat: 35.7275, lng: 139.7885 } },
  { id: "basho-fukagawa-an", name: "深川芭蕉庵跡", overlayMapID: "basho-oku-no-hosomichi-meiji", coordinate: { lat: 35.6822, lng: 139.8022 } },
  { id: "basho-kinenkan", name: "江東区芭蕉記念館", overlayMapID: "basho-oku-no-hosomichi-meiji", coordinate: { lat: 35.6809, lng: 139.8014 } },
  { id: "basho-saian", name: "采茶庵跡", overlayMapID: "basho-oku-no-hosomichi-meiji", coordinate: { lat: 35.6822, lng: 139.7989 } },
  { id: "basho-senju-ohashi", name: "千住大橋", overlayMapID: "basho-oku-no-hosomichi-meiji", coordinate: { lat: 35.7461, lng: 139.7986 } },
  { id: "basho-yatate-hajime", name: "矢立初めの地", overlayMapID: "basho-oku-no-hosomichi-meiji", coordinate: { lat: 35.7466, lng: 139.7983 } },
  { id: "basho-susanoo-shrine", name: "素盞雄神社", overlayMapID: "basho-oku-no-hosomichi-meiji", coordinate: { lat: 35.7458, lng: 139.7965 } },
  { id: "kasumigaseki-hibiya-park", name: "日比谷公園", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6740, lng: 139.7565 } },
  { id: "kasumigaseki-atago-shrine", name: "愛宕神社", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6653, lng: 139.7494 } },
  { id: "kasumigaseki-toranomon-kotohira", name: "虎ノ門金刀比羅宮", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6699, lng: 139.7497 } },
  { id: "kasumigaseki-tameike", name: "溜池跡", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6693, lng: 139.7413 } },
  { id: "akasaka-hikawa-shrine", name: "赤坂氷川神社", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6739, lng: 139.7362 } },
  { id: "akasaka-hie-shrine", name: "日枝神社", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6733, lng: 139.7392 } },
  { id: "kioicho-geihinkan", name: "迎賓館赤坂離宮（紀州藩邸跡）", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6797, lng: 139.7327 } },
  { id: "kioicho-sophia-univ", name: "上智大学（尾張藩邸跡）", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6857, lng: 139.7305 } },
  { id: "kioicho-new-otani", name: "ホテルニューオータニ（彦根藩井伊家邸跡）", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6788, lng: 139.7343 } },
  { id: "tokaido-nihonbashi", name: "日本橋", overlayMapID: "tokaido-edo", coordinate: { lat: 35.6835, lng: 139.7742 } },
  { id: "tokaido-takanawa-okido", name: "高輪大木戸跡", overlayMapID: "tokaido-edo", coordinate: { lat: 35.6335, lng: 139.7402 } },
  { id: "tokaido-sengakuji", name: "泉岳寺", overlayMapID: "tokaido-edo", coordinate: { lat: 35.6435, lng: 139.7385 } },
  { id: "tokaido-shinagawa-juku", name: "品川宿本陣跡", overlayMapID: "tokaido-edo", coordinate: { lat: 35.6247, lng: 139.7397 } },
  { id: "tokaido-suzugamori", name: "鈴ヶ森刑場跡", overlayMapID: "tokaido-edo", coordinate: { lat: 35.5865, lng: 139.7377 } },
  { id: "nakasendo-nihonbashi", name: "日本橋", overlayMapID: "nakasendo-edo", coordinate: { lat: 35.6835, lng: 139.7742 } },
  { id: "nakasendo-kanda-myojin", name: "神田明神", overlayMapID: "nakasendo-edo", coordinate: { lat: 35.7020, lng: 139.7671 } },
  { id: "nakasendo-hongo-oiwake", name: "本郷追分", overlayMapID: "nakasendo-edo", coordinate: { lat: 35.7183, lng: 139.7592 } },
  { id: "nakasendo-sugamo-koshinzuka", name: "巣鴨庚申塚", overlayMapID: "nakasendo-edo", coordinate: { lat: 35.7365, lng: 139.7325 } },
  { id: "nakasendo-itabashi-juku", name: "板橋宿本陣跡", overlayMapID: "nakasendo-edo", coordinate: { lat: 35.7513, lng: 139.7093 } },
  { id: "kudanshita-yasukuni-shrine", name: "靖国神社", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6938, lng: 139.7423 } },
  { id: "kudanshita-chidorigafuchi", name: "千鳥ヶ淵", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6913, lng: 139.7457 } },
  { id: "kudanshita-shimizumon", name: "清水門", overlayMapID: "edo-castle-1850s", coordinate: { lat: 35.6912, lng: 139.7508 } },
  { id: "roppongi-hills-mori-garden", name: "六本木ヒルズ（毛利庭園）", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6604, lng: 139.7292 } },
  { id: "roppongi-nogi-shrine", name: "乃木神社", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6667, lng: 139.7268 } },
  { id: "roppongi-azabudai", name: "麻布台（大名屋敷跡）", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6631, lng: 139.7395 } },
  { id: "roppongi-azabujuban", name: "麻布十番", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6558, lng: 139.7350 } },
  { id: "roppongi-arisugawa-park", name: "有栖川宮記念公園", overlayMapID: "akasaka-kioicho-meiji", coordinate: { lat: 35.6553, lng: 139.7236 } },
  { id: "meijijingu-shrine", name: "明治神宮", overlayMapID: "meiji-jingu-omotesando-meiji", coordinate: { lat: 35.6764, lng: 139.6993 } },
  { id: "meijijingu-harajuku-station", name: "原宿駅", overlayMapID: "meiji-jingu-omotesando-meiji", coordinate: { lat: 35.6702, lng: 139.7027 } },
  { id: "meijijingu-omotesando-hills", name: "表参道ヒルズ", overlayMapID: "meiji-jingu-omotesando-meiji", coordinate: { lat: 35.6672, lng: 139.7106 } },
  { id: "meijijingu-gaien-gallery", name: "聖徳記念絵画館", overlayMapID: "meiji-jingu-omotesando-meiji", coordinate: { lat: 35.6772, lng: 139.7193 } },
  { id: "oyamakaido-akasaka", name: "赤坂見附", overlayMapID: "oyama-kaido", coordinate: { lat: 35.6775, lng: 139.7370 } },
  { id: "oyamakaido-aoyama", name: "青山（青山通り）", overlayMapID: "oyama-kaido", coordinate: { lat: 35.6725, lng: 139.7256 } },
  { id: "oyamakaido-shibuya-dogenzaka", name: "渋谷・道玄坂", overlayMapID: "oyama-kaido", coordinate: { lat: 35.6580, lng: 139.6975 } },
  { id: "oyamakaido-sangenjaya", name: "三軒茶屋（大山道の追分）", overlayMapID: "oyama-kaido", coordinate: { lat: 35.6438, lng: 139.6708 } },
  { id: "oyamakaido-komazawa", name: "駒沢", overlayMapID: "oyama-kaido", coordinate: { lat: 35.6252, lng: 139.6553 } },
  { id: "oyamakaido-youga", name: "用賀", overlayMapID: "oyama-kaido", coordinate: { lat: 35.6229, lng: 139.6321 } },
  { id: "oyamakaido-futakotamagawa", name: "二子玉川（多摩川の渡し）", overlayMapID: "oyama-kaido", coordinate: { lat: 35.6099, lng: 139.6262 } },
  { id: "kws-hanazono-shrine", name: "花園神社", overlayMapID: "kagurazaka-waseda-shinjuku-meiji", coordinate: { lat: 35.6931, lng: 139.7043 } },
  { id: "kws-waseda-okuma", name: "早稲田大学 大隈講堂", overlayMapID: "kagurazaka-waseda-shinjuku-meiji", coordinate: { lat: 35.7089, lng: 139.7197 } },
  { id: "kws-anahachimangu", name: "穴八幡宮", overlayMapID: "kagurazaka-waseda-shinjuku-meiji", coordinate: { lat: 35.7078, lng: 139.7213 } },
  { id: "kws-kagurazaka-zenkokuji", name: "神楽坂・毘沙門天善國寺", overlayMapID: "kagurazaka-waseda-shinjuku-meiji", coordinate: { lat: 35.7017, lng: 139.7397 } },
  { id: "kiminona-suga-shrine", name: "須賀神社", overlayMapID: "kiminona-seichi", coordinate: { lat: 35.6863, lng: 139.7217 } },
  { id: "kiminona-yotsuya-station", name: "四ツ谷駅", overlayMapID: "kiminona-seichi", coordinate: { lat: 35.6858, lng: 139.7305 } },
  { id: "kiminona-docomo-tower", name: "ドコモタワー（NTTドコモ代々木ビル）", overlayMapID: "kiminona-seichi", coordinate: { lat: 35.6844, lng: 139.7031 } },
  { id: "kiminona-busta-shinjuku", name: "バスタ新宿", overlayMapID: "kiminona-seichi", coordinate: { lat: 35.6886, lng: 139.7008 } },
  { id: "kiminona-cafe-la-boheme", name: "カフェ・ラ・ボエム（新宿御苑店）", overlayMapID: "kiminona-seichi", coordinate: { lat: 35.6903, lng: 139.7154 } },
  { id: "kiminona-shibuya-tsutaya", name: "SHIBUYA TSUTAYA", overlayMapID: "kiminona-seichi", coordinate: { lat: 35.6597, lng: 139.7016 } },
];

export function findHistoricSite(id: string | null): HistoricSiteEntry | undefined {
  if (!id) return undefined;
  return HISTORIC_SITE_CATALOG.find((entry) => entry.id === id);
}

/** 指定した古地図に属するチェックポイントだけを返す（`overlayMapID`が`null`なら空配列）。 */
export function sitesForOverlay(overlayMapID: string | null): HistoricSiteEntry[] {
  if (!overlayMapID) return [];
  return HISTORIC_SITE_CATALOG.filter((entry) => entry.overlayMapID === overlayMapID);
}
