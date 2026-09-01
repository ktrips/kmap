/** 全ユーザー共通で公開された時空旅。Firestoreの `sharedTrips/{id}` に対応する。 */
export interface SharedTrip {
  id: string;
  ownerUserID: string;
  ownerDisplayName: string | null;
  title: string | null;
  latitudes: number[];
  longitudes: number[];
  startedAt: Date;
  endedAt: Date | null;
  stepCount: number | null;
  overlayMapID: string | null;
  totalDistanceMeters: number;
  photoURLs: string[];
}
