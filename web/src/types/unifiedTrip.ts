import type { WalkTrip } from "./walkRoute";
import type { SharedPhoto, SharedTrip } from "./sharedTrip";
import type { Stamp } from "./stamp";
import type { PhotoPost } from "./photoPost";
import { findHistoricSite } from "../lib/historicSiteCatalog";

/** 「時空旅」タブで、自分の時空旅と共有された時空旅をまとめて扱うための共通の形。 */
export interface UnifiedTrip {
  id: string;
  kind: "own" | "shared";
  title: string | null;
  /** 感想・説明。サインインしていれば自分の時空旅をWebから編集できる。 */
  description: string | null;
  latitudes: number[];
  longitudes: number[];
  startedAt: Date;
  endedAt: Date | null;
  stepCount: number | null;
  overlayMapID: string | null;
  totalDistanceMeters: number;
  ownerDisplayName: string | null;
  /** 史跡チェックポイントで獲得した御朱印の写真（史跡名つき）。 */
  stampPhotos: SharedPhoto[];
  /** ウォーキング中に自由投稿した写真（地点名つき）。 */
  postPhotos: SharedPhoto[];
  /** 獲得した御朱印の数。共有された時空旅では持ち主以外に分からないため`null`。 */
  stampCount: number | null;
  /** 自分の時空旅（`kind: "own"`）が、「みんなの時空旅」として公開中かどうか。 */
  isShared: boolean;
}

export function fromWalkTrip(
  trip: WalkTrip,
  stamps: Stamp[],
  photoPosts: PhotoPost[],
  isShared: boolean,
): UnifiedTrip {
  const tripStamps = stamps.filter((stamp) => stamp.walkRouteID === trip.id);
  const tripPhotoPosts = photoPosts.filter((post) => post.walkRouteID === trip.id);
  const stampPhotos: SharedPhoto[] = tripStamps
    .filter((stamp) => Boolean(stamp.photoURL))
    .map((stamp) => ({
      url: stamp.photoURL as string,
      label: findHistoricSite(stamp.siteID)?.name ?? "御朱印",
    }));
  const postPhotos: SharedPhoto[] = tripPhotoPosts
    .filter((post) => Boolean(post.photoURL))
    .map((post) => ({
      url: post.photoURL as string,
      label: post.placeName ?? "",
    }));

  return {
    id: trip.id,
    kind: "own",
    title: trip.title,
    description: trip.description,
    latitudes: trip.latitudes,
    longitudes: trip.longitudes,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    stepCount: trip.stepCount,
    overlayMapID: trip.overlayMapID,
    totalDistanceMeters: trip.totalDistanceMeters,
    ownerDisplayName: null,
    stampPhotos,
    postPhotos,
    stampCount: tripStamps.length,
    isShared,
  };
}

export function fromSharedTrip(trip: SharedTrip): UnifiedTrip {
  return {
    id: trip.id,
    kind: "shared",
    title: trip.title,
    description: trip.description,
    latitudes: trip.latitudes,
    longitudes: trip.longitudes,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    stepCount: trip.stepCount,
    overlayMapID: trip.overlayMapID,
    totalDistanceMeters: trip.totalDistanceMeters,
    // プライバシーのため、表示名は先頭6文字だけにする（サージケートペアも1文字として数える）。
    ownerDisplayName: trip.ownerDisplayName ? Array.from(trip.ownerDisplayName).slice(0, 6).join("") : null,
    stampPhotos: trip.stampPhotos,
    postPhotos: trip.postPhotos,
    stampCount: null,
    isShared: true,
  };
}
