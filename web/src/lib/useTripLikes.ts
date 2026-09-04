import { collection, deleteDoc, doc, onSnapshot, setDoc, serverTimestamp } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";

/**
 * 1つの時空旅（`sharedTrips/{tripId}`）への「いいね」を管理する。
 * `sharedTrips/{tripId}/likes/{uid}`の存在＝いいね済み、として扱う
 * （文書のIDをuidに固定しているため、1人1いいねが自然に守られる）。
 */
export function useTripLikes(tripId: string | null, currentUserID: string | null) {
  const [likeUserIDs, setLikeUserIDs] = useState<string[]>([]);
  const [isToggling, setIsToggling] = useState(false);

  useEffect(() => {
    if (!db || !tripId) {
      setLikeUserIDs([]);
      return;
    }
    const unsubscribe = onSnapshot(
      collection(db, "sharedTrips", tripId, "likes"),
      (snapshot) => setLikeUserIDs(snapshot.docs.map((d) => d.id)),
      () => setLikeUserIDs([]),
    );
    return () => unsubscribe();
  }, [tripId]);

  const isLikedByMe = currentUserID !== null && likeUserIDs.includes(currentUserID);

  const toggleLike = async () => {
    if (!db || !tripId || !currentUserID || isToggling) return;
    setIsToggling(true);
    try {
      const likeRef = doc(db, "sharedTrips", tripId, "likes", currentUserID);
      if (isLikedByMe) {
        await deleteDoc(likeRef);
      } else {
        await setDoc(likeRef, { likedAt: serverTimestamp() });
      }
    } finally {
      setIsToggling(false);
    }
  };

  return { likeCount: likeUserIDs.length, isLikedByMe, toggleLike, isToggling };
}
