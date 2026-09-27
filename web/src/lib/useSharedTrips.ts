import { collection, getDocs, limit, orderBy, query, type DocumentData } from "firebase/firestore/lite";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import { parseTripFields } from "./tripDocument";
import type { SharedPhoto, SharedTrip } from "../types/sharedTrip";

/** `sharedTrips/{id}`の1ドキュメントを`SharedTrip`に変換する。単発取得（`useSharedTripById`）とも共有する。 */
export function parseSharedTripDocument(id: string, data: DocumentData): SharedTrip {
  return {
    ...parseTripFields(id, data),
    ownerUserID: data.ownerUserID ?? "",
    ownerDisplayName: data.ownerDisplayName ?? null,
    stampPhotos: parsePhotos(data.stampPhotos),
    postPhotos: parsePhotos(data.postPhotos),
    likeCount: typeof data.likeCount === "number" ? data.likeCount : null,
    commentCount: typeof data.commentCount === "number" ? data.commentCount : null,
  };
}

function parsePhotos(value: unknown): SharedPhoto[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => {
      if (!entry || typeof entry !== "object") return null;
      const url = (entry as Record<string, unknown>).url;
      const label = (entry as Record<string, unknown>).siteName ?? (entry as Record<string, unknown>).placeName;
      const detail = (entry as Record<string, unknown>).detail;
      if (typeof url !== "string") return null;
      const photo: SharedPhoto = { url, label: typeof label === "string" ? label : "" };
      if (typeof detail === "string" && detail.length > 0) photo.detail = detail;
      return photo;
    })
    .filter((photo): photo is SharedPhoto => photo !== null);
}

/**
 * 全ユーザーが公開している「みんなの時空旅」（`sharedTrips`）の直近50件を読み込む。
 * サインインしていない訪問者でも見られる（Firestoreルールで`sharedTrips`は公開読み取り可）。
 *
 * 最初に読み込む量を減らすため、リアルタイム購読（完全版のFirestoreが必要）ではなく軽量版で1回読み、
 * タブに戻ってきた時（5分以上たっていれば）に読み直す。
 */
export function useSharedTrips() {
  const [trips, setTrips] = useState<SharedTrip[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const firestore = db;
    if (!firestore) {
      setTrips([]);
      return;
    }
    let cancelled = false;
    let loadedAt = 0;
    const load = () => {
      loadedAt = Date.now();
      setIsLoading(true);
      setError(null);
      getDocs(query(collection(firestore, "sharedTrips"), orderBy("startedAt", "desc"), limit(50)))
        .then((snapshot) => {
          if (cancelled) return;
          setTrips(snapshot.docs.map((doc) => parseSharedTripDocument(doc.id, doc.data())));
          setIsLoading(false);
        })
        .catch((err: unknown) => {
          if (cancelled) return;
          setError(err instanceof Error ? err.message : "読み込みに失敗しました。");
          setIsLoading(false);
        });
    };
    load();
    const handleVisibility = () => {
      if (document.visibilityState === "visible" && Date.now() - loadedAt > 5 * 60_000) load();
    };
    document.addEventListener("visibilitychange", handleVisibility);
    return () => {
      cancelled = true;
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, []);

  return { trips, isLoading, error };
}
