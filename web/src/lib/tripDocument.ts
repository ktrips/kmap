import { Timestamp, type DocumentData } from "firebase/firestore";
import type { WalkTrip } from "../types/walkRoute";

/**
 * `users/{uid}/walkRoutes/{id}`と`sharedTrips/{id}`に共通する項目を読み取る。
 * どちらもiOSアプリ（`SyncService`）が同じ項目名で書き込むため、読み取りもここに1本化する。
 */
export function parseTripFields(id: string, data: DocumentData): WalkTrip {
  return {
    id,
    title: data.title ?? null,
    description: data.notes ?? null,
    latitudes: Array.isArray(data.latitudes) ? data.latitudes : [],
    longitudes: Array.isArray(data.longitudes) ? data.longitudes : [],
    startedAt: data.startedAt instanceof Timestamp ? data.startedAt.toDate() : new Date(),
    endedAt: data.endedAt instanceof Timestamp ? data.endedAt.toDate() : null,
    stepCount: typeof data.stepCount === "number" ? data.stepCount : null,
    overlayMapID: data.overlayMapID ?? null,
    totalDistanceMeters: typeof data.totalDistanceMeters === "number" ? data.totalDistanceMeters : 0,
    journalTitle: data.travelJournalTitle ?? null,
    journalMarkdown: data.travelJournalMarkdown ?? null,
    tripVideoURL: typeof data.tripVideoURL === "string" && data.tripVideoURL.length > 0 ? data.tripVideoURL : null,
  };
}
