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
  // 以下は古地図としては統合済みで新規には選べないが、統合前にこのIDで
  // 記録された過去の時間旅・地点のラベル表示のため、引き続き残している
  // （画像は統合先に一本化したため、ここには持たせていない）。
  {
    id: "ueno-edo",
    title: "上野（寛永寺・不忍池周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "nihonbashi-edo",
    title: "日本橋・神田明神",
    era: "明治時代（1891年・明治24年頃）",
    imageUrl: "/old-maps/old_map_nihonbashi.jpg",
    southWest: { lat: 35.6638, lng: 139.7505 },
    northEast: { lat: 35.7166, lng: 139.7929 },
  },
  // 「東海道」に統合済み（下記と同じ理由でIDは残す）
  {
    id: "shiba-edo",
    title: "芝（増上寺周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  // 「日本橋・神田明神」に統合済み（下記と同じ理由でIDは残す）
  {
    id: "kanda-edo",
    title: "神田（神田明神周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  // 「赤坂・紀尾井町・六本木」に統合済み（下記と同じ理由でIDは残す）
  {
    id: "roppongi-meiji",
    title: "麻布・六本木周辺",
    era: "古地図風（現在の地図をもとに加工）",
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
    southWest: { lat: 35.6531, lng: 139.7543 },
    northEast: { lat: 35.755, lng: 139.7967 },
  },
  // 「江戸城周辺（安政期）」に統合済み（下記と同じ理由でIDは残す）
  {
    id: "kasumigaseki-toranomon-meiji",
    title: "霞ヶ関・虎ノ門（大名屋敷と社寺）",
    era: "明治時代（1891年・明治24年頃）",
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
  // 「江戸城周辺（安政期）」に統合済み（下記と同じ理由でIDは残す）
  {
    id: "kudanshita-chidorigafuchi-meiji",
    title: "九段下・千鳥ヶ淵（靖国神社周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "meiji-jingu-omotesando-meiji",
    title: "明治神宮・表参道・神宮外苑",
    era: "明治時代（1891年・明治24年頃、社殿創建前の代々木御料地一帯）",
    imageUrl: "/old-maps/old_map_meijijingu_omotesando.jpg",
    southWest: { lat: 35.65776, lng: 139.69495 },
    northEast: { lat: 35.68296, lng: 139.73031 },
  },
  {
    id: "oyama-kaido",
    title: "大山街道（赤坂〜二子玉川）",
    era: "古地図風（現在の地図をもとに加工）",
    imageUrl: "/old-maps/old_map_oyama_kaido.jpg",
    southWest: { lat: 35.585851593232356, lng: 139.6142578125 },
    northEast: { lat: 35.6929946320988, lng: 139.74609375 },
  },
  {
    id: "kagurazaka-waseda-shinjuku-meiji",
    title: "神楽坂・早稲田・新宿",
    era: "古地図風（現在の地図をもとに加工）",
    imageUrl: "/old-maps/old_map_kagurazaka_waseda_shinjuku.jpg",
    southWest: { lat: 35.685, lng: 139.696 },
    northEast: { lat: 35.712, lng: 139.744 },
  },
];

export function findOldMap(id: string | null): OldMapEntry | undefined {
  if (!id) return undefined;
  return OLD_MAP_CATALOG.find((entry) => entry.id === id);
}
