import { HISTORIC_SITE_DATA } from "./generated/catalogData";

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

// チェックポイントの一覧は catalog/historic_sites.json から生成した generated/catalogData.ts にある。
export const HISTORIC_SITE_CATALOG: HistoricSiteEntry[] = HISTORIC_SITE_DATA;

// 一覧の行・御朱印ごとに呼ばれるため、毎回全件を順に探さないよう索引を一度だけ作る。
const SITE_BY_ID = new Map(HISTORIC_SITE_CATALOG.map((entry) => [entry.id, entry]));
const SITES_BY_OVERLAY = new Map<string, HistoricSiteEntry[]>();
for (const entry of HISTORIC_SITE_CATALOG) {
  const group = SITES_BY_OVERLAY.get(entry.overlayMapID);
  if (group) group.push(entry);
  else SITES_BY_OVERLAY.set(entry.overlayMapID, [entry]);
}
const EMPTY_SITES: HistoricSiteEntry[] = [];

export function findHistoricSite(id: string | null): HistoricSiteEntry | undefined {
  if (!id) return undefined;
  return SITE_BY_ID.get(id);
}

/**
 * 指定した古地図に属するチェックポイントだけを返す（`overlayMapID`が`null`なら空配列）。
 * 同じ古地図には常に同じ配列を返すため、呼び出し側で`useMemo`しなくても参照が安定する。
 */
export function sitesForOverlay(overlayMapID: string | null): HistoricSiteEntry[] {
  if (!overlayMapID) return EMPTY_SITES;
  return SITES_BY_OVERLAY.get(overlayMapID) ?? EMPTY_SITES;
}
