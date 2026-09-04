import { collection, onSnapshot } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";

/**
 * 一覧の1行に添える、いいね・コメントの件数だけの軽量な購読。
 * iOSアプリで付けた分もこの同じ`sharedTrips/{tripId}`を見るため、そのまま反映される。
 */
export function useTripEngagementCounts(tripId: string | null) {
  const [likeCount, setLikeCount] = useState(0);
  const [commentCount, setCommentCount] = useState(0);

  useEffect(() => {
    if (!db || !tripId) {
      setLikeCount(0);
      setCommentCount(0);
      return;
    }
    const unsubscribeLikes = onSnapshot(
      collection(db, "sharedTrips", tripId, "likes"),
      (snapshot) => setLikeCount(snapshot.size),
      () => setLikeCount(0),
    );
    const unsubscribeComments = onSnapshot(
      collection(db, "sharedTrips", tripId, "comments"),
      (snapshot) => setCommentCount(snapshot.size),
      () => setCommentCount(0),
    );
    return () => {
      unsubscribeLikes();
      unsubscribeComments();
    };
  }, [tripId]);

  return { likeCount, commentCount };
}
