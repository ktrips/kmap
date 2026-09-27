import { parseTripFields } from "./tripDocument";
import { useRealtimeCollection } from "./useRealtimeCollection";

/**
 * サインイン中のユーザーの `users/{uid}/walkRoutes` をリアルタイムに購読する。
 * iOSアプリ（またはApple Watch）で時間旅を保存すると、このWeb側の「My Trips」にもすぐ反映される。
 */
export function useWalkRoutes(userID: string | null) {
  const { items, isLoading, error } = useRealtimeCollection(
    userID ? ["users", userID, "walkRoutes"] : null,
    "startedAt",
    parseTripFields,
  );
  return { trips: items, isLoading, error };
}
