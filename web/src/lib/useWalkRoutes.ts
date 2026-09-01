import { collection, onSnapshot, orderBy, query, Timestamp } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { WalkTrip } from "../types/walkRoute";

/**
 * サインイン中のユーザーの `users/{uid}/walkRoutes` をリアルタイムに監視する。
 * iOSアプリ（またはApple Watch）で時間旅を保存すると、このWeb側の「My Trips」にもすぐ反映される。
 */
export function useWalkRoutes(userID: string | null) {
  const [trips, setTrips] = useState<WalkTrip[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!db || !userID) {
      setTrips([]);
      return;
    }

    setIsLoading(true);
    setError(null);

    const q = query(collection(db, "users", userID, "walkRoutes"), orderBy("startedAt", "desc"));

    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const next: WalkTrip[] = snapshot.docs.map((doc) => {
          const data = doc.data();
          const startedAt = data.startedAt instanceof Timestamp ? data.startedAt.toDate() : new Date();
          const endedAt = data.endedAt instanceof Timestamp ? data.endedAt.toDate() : null;
          return {
            id: doc.id,
            title: data.title ?? null,
            latitudes: Array.isArray(data.latitudes) ? data.latitudes : [],
            longitudes: Array.isArray(data.longitudes) ? data.longitudes : [],
            startedAt,
            endedAt,
            stepCount: typeof data.stepCount === "number" ? data.stepCount : null,
            overlayMapID: data.overlayMapID ?? null,
            totalDistanceMeters: typeof data.totalDistanceMeters === "number" ? data.totalDistanceMeters : 0,
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
  }, [userID]);

  return { trips, isLoading, error };
}
