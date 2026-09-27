import { addDoc, collection, deleteDoc, doc, getDocs, orderBy, query, serverTimestamp } from "firebase/firestore/lite";
import { useCallback, useEffect, useState } from "react";
import { db } from "./firebase";
import { toDate } from "./tripDocument";

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

  // 軽量版のFirestoreで、旅を開いた時と、自分が投稿・削除した後に読み直す。
  const reload = useCallback(async () => {
    if (!db || !tripId) {
      setComments([]);
      return;
    }
    try {
      const snapshot = await getDocs(query(collection(db, "sharedTrips", tripId, "comments"), orderBy("createdAt", "asc")));
      setComments(
        snapshot.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            authorUserID: data.authorUserID ?? "",
            authorDisplayName: data.authorDisplayName ?? "名無し",
            text: data.text ?? "",
            createdAt: toDate(data.createdAt, new Date()),
          };
        }),
      );
    } catch {
      setComments([]);
    }
  }, [tripId]);

  useEffect(() => {
    void reload();
  }, [reload]);

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
      await reload();
    } finally {
      setIsPosting(false);
    }
  };

  const deleteComment = async (commentId: string) => {
    if (!db || !tripId) return;
    await deleteDoc(doc(db, "sharedTrips", tripId, "comments", commentId));
    await reload();
  };

  return { comments, postComment, deleteComment, isPosting };
}
