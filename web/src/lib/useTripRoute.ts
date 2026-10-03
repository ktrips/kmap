import { doc, getDoc } from "firebase/firestore/lite";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { UnifiedTrip } from "../types/unifiedTrip";

type Route = { latitudes: number[]; longitudes: number[] };

/** 一度読んだ旅の座標（開き直した時に読み直さない）。 */
const routeCache = new Map<string, Route>();

/**
 * 公開中の旅の一覧は軌跡の座標を読まない（`useSharedTrips`）ので、旅を開いた時にその1件の座標だけを読んで足す。
 * 座標を既に持っている旅（自分の旅・共有リンクで個別に読んだ旅）はそのまま返す。
 */
export function useTripRoute(trip: UnifiedTrip | null): UnifiedTrip | null {
  const path = trip && trip.latitudes.length === 0 ? trip.documentPath : null;
  const [route, setRoute] = useState<{ path: string; route: Route } | null>(null);

  useEffect(() => {
    if (!path || !db || routeCache.has(path)) return;
    let cancelled = false;
    getDoc(doc(db, path))
      .then((snapshot) => {
        const data = snapshot.data();
        const loaded: Route = {
          latitudes: Array.isArray(data?.latitudes) ? data.latitudes : [],
          longitudes: Array.isArray(data?.longitudes) ? data.longitudes : [],
        };
        routeCache.set(path, loaded);
        if (!cancelled) setRoute({ path, route: loaded });
      })
      .catch(() => {
        // 座標が読めなくても、写真・旅日記などは表示できるので静かに諦める（地図だけ出ない）。
      });
    return () => {
      cancelled = true;
    };
  }, [path]);

  if (!trip || !path) return trip;
  const loaded = routeCache.get(path) ?? (route?.path === path ? route.route : null);
  return loaded ? { ...trip, ...loaded } : trip;
}
