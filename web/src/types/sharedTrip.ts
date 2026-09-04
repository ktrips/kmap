/** 御朱印・投稿写真1枚分（URLと、史跡名／地点名のラベル）。 */
export interface SharedPhoto {
  url: string;
  label: string;
}

/** 全ユーザー共通で公開された時空旅。Firestoreの `sharedTrips/{id}` に対応する。 */
export interface SharedTrip {
  id: string;
  ownerUserID: string;
  ownerDisplayName: string | null;
  title: string | null;
  /** 感想・説明。Webからも編集できる。 */
  description: string | null;
  latitudes: number[];
  longitudes: number[];
  startedAt: Date;
  endedAt: Date | null;
  stepCount: number | null;
  overlayMapID: string | null;
  totalDistanceMeters: number;
  /** 史跡チェックポイントで獲得した御朱印の写真。 */
  stampPhotos: SharedPhoto[];
  /** ウォーキング中に自由投稿した写真。 */
  postPhotos: SharedPhoto[];
}
