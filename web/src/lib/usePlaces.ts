import { collection, onSnapshot, orderBy, query, Timestamp } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { SavedPlace } from "../types/place";

/**
 * サインイン中のユーザーの `users/{uid}/places` をリアルタイムに監視する。
 * iOSアプリ側で新しい地点を保存すると、このWeb側にもすぐ反映される。
 */
export function usePlaces(userID: string | null) {
  const [places, setPlaces] = useState<SavedPlace[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!db || !userID) {
      setPlaces([]);
      return;
    }

    setIsLoading(true);
    setError(null);

    const q = query(collection(db, "users", userID, "places"), orderBy("createdAt", "desc"));

    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const next: SavedPlace[] = snapshot.docs.map((doc) => {
          const data = doc.data();
          const createdAt = data.createdAt instanceof Timestamp ? data.createdAt.toDate() : new Date();
          return {
            id: doc.id,
            title: data.title ?? "",
            latitude: data.latitude ?? 0,
            longitude: data.longitude ?? 0,
            overlayMapID: data.overlayMapID ?? null,
            era: data.era ?? "",
            storyText: data.storyText ?? "",
            createdAt,
          };
        });
        setPlaces(next);
        setIsLoading(false);
      },
      (err) => {
        setError(err.message);
        setIsLoading(false);
      },
    );

    return () => unsubscribe();
  }, [userID]);

  return { places, isLoading, error };
}
