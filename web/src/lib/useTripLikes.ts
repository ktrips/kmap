import { collection, deleteDoc, doc, getDocs, setDoc, serverTimestamp } from "firebase/firestore/lite";
import { useCallback, useEffect, useState } from "react";
import { db } from "./firebase";

/**
 * 1つの時空旅（`sharedTrips/{tripId}`）への「いいね」を管理する。
 * `sharedTrips/{tripId}/likes/{uid}`の存在＝いいね済み、として扱う
 * （文書のIDをuidに固定しているため、1人1いいねが自然に守られる）。
 * 軽量版のFirestoreで、旅を開いた時と、自分がいいねを付け外しした後に読み直す。
 */
export function useTripLikes(tripId: string | null, currentUserID: string | null) {
  const [likeUserIDs, setLikeUserIDs] = useState<string[]>([]);
  const [isToggling, setIsToggling] = useState(false);

  const reload = useCallback(async () => {
    if (!db || !tripId) {
      setLikeUserIDs([]);
      return;
    }
    try {
      const snapshot = await getDocs(collection(db, "sharedTrips", tripId, "likes"));
      setLikeUserIDs(snapshot.docs.map((d) => d.id));
    } catch {
      setLikeUserIDs([]);
    }
  }, [tripId]);

  useEffect(() => {
    void reload();
  }, [reload]);

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
      await reload();
    } finally {
      setIsToggling(false);
    }
  };

  return { likeCount: likeUserIDs.length, isLikedByMe, toggleLike, isToggling };
}
