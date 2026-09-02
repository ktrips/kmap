import type { WalkTrip } from "./walkRoute";
import type { SharedTrip } from "./sharedTrip";
import type { Stamp } from "./stamp";
import type { PhotoPost } from "./photoPost";

/** 「時空旅」タブで、自分の時空旅と共有された時空旅をまとめて扱うための共通の形。 */
export interface UnifiedTrip {
  id: string;
  kind: "own" | "shared";
  title: string | null;
  latitudes: number[];
  longitudes: number[];
  startedAt: Date;
  endedAt: Date | null;
  stepCount: number | null;
  overlayMapID: string | null;
  totalDistanceMeters: number;
  ownerDisplayName: string | null;
  photoURLs: string[];
  /** 獲得した御朱印の数。共有された時空旅では持ち主以外に分からないため`null`。 */
  stampCount: number | null;
}

export function fromWalkTrip(trip: WalkTrip, stamps: Stamp[], photoPosts: PhotoPost[]): UnifiedTrip {
  const tripStamps = stamps.filter((stamp) => stamp.walkRouteID === trip.id);
  const tripPhotoPosts = photoPosts.filter((post) => post.walkRouteID === trip.id);
  const photoURLs = [
    ...tripStamps.map((stamp) => stamp.photoURL),
    ...tripPhotoPosts.map((post) => post.photoURL),
  ].filter((url): url is string => Boolean(url));

  return {
    id: trip.id,
    kind: "own",
    title: trip.title,
    latitudes: trip.latitudes,
    longitudes: trip.longitudes,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    stepCount: trip.stepCount,
    overlayMapID: trip.overlayMapID,
    totalDistanceMeters: trip.totalDistanceMeters,
    ownerDisplayName: null,
    photoURLs,
    stampCount: tripStamps.length,
  };
}

export function fromSharedTrip(trip: SharedTrip): UnifiedTrip {
  return {
    id: trip.id,
    kind: "shared",
    title: trip.title,
    latitudes: trip.latitudes,
    longitudes: trip.longitudes,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    stepCount: trip.stepCount,
    overlayMapID: trip.overlayMapID,
    totalDistanceMeters: trip.totalDistanceMeters,
    // プライバシーのため、表示名は先頭6文字だけにする（サージケートペアも1文字として数える）。
    ownerDisplayName: trip.ownerDisplayName ? Array.from(trip.ownerDisplayName).slice(0, 6).join("") : null,
    photoURLs: trip.photoURLs,
    stampCount: null,
  };
}
