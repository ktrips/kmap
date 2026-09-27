import type { DocumentData } from "firebase/firestore";
import { toDate } from "./tripDocument";
import { useRealtimeCollection } from "./useRealtimeCollection";
import type { PhotoPost } from "../types/photoPost";

function parsePhotoPost(id: string, data: DocumentData): PhotoPost {
  return {
    id,
    photoURL: data.photoURL ?? null,
    postedAt: toDate(data.postedAt, new Date()),
    points: typeof data.points === "number" ? data.points : 0,
    latitude: typeof data.latitude === "number" ? data.latitude : 0,
    longitude: typeof data.longitude === "number" ? data.longitude : 0,
    walkRouteID: data.walkRouteID ?? null,
    placeName: data.placeName ?? null,
    storyTitle: data.storyTitle ?? null,
    storyBody: data.storyBody ?? null,
  };
}

/** サインイン中のユーザーの `users/{uid}/photoPosts` をリアルタイムに購読する。 */
export function usePhotoPosts(userID: string | null) {
  const { items } = useRealtimeCollection(userID ? ["users", userID, "photoPosts"] : null, "postedAt", parsePhotoPost);
  return { photoPosts: items };
}
