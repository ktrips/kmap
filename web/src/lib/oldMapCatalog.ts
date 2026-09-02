/**
 * iOS側の `Komap/Models/HistoricalOverlayMap.swift` と対になる古地図カタログ。
 * Web側では地点・時間旅に紐づく古地図の「タイトル・時代」をラベル表示するために使う。
 */
export interface OldMapEntry {
  id: string;
  title: string;
  era: string;
}

export const OLD_MAP_CATALOG: OldMapEntry[] = [
  {
    id: "edo-castle-1850s",
    title: "江戸城周辺（安政期）",
    era: "江戸時代後期（1850年代・安政期）",
  },
  {
    id: "asakusa-edo",
    title: "浅草・浅草寺周辺（江戸時代）",
    era: "江戸時代（浅草寺門前町が賑わった時期）",
  },
  {
    id: "meiji-writers",
    title: "明治の文豪の家（本郷・谷中）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "ueno-edo",
    title: "上野（寛永寺・不忍池周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "nihonbashi-edo",
    title: "日本橋（商人の町）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "shiba-edo",
    title: "芝（増上寺周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "kanda-edo",
    title: "神田（神田明神周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "roppongi-meiji",
    title: "麻布・六本木周辺",
    era: "古地図風（現在の地図をもとに加工）",
  },
  {
    id: "goshiki-fudo-meiji",
    title: "五色不動めぐり（目黒・目白・目赤・目青・目黄）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "basho-oku-no-hosomichi-meiji",
    title: "松尾芭蕉ゆかりの地（深川〜千住）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "kasumigaseki-toranomon-meiji",
    title: "霞ヶ関・虎ノ門（大名屋敷と社寺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "akasaka-kioicho-meiji",
    title: "赤坂・紀尾井町（大名屋敷跡）",
    era: "古地図風（現在の地図をもとに加工）",
  },
  {
    id: "tokaido-edo",
    title: "東海道（日本橋〜京橋・新橋）",
    era: "江戸時代（五街道が整備された時期）",
  },
  {
    id: "nakasendo-edo",
    title: "中山道（本郷〜小石川・巣鴨）",
    era: "江戸時代（五街道が整備された時期）",
  },
  {
    id: "kudanshita-chidorigafuchi-meiji",
    title: "九段下・千鳥ヶ淵（靖国神社周辺）",
    era: "明治時代（1891年・明治24年頃）",
  },
  {
    id: "meiji-jingu-omotesando-meiji",
    title: "明治神宮・表参道・神宮外苑",
    era: "明治時代（1891年・明治24年頃、社殿創建前の代々木御料地一帯）",
  },
  {
    id: "oyama-kaido",
    title: "大山街道（赤坂〜二子玉川）",
    era: "古地図風（現在の地図をもとに加工）",
  },
];

export function findOldMap(id: string | null): OldMapEntry | undefined {
  if (!id) return undefined;
  return OLD_MAP_CATALOG.find((entry) => entry.id === id);
}
