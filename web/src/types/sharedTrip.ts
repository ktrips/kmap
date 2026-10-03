/** 御朱印・投稿写真1枚分（URLと、史跡名／地点名のラベル）。 */
export interface SharedPhoto {
  url: string;
  label: string;
  /** その場所についての説明文（AIが生成した物語など）。無ければ`undefined`。 */
  detail?: string;
}

/** 公開中の時空旅。Firestoreの`users/{uid}/walkRoutes/{id}`（`isSharedPublicly == true`）に対応する。 */
export interface SharedTrip {
  id: string;
  ownerUserID: string;
  /** 旅の文書のパス（`users/{uid}/walkRoutes/{id}`）。一覧では読まない軌跡の座標を、開いた時に読むのに使う。 */
  documentPath: string;
  ownerDisplayName: string | null;
  title: string | null;
  /** 感想・説明。Webからも編集できる。 */
  description: string | null;
  /** 軌跡の座標。一覧では読まないので空（旅を開いた時に`useTripRoute`が読む）。 */
  latitudes: number[];
  longitudes: number[];
  /** 歩き始めた地点（一覧でリージョンを決めるのに使う。Cloud Functionsが書く）。 */
  startLatitude: number | null;
  startLongitude: number | null;
  startedAt: Date;
  endedAt: Date | null;
  stepCount: number | null;
  overlayMapID: string | null;
  totalDistanceMeters: number;
  /** 史跡チェックポイントで獲得した御朱印の写真。 */
  stampPhotos: SharedPhoto[];
  /** ウォーキング中に自由投稿した写真。 */
  postPhotos: SharedPhoto[];
  /** AIが生成した旅日記の見出し。未生成なら`null`。 */
  journalTitle: string | null;
  /** AIが生成した旅日記の本文（Markdown形式）。未生成なら`null`。 */
  journalMarkdown: string | null;
  /** iOSアプリで作った旅の動画（MP4）のクラウド上のURL。未作成なら`null`。 */
  tripVideoURL: string | null;
  /** いいね・コメントの件数（Cloud Functionsが書く）。まだ無い旅は`null`で、その時は集計クエリで数える。 */
  likeCount: number | null;
  commentCount: number | null;
}
