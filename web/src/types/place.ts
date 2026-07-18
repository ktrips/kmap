/** iOSアプリ（Komap）で保存された1地点。Firestoreの `users/{uid}/places/{id}` に対応する。 */
export interface SavedPlace {
  id: string;
  title: string;
  latitude: number;
  longitude: number;
  overlayMapID: string | null;
  era: string;
  storyText: string;
  createdAt: Date;
}
