import { collection, getDocs, limit, orderBy, query, type DocumentData } from "firebase/firestore/lite";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { HistoricSiteEntry } from "./historicSiteCatalog";
import type { OldMapEntry } from "./oldMapCatalog";

/**
 * `sharedOverlayMaps/{id}`（iOSアプリで個人が作って公開した古地図）の1ドキュメントを、同梱の古地図と
 * 同じ`OldMapEntry`に変換する（iOSの`RemoteOverlayMap`と同じ項目）。必要な項目が無ければ`null`。
 */
function parseSharedOverlayMap(id: string, data: DocumentData): OldMapEntry | null {
  const { title, imageURL, southWestLat, southWestLng, northEastLat, northEastLng } = data;
  if (
    typeof title !== "string" ||
    typeof imageURL !== "string" ||
    ![southWestLat, southWestLng, northEastLat, northEastLng].every((value) => typeof value === "number")
  ) {
    return null;
  }
  const checkpoints: HistoricSiteEntry[] = Array.isArray(data.checkpoints)
    ? data.checkpoints.flatMap((item: Record<string, unknown>, index: number) =>
        item && typeof item.name === "string" && typeof item.lat === "number" && typeof item.lng === "number"
          ? [{ id: `${id}-${index}`, name: item.name, overlayMapID: id, coordinate: { lat: item.lat, lng: item.lng } }]
          : [],
      )
    : [];
  return {
    id,
    title,
    era: typeof data.era === "string" ? data.era : "",
    summary: typeof data.summary === "string" ? data.summary : undefined,
    imageUrl: imageURL,
    southWest: { lat: southWestLat, lng: southWestLng },
    northEast: { lat: northEastLat, lng: northEastLng },
    ownerDisplayName: typeof data.ownerDisplayName === "string" ? data.ownerDisplayName : null,
    checkpoints,
  };
}

/**
 * 個人が作って公開した古地図（「みんなの古地図」）を、更新の新しい順に60件まで読み込む
 * （iOSの`OverlayMapShareService.fetchPublicMaps`と同じ）。サインインしていなくても読める。
 */
export function useSharedOverlayMaps(): OldMapEntry[] {
  const [maps, setMaps] = useState<OldMapEntry[]>([]);

  useEffect(() => {
    const firestore = db;
    if (!firestore) return;
    let cancelled = false;
    getDocs(query(collection(firestore, "sharedOverlayMaps"), orderBy("updatedAt", "desc"), limit(60)))
      .then((snapshot) => {
        if (cancelled) return;
        setMaps(
          snapshot.docs
            .map((doc) => parseSharedOverlayMap(doc.id, doc.data()))
            .filter((map): map is OldMapEntry => map !== null),
        );
      })
      .catch((err: unknown) => {
        // 一覧の補足なので、読めなくても同梱の古地図だけで表示を続ける。
        console.warn("みんなの古地図を読み込めませんでした", err);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return maps;
}
