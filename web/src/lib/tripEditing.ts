import { doc, updateDoc } from "firebase/firestore";
import { db } from "./firebase";

/**
 * 自分の時空旅の名称・感想（説明）を更新する。`users/{uid}/walkRoutes/{id}`に加え、
 * 「みんなの時空旅」として公開中（`isShared`）なら`sharedTrips/{id}`も合わせて更新し、
 * 公開ページ側の表示にもすぐ反映されるようにする。
 */
export async function saveTripDetails(
  userID: string,
  tripId: string,
  isShared: boolean,
  updates: { title: string | null; description: string | null },
): Promise<void> {
  if (!db) return;
  const payload = { title: updates.title, notes: updates.description };
  await updateDoc(doc(db, "users", userID, "walkRoutes", tripId), payload);
  if (isShared) {
    await updateDoc(doc(db, "sharedTrips", tripId), payload);
  }
}
