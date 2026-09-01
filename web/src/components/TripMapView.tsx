import { useEffect, useRef } from "react";
import { useGoogleMaps } from "../lib/useGoogleMaps";

interface Props {
  latitudes: number[];
  longitudes: number[];
}

/** 選んだ時空旅の歩いたルートを、素のGoogle Map上にポリラインで表示する小さな地図。 */
export function TripMapView({ latitudes, longitudes }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const { isLoaded, error, isConfigured } = useGoogleMaps();

  useEffect(() => {
    if (!isLoaded || !containerRef.current) return;

    const path = latitudes.map((lat, i) => ({ lat, lng: longitudes[i] }));
    if (path.length === 0) return;

    const map = new google.maps.Map(containerRef.current, {
      center: path[0],
      zoom: 15,
      disableDefaultUI: true,
      gestureHandling: "cooperative",
    });

    if (path.length >= 2) {
      new google.maps.Polyline({
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
      new google.maps.Marker({ position: path[0], map });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoaded, latitudes, longitudes]);

  if (!isConfigured || error) {
    return null;
  }

  return <div ref={containerRef} className="trip-map-view" />;
}
