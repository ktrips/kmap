import { useEffect, useRef, useState } from "react";
import { useGoogleMaps } from "../lib/useGoogleMaps";
import type { OldMapEntry } from "../lib/oldMapCatalog";
import type { HistoricSiteEntry } from "../lib/historicSiteCatalog";

interface Props {
  latitudes: number[];
  longitudes: number[];
  /** この時空旅で使っていた古地図（画像・範囲を持つ場合のみ重ねて表示する）。 */
  oldMap?: OldMapEntry;
  /** この時空旅で使っていた古地図に属する史跡チェックポイント（iOS版と同じ赤いマーカーで表示）。 */
  checkpoints?: HistoricSiteEntry[];
}

/**
 * 選んだ時空旅の歩いたルートを、Google Map上にポリラインで表示する小さな地図。
 * 使っていた古地図の画像情報（`imageUrl`・範囲）があれば、iOS版と同じように
 * その古地図をオーバーレイとして重ねて表示する。
 *
 * - Important: Google Maps JavaScript APIの`GroundOverlay`は回転（bearing）を
 *   サポートしないため、iOS版で回転させて位置合わせしている古地図
 *   （現状`goshiki-fudo-meiji`のみ）は、Web版では回転無しで表示される。
 */
export function TripMapView({ latitudes, longitudes, oldMap, checkpoints = [] }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const polylineRef = useRef<google.maps.Polyline | null>(null);
  const markerRef = useRef<google.maps.Marker | null>(null);
  const overlayRef = useRef<google.maps.GroundOverlay | null>(null);
  const checkpointMarkersRef = useRef<google.maps.Marker[]>([]);
  const infoWindowRef = useRef<google.maps.InfoWindow | null>(null);
  const { isLoaded, error, isConfigured } = useGoogleMaps();
  const [opacity, setOpacity] = useState(0.6);

  useEffect(() => {
    if (!isLoaded || !containerRef.current) return;

    const path = latitudes.map((lat, i) => ({ lat, lng: longitudes[i] }));
    if (path.length === 0) return;

    // 時空旅を選び直すたびにMapインスタンスを作り直すと、古いインスタンスが
    // 破棄されずに残ってメモリ・描画負荷が積み重なるため、1つだけ作って使い回す。
    if (!mapRef.current) {
      mapRef.current = new google.maps.Map(containerRef.current, {
        center: path[0],
        zoom: 15,
        disableDefaultUI: true,
        gestureHandling: "cooperative",
      });
    }
    const map = mapRef.current;

    polylineRef.current?.setMap(null);
    polylineRef.current = null;
    markerRef.current?.setMap(null);
    markerRef.current = null;
    overlayRef.current?.setMap(null);
    overlayRef.current = null;
    checkpointMarkersRef.current.forEach((marker) => marker.setMap(null));
    checkpointMarkersRef.current = [];

    if (checkpoints.length > 0 && !infoWindowRef.current) {
      infoWindowRef.current = new google.maps.InfoWindow();
    }
    checkpointMarkersRef.current = checkpoints.map((checkpoint) => {
      const marker = new google.maps.Marker({
        position: checkpoint.coordinate,
        map,
        title: checkpoint.name,
      });
      marker.addListener("click", () => {
        infoWindowRef.current?.setContent(checkpoint.name);
        infoWindowRef.current?.open(map, marker);
      });
      return marker;
    });

    if (oldMap?.imageUrl && oldMap.southWest && oldMap.northEast) {
      overlayRef.current = new google.maps.GroundOverlay(oldMap.imageUrl, {
        south: oldMap.southWest.lat,
        west: oldMap.southWest.lng,
        north: oldMap.northEast.lat,
        east: oldMap.northEast.lng,
      });
      overlayRef.current.setOpacity(opacity);
      overlayRef.current.setMap(map);
    }

    if (path.length >= 2) {
      polylineRef.current = new google.maps.Polyline({
        path,
        strokeColor: "#733c1a",
        strokeOpacity: 0.9,
        strokeWeight: 5,
        map,
      });

      const bounds = new google.maps.LatLngBounds();
      path.forEach((point) => bounds.extend(point));
      map.fitBounds(bounds, 32);
    } else {
      markerRef.current = new google.maps.Marker({ position: path[0], map });
      map.setCenter(path[0]);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoaded, latitudes, longitudes, oldMap, checkpoints]);

  // 濃度スライダーはオーバーレイの作り直しなしに反映したいので、別のeffectに分けている。
  useEffect(() => {
    overlayRef.current?.setOpacity(opacity);
  }, [opacity]);

  if (!isConfigured || error) {
    return null;
  }

  return (
    <div className="trip-map-wrap">
      <div ref={containerRef} className="trip-map-view" />
      {oldMap?.imageUrl && (
        <div className="trip-map-opacity">
          <span>現在</span>
          <input
            type="range"
            min={0}
            max={1}
            step={0.05}
            value={opacity}
            onChange={(e) => setOpacity(Number(e.target.value))}
            aria-label="古地図の濃度"
          />
          <span>古地図</span>
        </div>
      )}
    </div>
  );
}
