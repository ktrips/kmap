/** 獲得した御朱印。Firestoreの `users/{uid}/stamps/{id}` に対応する。 */
export interface Stamp {
  id: string;
  siteID: string;
  collectedAt: Date;
  photoURL: string | null;
  walkRouteID: string | null;
  /** その御朱印スポットの説明文。未生成なら`null`。 */
  detail: string | null;
}
