import { collection, onSnapshot, orderBy, query, Timestamp } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { Stamp } from "../types/stamp";

/** サインイン中のユーザーの `users/{uid}/stamps` をリアルタイムに監視する。 */
export function useStamps(userID: string | null) {
  const [stamps, setStamps] = useState<Stamp[]>([]);

  useEffect(() => {
    if (!db || !userID) {
      setStamps([]);
      return;
    }

    const q = query(collection(db, "users", userID, "stamps"), orderBy("collectedAt", "desc"));

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const next: Stamp[] = snapshot.docs.map((doc) => {
        const data = doc.data();
        const collectedAt = data.collectedAt instanceof Timestamp ? data.collectedAt.toDate() : new Date();
        return {
          id: doc.id,
          siteID: data.siteID ?? "",
          collectedAt,
          photoURL: data.photoURL ?? null,
          walkRouteID: data.walkRouteID ?? null,
        };
      });
      setStamps(next);
    });

    return () => unsubscribe();
  }, [userID]);

  return { stamps };
}
