import { findOldMap, OLD_MAP_CATALOG, type OldMapEntry } from "./oldMapCatalog";
import type { UnifiedTrip } from "../types/unifiedTrip";

/** iOSアプリの`MapRegion`と同じ4つのリージョン。 */
export type MapRegion = "japan" | "europe" | "asia" | "america";

/** リージョンごとに分けて並べる時の順番（iOSの`MapRegion.displayOrder`と同じ）。 */
export const REGION_ORDER: MapRegion[] = ["europe", "america", "japan", "asia"];

export const REGION_LABEL: Record<MapRegion, string> = {
  japan: "Japan（日本）",
  europe: "Europe（ヨーロッパ）",
  asia: "Asia（アジア・その他）",
  america: "America（南北アメリカ）",
};

/** 時空旅の一覧で、旅の名前の横に小さく添える短い表記。 */
export const REGION_SHORT_LABEL: Record<MapRegion, string> = {
  japan: "Japan",
  europe: "Europe",
  asia: "Asia",
  america: "America",
};

/** 位置からリージョンを決める（iOSの`MapRegion(containing:)`と同じ範囲）。 */
export function regionOf(lat: number, lng: number): MapRegion {
  if (lat >= 24 && lat <= 46 && lng >= 122 && lng <= 154) return "japan";
  if (lat >= 34 && lat <= 72 && lng >= -25 && lng <= 45) return "europe";
  if (lng >= -170 && lng <= -30) return "america";
  return "asia";
}

/** 画像と範囲を持つ（統合で廃止されていない）古地図だけ。 */
export const VISIBLE_OLD_MAPS = OLD_MAP_CATALOG.filter((map) => map.imageUrl && map.southWest && map.northEast);

/** 古地図のリージョン（地図の中心の位置で決める）。 */
export function oldMapRegion(map: OldMapEntry): MapRegion {
  const sw = map.southWest ?? { lat: 0, lng: 0 };
  const ne = map.northEast ?? sw;
  return regionOf((sw.lat + ne.lat) / 2, (sw.lng + ne.lng) / 2);
}

/** 旅のリージョン。使った古地図があればその古地図の、無ければ歩き始めた地点のリージョン。 */
export function tripRegion(trip: UnifiedTrip): MapRegion {
  const map = findOldMap(trip.overlayMapID);
  if (map?.southWest && map.northEast) {
    return regionOf((map.southWest.lat + map.northEast.lat) / 2, (map.southWest.lng + map.northEast.lng) / 2);
  }
  if (trip.latitudes.length > 0 && trip.longitudes.length > 0) {
    return regionOf(trip.latitudes[0], trip.longitudes[0]);
  }
  return "japan";
}

/** 各リージョンの中での並び順（iOSの`TripSortOrder`と同じ）。 */
export type TripSortOrder = "likes" | "date" | "distance";

export function compareTrips(order: TripSortOrder, likes: (id: string) => number) {
  return (a: UnifiedTrip, b: UnifiedTrip): number => {
    if (order === "distance") return b.totalDistanceMeters - a.totalDistanceMeters;
    if (order === "date") return b.startedAt.getTime() - a.startedAt.getTime();
    // いいねの多い順。同じ数なら日付の新しい順、さらに距離の長い順。
    return (
      likes(b.id) - likes(a.id) ||
      b.startedAt.getTime() - a.startedAt.getTime() ||
      b.totalDistanceMeters - a.totalDistanceMeters
    );
  };
}
