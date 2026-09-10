/** iOSアプリ（Komap）で保存された1回分の時間旅。Firestoreの `users/{uid}/walkRoutes/{id}` に対応する。 */
export interface WalkTrip {
  id: string;
  title: string | null;
  /** 感想・説明（iOS側の`notes`）。Webからも編集できる。 */
  description: string | null;
  latitudes: number[];
  longitudes: number[];
  startedAt: Date;
  endedAt: Date | null;
  stepCount: number | null;
  overlayMapID: string | null;
  totalDistanceMeters: number;
  /** AIが生成した旅日記の見出し。未生成なら`null`。 */
  journalTitle: string | null;
  /** AIが生成した旅日記の本文（Markdown形式）。未生成なら`null`。 */
  journalMarkdown: string | null;
}
