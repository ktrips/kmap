import { collection, onSnapshot, orderBy, query, Timestamp } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { PhotoPost } from "../types/photoPost";

/** サインイン中のユーザーの `users/{uid}/photoPosts` をリアルタイムに監視する。 */
export function usePhotoPosts(userID: string | null) {
  const [photoPosts, setPhotoPosts] = useState<PhotoPost[]>([]);

  useEffect(() => {
    if (!db || !userID) {
      setPhotoPosts([]);
      return;
    }

    const q = query(collection(db, "users", userID, "photoPosts"), orderBy("postedAt", "desc"));

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const next: PhotoPost[] = snapshot.docs.map((doc) => {
        const data = doc.data();
        const postedAt = data.postedAt instanceof Timestamp ? data.postedAt.toDate() : new Date();
        return {
          id: doc.id,
          photoURL: data.photoURL ?? null,
          postedAt,
          points: typeof data.points === "number" ? data.points : 0,
          latitude: typeof data.latitude === "number" ? data.latitude : 0,
          longitude: typeof data.longitude === "number" ? data.longitude : 0,
          walkRouteID: data.walkRouteID ?? null,
          placeName: data.placeName ?? null,
        };
      });
      setPhotoPosts(next);
    });

    return () => unsubscribe();
  }, [userID]);

  return { photoPosts };
}
