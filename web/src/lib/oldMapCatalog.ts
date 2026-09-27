/**
 * iOS側の `Komap/Models/HistoricalOverlayMap.swift` と対になる古地図カタログ。
 * Web側では地点・時間旅に紐づく古地図の「タイトル・時代」をラベル表示するほか、
 * 時空旅の地図（`TripMapView`）に古地図の画像を重ねて表示するために使う。
 */
export interface OldMapEntry {
  id: string;
  title: string;
  era: string;
  /** `web/public/old-maps/` 内の画像パス。統合済みで画像を持たない古い古地図IDはundefined。 */
  imageUrl?: string;
  southWest?: { lat: number; lng: number };
  northEast?: { lat: number; lng: number };
  /**
   * 画像の「上」が指す方角（真北から時計回りの度数）。0以外は現状`goshiki-fudo-meiji`のみ。
   * Google Maps JavaScript APIの`GroundOverlay`は回転をサポートしないため、Web版では
   * この値があっても画像は回転させずに表示する（iOS版とは見た目が異なる点に注意）。
   */
  bearing?: number;
}

export const OLD_MAP_CATALOG: OldMapEntry[] = [
  {
    id: "edo-castle-1850s",
    title: "江戸城周辺（安政期）",
    era: "江戸時代後期（1850年代・安政期）",
    imageUrl: "/old-maps/old_map_edo_castle.jpg",
    southWest: { lat: 35.6653, lng: 139.74 },
    northEast: { lat: 35.696, lng: 139.767 },
  },
  {
    id: "asakusa-edo",
    title: "浅草・浅草寺周辺（江戸時代）",
    era: "江戸時代（浅草寺門前町が賑わった時期）",
    imageUrl: "/old-maps/old_map_asakusa.jpg",
    southWest: { lat: 35.708, lng: 139.788 },
    northEast: { lat: 35.723, lng: 139.806 },
  },
  {
    id: "meiji-writers",
    title: "明治の文豪（本郷・上野）",
    era: "明治時代（1891年・明治24年頃）",
    imageUrl: "/old-maps/old_map_meiji_writers.jpg",
    southWest: { lat: 35.6929, lng: 139.7484 },
    northEast: { lat: 35.7395, lng: 139.7984 },
  },
  {
    id: "nihonbashi-edo",
    title: "日本橋・神田明神",
    era: "明治時代（1891年・明治24年頃）",
    imageUrl: "/old-maps/old_map_nihonbashi.jpg",
    southWest: { lat: 35.6638, lng: 139.7505 },
    northEast: { lat: 35.7166, lng: 139.7929 },
  },
  {
    // iOS版と同じく、日本橋と同じ画像・位置合わせのまま範囲を南へ広げている。
    id: "ginza-kabukiza",
    title: "銀座・歌舞伎座",
    era: "明治時代（1891年・明治24年頃）",
    imageUrl: "/old-maps/old_map_nihonbashi.jpg",
    southWest: { lat: 35.652, lng: 139.7505 },
    northEast: { lat: 35.7166, lng: 139.7929 },
  },
  {
    id: "goshiki-fudo-meiji",
    title: "五色不動めぐり（目黒・目白・目赤・目青・目黄）",
    era: "明治時代（1891年・明治24年頃）",
    imageUrl: "/old-maps/old_map_tokyo_meiji1891.jpg",
    southWest: { lat: 35.63735, lng: 139.71808 },
    northEast: { lat: 35.72185, lng: 139.82213 },
    bearing: 325.0,
  },
  {
    id: "basho-oku-no-hosomichi-meiji",
    title: "松尾芭蕉ゆかりの地（深川〜千住）",
    era: "明治時代（1891年・明治24年頃）",
    imageUrl: "/old-maps/old_map_basho_oku_no_hosomichi.jpg",
    // 画像が正方形（内容は横幅の半分弱、左右が余白）のため、iOS版と同様に
    // 東西の範囲を正方形になるまで広げ、縦方向への引き伸ばしを解消している。
    southWest: { lat: 35.6531, lng: 139.713 },
    northEast: { lat: 35.755, lng: 139.838 },
  },
  {
    id: "akasaka-kioicho-meiji",
    title: "赤坂・紀尾井町・六本木",
    era: "古地図風（現在の地図をもとに加工）",
    imageUrl: "/old-maps/old_map_akasaka_kioicho.jpg",
    southWest: { lat: 35.64769, lng: 139.72203 },
    northEast: { lat: 35.69024, lng: 139.74098 },
  },
  {
    id: "tokaido-edo",
    title: "東海道（日本橋・芝増上寺・品川）",
    era: "江戸時代（五街道が整備された時期）",
    imageUrl: "/old-maps/old_map_shiba.jpg",
    southWest: { lat: 35.5865, lng: 139.7262 },
    northEast: { lat: 35.6835, lng: 139.7742 },
  },
  {
    id: "nakasendo-edo",
    title: "中山道（本郷〜小石川・巣鴨）",
    era: "江戸時代（五街道が整備された時期）",
    imageUrl: "/old-maps/old_map_nakasendo.jpg",
    southWest: { lat: 35.68, lng: 139.7 },
    northEast: { lat: 35.755, lng: 139.79 },
  },
  {
    id: "oyama-kaido",
    title: "大山街道（赤坂〜明治神宮〜二子）",
    era: "古地図風（現在の地図をもとに加工）",
    imageUrl: "/old-maps/old_map_oyama_kaido.jpg",
    southWest: { lat: 35.585851593232356, lng: 139.6142578125 },
    northEast: { lat: 35.6929946320988, lng: 139.74609375 },
  },
  {
    id: "kiminona-seichi",
    title: "「君の名は。」聖地巡礼",
    era: "現代（映画『君の名は。』の聖地巡礼スポット）",
    imageUrl: "/old-maps/old_map_kiminona_seichi.jpg",
    southWest: { lat: 35.6535, lng: 139.6881 },
    northEast: { lat: 35.6985, lng: 139.7433 },
  },
  {
    id: "ghibli-seichi",
    title: "ジブリ映画の聖地巡り",
    era: "現代（スタジオジブリ作品の聖地巡礼スポット）",
    imageUrl: "/old-maps/old_map_ghibli_seichi.jpg",
    southWest: { lat: 35.5439, lng: 139.44 },
    northEast: { lat: 35.8112, lng: 139.768 },
  },
  {
    id: "tokyo-toilet-perfect-days",
    title: "東京トイレット（Perfect Days）",
    era: "現代（映画『PERFECT DAYS』の聖地巡礼スポット）",
    imageUrl: "/old-maps/old_map_tokyo_toilet.jpg",
    southWest: { lat: 35.645, lng: 139.663 },
    northEast: { lat: 35.678, lng: 139.724 },
  },

  // Komap Global（東京版とは別の、海外都市の旧市街コース）
  {
    id: "amsterdam-medieval",
    title: "アムステルダム旧市街（オランダ）",
    era: "中世〜17世紀（オランダ黄金時代）",
    imageUrl: "/old-maps/old_map_amsterdam.jpg",
    southWest: { lat: 52.36, lng: 4.883 },
    northEast: { lat: 52.38, lng: 4.916 },
  },
  {
    id: "helsinki-old-town",
    title: "ヘルシンキ旧市街（フィンランド）",
    era: "18〜19世紀（スウェーデン統治末期〜ロシア帝政期）",
    imageUrl: "/old-maps/old_map_helsinki.jpg",
    southWest: { lat: 60.141, lng: 24.886 },
    northEast: { lat: 60.224, lng: 25.053 },
  },
  {
    id: "stockholm-old-town",
    title: "ストックホルム旧市街（スウェーデン）",
    era: "13世紀〜近世（ガムラスタン成立期）",
    imageUrl: "/old-maps/old_map_stockholm.jpg",
    southWest: { lat: 59.317, lng: 18.063 },
    northEast: { lat: 59.329, lng: 18.089 },
  },
  {
    id: "tallinn-old-town",
    title: "タリン旧市街（エストニア）",
    era: "13〜16世紀（ハンザ同盟の時代）",
    imageUrl: "/old-maps/old_map_tallinn.jpg",
    southWest: { lat: 59.436, lng: 24.736 },
    northEast: { lat: 59.444, lng: 24.752 },
  },
  // Europe（西ヨーロッパ）
  {
    id: "paris-montmartre",
    title: "パリ・モンマルトル（芸術家の家めぐり）",
    era: "1900年頃（ベル・エポック）",
    imageUrl: "/old-maps/old_map_paris.jpg",
    southWest: { lat: 48.88, lng: 2.329 },
    northEast: { lat: 48.892, lng: 2.3472 },
  },
  {
    id: "london-shakespeare",
    title: "ロンドン（シェイクスピアの時代）",
    era: "1600年頃（エリザベス1世〜ジェームズ1世）",
    imageUrl: "/old-maps/old_map_london.jpg",
    southWest: { lat: 51.499, lng: -0.108 },
    northEast: { lat: 51.5208, lng: -0.073 },
  },
  // Asia・America（OpenStreetMapをもとに各地域の古地図の様式で描いたオリジナル画像）
  {
    id: "beijing-qing",
    title: "北京・紫禁城と内城（清代）",
    era: "清代（18世紀・乾隆期）",
    imageUrl: "/old-maps/old_map_beijing.jpg",
    southWest: { lat: 39.862, lng: 116.333 },
    northEast: { lat: 39.952, lng: 116.45 },
  },
  {
    id: "xian-changan",
    title: "西安・長安（明の西安府城）",
    era: "唐の長安〜明代（14〜17世紀）",
    imageUrl: "/old-maps/old_map_xian.jpg",
    southWest: { lat: 34.212, lng: 108.898 },
    northEast: { lat: 34.287, lng: 108.9885 },
  },
  {
    id: "lhasa-holy-city",
    title: "ラサ・ポタラ宮と聖都",
    era: "17〜18世紀（ダライ・ラマの時代）",
    imageUrl: "/old-maps/old_map_lhasa.jpg",
    southWest: { lat: 29.632, lng: 91.086 },
    northEast: { lat: 29.679, lng: 91.14 },
  },
  {
    id: "angkor-yasodharapura",
    title: "アンコール（クメール王朝の都）",
    era: "9〜15世紀（クメール王朝）",
    imageUrl: "/old-maps/old_map_angkor.jpg",
    southWest: { lat: 13.404, lng: 103.848 },
    northEast: { lat: 13.447, lng: 103.8923 },
  },
  {
    id: "delhi-shahjahanabad",
    title: "デリー・シャージャハーナーバード（ムガル帝国）",
    era: "17〜18世紀（ムガル帝国）",
    imageUrl: "/old-maps/old_map_delhi.jpg",
    southWest: { lat: 28.64, lng: 77.215 },
    northEast: { lat: 28.672, lng: 77.2515 },
  },
  {
    id: "isfahan-safavid",
    title: "イスファハーン（ペルシャ・サファヴィー朝）",
    era: "16〜17世紀（サファヴィー朝）",
    imageUrl: "/old-maps/old_map_isfahan.jpg",
    southWest: { lat: 32.64, lng: 51.656 },
    northEast: { lat: 32.674, lng: 51.6965 },
  },
  {
    id: "jerusalem-old-city",
    title: "エルサレム旧市街",
    era: "16世紀〜（オスマン帝国の城壁）",
    imageUrl: "/old-maps/old_map_jerusalem.jpg",
    southWest: { lat: 31.767, lng: 35.2185 },
    northEast: { lat: 31.789, lng: 35.2444 },
  },
  {
    id: "boston-colonial",
    title: "ボストン（独立戦争の時代）",
    era: "18世紀（1775年頃）",
    imageUrl: "/old-maps/old_map_boston.jpg",
    southWest: { lat: 42.348, lng: -71.0745 },
    northEast: { lat: 42.372, lng: -71.042 },
  },
  {
    id: "newyork-new-amsterdam",
    title: "ニューヨーク（ニューアムステルダム）",
    era: "17〜18世紀（オランダ・英国植民地）",
    imageUrl: "/old-maps/old_map_newyork.jpg",
    southWest: { lat: 40.698, lng: -74.024 },
    northEast: { lat: 40.718, lng: -73.9977 },
  },
  {
    id: "mexico-tenochtitlan",
    title: "メキシコシティ（テノチティトランの跡）",
    era: "14〜17世紀（アステカ〜スペイン植民地）",
    imageUrl: "/old-maps/old_map_mexico.jpg",
    southWest: { lat: 19.425, lng: -99.1478 },
    northEast: { lat: 19.445, lng: -99.1266 },
  },
  {
    id: "cusco-inca",
    title: "クスコ（インカ帝国の都）",
    era: "15〜17世紀（インカ〜スペイン植民地）",
    imageUrl: "/old-maps/old_map_cusco.jpg",
    southWest: { lat: -13.527, lng: -71.9895 },
    northEast: { lat: -13.504, lng: -71.9659 },
  },
  {
    id: "buenosaires-colonial",
    title: "ブエノスアイレス（植民地時代の港町）",
    era: "18〜19世紀（スペイン植民地〜独立）",
    imageUrl: "/old-maps/old_map_buenosaires.jpg",
    southWest: { lat: -34.626, lng: -58.389 },
    northEast: { lat: -34.597, lng: -58.354 },
  },
];

