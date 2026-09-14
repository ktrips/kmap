import { doc, getDoc } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import { parseSharedTripDocument } from "./useSharedTrips";
import type { SharedTrip } from "../types/sharedTrip";

/**
 * `useSharedTrips`は通信量を抑えるため、直近50件だけを一覧として購読している。
 * そのため、共有リンク（`?t=`）でそれより古い（または`startedAt`が無い）時空旅を
 * 直接開いた時、一覧にその旅が含まれず「開いたのに表示されない」ことがあった。
 * このフックは、選ばれた旅IDが一覧に無い時だけ、その1件をFirestoreから直接取得する。
 */
export function useSharedTripById(tripId: string | null, isAlreadyInList: boolean): SharedTrip | null {
  const [trip, setTrip] = useState<SharedTrip | null>(null);

  useEffect(() => {
    if (!tripId || isAlreadyInList || !db) {
      setTrip(null);
      return;
    }
    let cancelled = false;
    getDoc(doc(db, "sharedTrips", tripId))
      .then((snapshot) => {
        if (cancelled || !snapshot.exists()) return;
        setTrip(parseSharedTripDocument(snapshot.id, snapshot.data()));
      })
      .catch(() => {
        // 個別取得に失敗しても、一覧側の通常表示には影響しないので静かに諦める。
      });
    return () => {
      cancelled = true;
    };
  }, [tripId, isAlreadyInList]);

  return trip;
}
