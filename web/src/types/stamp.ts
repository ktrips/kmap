/** 獲得した御朱印。Firestoreの `users/{uid}/stamps/{id}` に対応する。 */
export interface Stamp {
  id: string;
  siteID: string;
  collectedAt: Date;
  photoURL: string | null;
  walkRouteID: string | null;
}
