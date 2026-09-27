import type { DocumentData } from "firebase/firestore";
import { toDate } from "./tripDocument";
import { useRealtimeCollection } from "./useRealtimeCollection";
import type { Stamp } from "../types/stamp";

function parseStamp(id: string, data: DocumentData): Stamp {
  return {
    id,
    siteID: data.siteID ?? "",
    collectedAt: toDate(data.collectedAt, new Date()),
    photoURL: data.photoURL ?? null,
    walkRouteID: data.walkRouteID ?? null,
    detail: data.detail ?? null,
  };
}

/** サインイン中のユーザーの `users/{uid}/stamps` をリアルタイムに購読する。 */
export function useStamps(userID: string | null) {
  const { items } = useRealtimeCollection(userID ? ["users", userID, "stamps"] : null, "collectedAt", parseStamp);
  return { stamps: items };
}
