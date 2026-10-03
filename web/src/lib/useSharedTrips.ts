import type { DocumentData } from "firebase/firestore/lite";
import { useEffect, useState } from "react";
import { isFirebaseConfigured } from "./firebase";
import { runProjectedQuery } from "./firestoreRest";
import { parseTripFields } from "./tripDocument";
import type { SharedPhoto, SharedTrip } from "../types/sharedTrip";

/**
 * 公開中の旅（`users/{uid}/walkRoutes/{id}`で`isSharedPublicly == true`のもの）の1件を`SharedTrip`に変換する。
 * 投稿者名・写真の一覧・件数・歩き始めた地点は Cloud Functions（functions/src/sharedTrips.ts）が旅の文書に書いている。
 * 単発取得（`useSharedTripById`）とも共有する。
 *
 * @param path 旅の文書のパス（`users/{uid}/walkRoutes/{id}`）。
 */
export function parseSharedTripDocument(path: string, data: DocumentData): SharedTrip {
  const [, ownerFromPath = "", , id = ""] = path.split("/");
  const trip = parseTripFields(id, data);
  return {
    ...trip,
    documentPath: path,
    startLatitude: trip.latitudes[0] ?? (typeof data.startLatitude === "number" ? data.startLatitude : null),
    startLongitude: trip.longitudes[0] ?? (typeof data.startLongitude === "number" ? data.startLongitude : null),
    ownerUserID: data.ownerUserID ?? ownerFromPath,
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

/** 一覧で読む項目。軌跡の座標（`latitudes`・`longitudes`）は旅の文書の大半を占めるので読まず、旅を開いた時に読む。 */
const LIST_FIELDS = [
  "title", "notes", "startedAt", "endedAt", "stepCount", "overlayMapID", "totalDistanceMeters",
  "travelJournalTitle", "travelJournalMarkdown", "tripVideoURL", "ownerUserID", "ownerDisplayName",
  "stampPhotos", "postPhotos", "likeCount", "commentCount", "startLatitude", "startLongitude",
];

/**
 * 全ユーザーが公開している「みんなの時空旅」の直近50件を読み込む（全ユーザーの`walkRoutes`から公開中のものを探す）。
 * サインインしていない訪問者でも見られる（Firestoreルールで、公開中の旅は誰でも読める）。
 * 軌跡の座標を除いた項目だけを読む（17件で 1.3MB → 約0.2MB）。座標は`useTripRoute`が旅を開いた時に読む。
 *
 * 最初に読み込む量を減らすため、リアルタイム購読（完全版のFirestoreが必要）ではなく軽量版で1回読み、
 * タブに戻ってきた時（5分以上たっていれば）に読み直す。
 */
export function useSharedTrips() {
  const [trips, setTrips] = useState<SharedTrip[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!isFirebaseConfigured) {
      setTrips([]);
      return;
    }
    let cancelled = false;
    let loadedAt = 0;
    const load = () => {
      loadedAt = Date.now();
      setIsLoading(true);
      setError(null);
      runProjectedQuery(
        {
          from: [{ collectionId: "walkRoutes", allDescendants: true }],
          where: { fieldFilter: { field: { fieldPath: "isSharedPublicly" }, op: "EQUAL", value: { booleanValue: true } } },
          orderBy: [{ field: { fieldPath: "startedAt" }, direction: "DESCENDING" }],
          limit: 50,
        },
        LIST_FIELDS,
      )
        .then((documents) => {
          if (cancelled) return;
          setTrips(documents.map(({ path, data }) => parseSharedTripDocument(path, data)));
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
