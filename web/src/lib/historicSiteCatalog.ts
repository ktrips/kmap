import { collection, getDocs } from "firebase/firestore/lite";
import { useSyncExternalStore } from "react";
import { db } from "./firebase";
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

// 一覧の行・御朱印ごとに呼ばれるため、毎回全件を順に探さないよう索引を作っておく。
// 管理者がアプリで追加・非表示にしたチェックポイント（Firestore の`adminCheckpoints`）を読んだら作り直す。
let SITE_BY_ID = new Map<string, HistoricSiteEntry>();
let SITES_BY_OVERLAY = new Map<string, HistoricSiteEntry[]>();
function rebuildIndexes(entries: HistoricSiteEntry[]) {
  SITE_BY_ID = new Map(entries.map((entry) => [entry.id, entry]));
  SITES_BY_OVERLAY = new Map();
  for (const entry of entries) {
    const group = SITES_BY_OVERLAY.get(entry.overlayMapID);
    if (group) group.push(entry);
    else SITES_BY_OVERLAY.set(entry.overlayMapID, [entry]);
  }
}
rebuildIndexes(HISTORIC_SITE_CATALOG);
const EMPTY_SITES: HistoricSiteEntry[] = [];

// ---- 管理者が追加・非表示にしたチェックポイント（iOSの`AdminCheckpointCloud`と同じデータ）

let catalogVersion = 0;
const listeners = new Set<() => void>();
let adminCheckpointsRequested = false;

function loadAdminCheckpoints() {
  if (adminCheckpointsRequested || !db) return;
  adminCheckpointsRequested = true;
  getDocs(collection(db, "adminCheckpoints"))
    .then((snapshot) => {
      const hidden = new Set<string>();
      const extras: HistoricSiteEntry[] = [];
      for (const doc of snapshot.docs) {
        const data = doc.data();
        if (typeof data.overlayMapID !== "string") continue;
        if (data.hidden === true) hidden.add(doc.id);
        else if (typeof data.name === "string" && typeof data.lat === "number" && typeof data.lng === "number") {
          extras.push({ id: doc.id, name: data.name, overlayMapID: data.overlayMapID, coordinate: { lat: data.lat, lng: data.lng } });
        }
      }
      if (hidden.size === 0 && extras.length === 0) return;
      extras.sort((a, b) => a.id.localeCompare(b.id));
      rebuildIndexes([...HISTORIC_SITE_CATALOG.filter((entry) => !hidden.has(entry.id)), ...extras]);
      catalogVersion += 1;
      listeners.forEach((listener) => listener());
    })
    .catch(() => {
      // 読めなくても、同梱のチェックポイントだけで表示を続ける。
    });
}

/**
 * チェックポイントの一覧が変わった（管理者の追加分を読み込んだ）時に再描画するためのフック。
 * 返す値は変わるたびに増える番号なので、`useMemo`の依存に入れて使う。初めて使われた時に読み込みを始める。
 */
export function useHistoricSiteCatalogVersion(): number {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      loadAdminCheckpoints();
      return () => listeners.delete(listener);
    },
    () => catalogVersion,
  );
}

export function findHistoricSite(id: string | null): HistoricSiteEntry | undefined {
  if (!id) return undefined;
  return SITE_BY_ID.get(id);
}

/**
 * 指定した古地図に属するチェックポイントだけを返す（`overlayMapID`が`null`なら空配列）。
 * 同じ古地図には常に同じ配列を返すため、呼び出し側で`useMemo`しなくても参照が安定する
 * （管理者の追加分を読み込んだ時だけ変わる。`useHistoricSiteCatalogVersion`）。
 */
export function sitesForOverlay(overlayMapID: string | null): HistoricSiteEntry[] {
  if (!overlayMapID) return EMPTY_SITES;
  return SITES_BY_OVERLAY.get(overlayMapID) ?? EMPTY_SITES;
}
