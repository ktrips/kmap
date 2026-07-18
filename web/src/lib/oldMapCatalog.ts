/**
 * iOS側の `Komap/Models/HistoricalOverlayMap.swift` と対になる古地図カタログ。
 * Web側では地点に紐づく古地図の「タイトル・時代」をラベル表示するために使う。
 */
export interface OldMapEntry {
  id: string;
  title: string;
  era: string;
}

export const OLD_MAP_CATALOG: OldMapEntry[] = [
  {
    id: "edo-castle-1850s",
    title: "江戸城周辺（安政期・1850年代）",
    era: "江戸時代後期（1850年代・安政期）",
  },
  {
    id: "asakusa-edo",
    title: "浅草・浅草寺周辺（江戸時代）",
    era: "江戸時代（浅草寺門前町が賑わった時期）",
  },
];

export function findOldMap(id: string | null): OldMapEntry | undefined {
  if (!id) return undefined;
  return OLD_MAP_CATALOG.find((entry) => entry.id === id);
}