/**
 * 統合済みで現在は選べない古い古地図IDを、統合先の古地図IDへ読み替える表。
 * 過去の時空旅・保存した地点は統合前のIDのまま記録されているため、
 * `findOldMap`で解決する際にここを通して統合先の古地図（タイトル・画像とも）に
 * 差し替える（iOS側の`HistoricalOverlayMap.swift`の統合履歴と対応）。
 */
const MERGED_INTO: Record<string, string> = {
  "ueno-edo": "meiji-writers",
  "shiba-edo": "tokaido-edo",
  "kanda-edo": "nihonbashi-edo",
  "roppongi-meiji": "akasaka-kioicho-meiji",
  "kasumigaseki-toranomon-meiji": "edo-castle-1850s",
  "kudanshita-chidorigafuchi-meiji": "edo-castle-1850s",
  "meiji-jingu-omotesando-meiji": "oyama-kaido",
  "kagurazaka-waseda-shinjuku-meiji": "kiminona-seichi",
};

// 一覧の各行から呼ばれるため、毎回全件を順に探さないよう索引を一度だけ作る。
const OLD_MAP_BY_ID = new Map(OLD_MAP_CATALOG.map((entry) => [entry.id, entry]));

export function findOldMap(id: string | null): OldMapEntry | undefined {
  if (!id) return undefined;
  const resolvedId = MERGED_INTO[id] ?? id;
  return OLD_MAP_BY_ID.get(resolvedId);
}
