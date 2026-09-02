import { collection, onSnapshot, orderBy, query, Timestamp } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { SharedPhoto, SharedTrip } from "../types/sharedTrip";

function parsePhotos(value: unknown): SharedPhoto[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => {
      if (!entry || typeof entry !== "object") return null;
      const url = (entry as Record<string, unknown>).url;
      const label = (entry as Record<string, unknown>).siteName ?? (entry as Record<string, unknown>).placeName;
      if (typeof url !== "string") return null;
      return { url, label: typeof label === "string" ? label : "" };
    })
    .filter((photo): photo is SharedPhoto => photo !== null);
}

/**
 * 全ユーザーが公開している「みんなの時空旅」（`sharedTrips`）をリアルタイムに監視する。
 * サインインしていない訪問者でも、公開済みの時空旅は誰でも見られる
 * （Firestoreルールで`sharedTrips`は公開読み取り可にしているため）。
 */
export function useSharedTrips() {
  const [trips, setTrips] = useState<SharedTrip[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!db) {
      setTrips([]);
      return;
    }

    setIsLoading(true);
    setError(null);

    const q = query(collection(db, "sharedTrips"), orderBy("startedAt", "desc"));

    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const next: SharedTrip[] = snapshot.docs.map((doc) => {
          const data = doc.data();
          const startedAt = data.startedAt instanceof Timestamp ? data.startedAt.toDate() : new Date();
          const endedAt = data.endedAt instanceof Timestamp ? data.endedAt.toDate() : null;
          return {
            id: doc.id,
            ownerUserID: data.ownerUserID ?? "",
            ownerDisplayName: data.ownerDisplayName ?? null,
            title: data.title ?? null,
            latitudes: Array.isArray(data.latitudes) ? data.latitudes : [],
            longitudes: Array.isArray(data.longitudes) ? data.longitudes : [],
            startedAt,
            endedAt,
            stepCount: typeof data.stepCount === "number" ? data.stepCount : null,
            overlayMapID: data.overlayMapID ?? null,
            totalDistanceMeters: typeof data.totalDistanceMeters === "number" ? data.totalDistanceMeters : 0,
            stampPhotos: parsePhotos(data.stampPhotos),
            postPhotos: parsePhotos(data.postPhotos),
          };
        });
        setTrips(next);
        setIsLoading(false);
      },
      (err) => {
        setError(err.message);
        setIsLoading(false);
      },
    );

    return () => unsubscribe();
  }, []);

  return { trips, isLoading, error };
}
