import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
} from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";

export interface TripComment {
  id: string;
  authorUserID: string;
  authorDisplayName: string;
  text: string;
  createdAt: Date;
}

/** 1つの時空旅（`sharedTrips/{tripId}`）へのコメントを管理する。 */
export function useTripComments(tripId: string | null) {
  const [comments, setComments] = useState<TripComment[]>([]);
  const [isPosting, setIsPosting] = useState(false);

  useEffect(() => {
    if (!db || !tripId) {
      setComments([]);
      return;
    }
    const q = query(collection(db, "sharedTrips", tripId, "comments"), orderBy("createdAt", "asc"));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        setComments(
          snapshot.docs.map((d) => {
            const data = d.data();
            return {
              id: d.id,
              authorUserID: data.authorUserID ?? "",
              authorDisplayName: data.authorDisplayName ?? "名無し",
              text: data.text ?? "",
              createdAt: data.createdAt instanceof Timestamp ? data.createdAt.toDate() : new Date(),
            };
          }),
        );
      },
      () => setComments([]),
    );
    return () => unsubscribe();
  }, [tripId]);

  const postComment = async (text: string, author: { uid: string; displayName: string | null }) => {
    if (!db || !tripId) return;
    const trimmed = text.trim();
    if (!trimmed) return;
    setIsPosting(true);
    try {
      await addDoc(collection(db, "sharedTrips", tripId, "comments"), {
        authorUserID: author.uid,
        authorDisplayName: author.displayName ?? "名無し",
        text: trimmed,
        createdAt: serverTimestamp(),
      });
    } finally {
      setIsPosting(false);
    }
  };

  const deleteComment = async (commentId: string) => {
    if (!db || !tripId) return;
    await deleteDoc(doc(db, "sharedTrips", tripId, "comments", commentId));
  };

  return { comments, postComment, deleteComment, isPosting };
}
