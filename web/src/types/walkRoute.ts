/** iOSアプリ（Komap）で保存された1回分の時間旅。Firestoreの `users/{uid}/walkRoutes/{id}` に対応する。 */
export interface WalkTrip {
  id: string;
  title: string | null;
  latitudes: number[];
  longitudes: number[];
  startedAt: Date;
  endedAt: Date | null;
  stepCount: number | null;
  overlayMapID: string | null;
  totalDistanceMeters: number;
}
