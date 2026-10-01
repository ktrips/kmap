import type { DocumentData } from "firebase/firestore/lite";
import type { WalkTrip } from "../types/walkRoute";

/**
 * FirestoreのTimestamp（軽量版・完全版のどちらのクラスでも）をDateにする。無ければ`fallback`。
 * 軽量版と完全版でTimestampのクラスが別のため、`instanceof`ではなく`toDate`の有無で判定する。
 */
export function toDate(value: unknown, fallback: Date): Date;
export function toDate(value: unknown, fallback: null): Date | null;
export function toDate(value: unknown, fallback: Date | null): Date | null {
  if (value && typeof (value as { toDate?: unknown }).toDate === "function") {
    return (value as { toDate: () => Date }).toDate();
  }
  return fallback;
}

/**
 * `users/{uid}/walkRoutes/{id}`の項目を読み取る（自分の旅・公開中の旅で共通）。
 * どちらもiOSアプリ（`SyncService`）が同じ項目名で書き込むため、読み取りもここに1本化する。
 */
export function parseTripFields(id: string, data: DocumentData): WalkTrip {
  return {
    id,
    title: data.title ?? null,
    description: data.notes ?? null,
    latitudes: Array.isArray(data.latitudes) ? data.latitudes : [],
    longitudes: Array.isArray(data.longitudes) ? data.longitudes : [],
    startedAt: toDate(data.startedAt, new Date()),
    endedAt: toDate(data.endedAt, null),
    stepCount: typeof data.stepCount === "number" ? data.stepCount : null,
    overlayMapID: data.overlayMapID ?? null,
    totalDistanceMeters: typeof data.totalDistanceMeters === "number" ? data.totalDistanceMeters : 0,
    journalTitle: data.travelJournalTitle ?? null,
    journalMarkdown: data.travelJournalMarkdown ?? null,
    tripVideoURL: typeof data.tripVideoURL === "string" && data.tripVideoURL.length > 0 ? data.tripVideoURL : null,
  };
}
