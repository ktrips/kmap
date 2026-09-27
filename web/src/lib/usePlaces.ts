import type { DocumentData } from "firebase/firestore";
import { toDate } from "./tripDocument";
import { useRealtimeCollection } from "./useRealtimeCollection";
import type { SavedPlace } from "../types/place";

function parsePlace(id: string, data: DocumentData): SavedPlace {
  return {
    id,
    title: data.title ?? "",
    latitude: data.latitude ?? 0,
    longitude: data.longitude ?? 0,
    overlayMapID: data.overlayMapID ?? null,
    era: data.era ?? "",
    storyText: data.storyText ?? "",
    createdAt: toDate(data.createdAt, new Date()),
  };
}

/** サインイン中のユーザーの `users/{uid}/places` をリアルタイムに購読する。 */
export function usePlaces(userID: string | null) {
  const { items, isLoading, error } = useRealtimeCollection(
    userID ? ["users", userID, "places"] : null,
    "createdAt",
    parsePlace,
  );
  return { places: items, isLoading, error };
}
