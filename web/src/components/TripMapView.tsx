import { useEffect, useRef } from "react";
import { useGoogleMaps } from "../lib/useGoogleMaps";

interface Props {
  latitudes: number[];
  longitudes: number[];
}

/** 選んだ時空旅の歩いたルートを、素のGoogle Map上にポリラインで表示する小さな地図。 */
export function TripMapView({ latitudes, longitudes }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const polylineRef = useRef<google.maps.Polyline | null>(null);
  const markerRef = useRef<google.maps.Marker | null>(null);
  const { isLoaded, error, isConfigured } = useGoogleMaps();

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
  }, [isLoaded, latitudes, longitudes]);

  if (!isConfigured || error) {
    return null;
  }

  return <div ref={containerRef} className="trip-map-view" />;
}
