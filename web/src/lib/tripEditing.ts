import { doc, serverTimestamp, updateDoc } from "firebase/firestore/lite";
import { db } from "./firebase";

/**
 * 自分の時空旅の名称・感想（説明）を更新する。旅の正本は`users/{uid}/walkRoutes/{id}`の1か所だけなので、
 * 公開中の旅なら「みんなの時空旅」にもそのまま反映される。
 */
export async function saveTripDetails(
  userID: string,
  tripId: string,
  updates: { title: string | null; description: string | null },
): Promise<void> {
  if (!db) return;
  // `detailsUpdatedAt`: iOSアプリはこの日時と端末側の変更日時を比べ、新しい方の名前・感想を残す。
  const payload = { title: updates.title, notes: updates.description, detailsUpdatedAt: serverTimestamp() };
  await updateDoc(doc(db, "users", userID, "walkRoutes", tripId), payload);
}
