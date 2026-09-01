/** ウォーキング中に投稿した写真。Firestoreの `users/{uid}/photoPosts/{id}` に対応する。 */
export interface PhotoPost {
  id: string;
  photoURL: string | null;
  postedAt: Date;
  points: number;
  latitude: number;
  longitude: number;
  walkRouteID: string | null;
  placeName: string | null;
}
