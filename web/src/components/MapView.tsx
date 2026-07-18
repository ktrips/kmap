import { useEffect, useRef } from "react";
import { useGoogleMaps } from "../lib/useGoogleMaps";
import type { SavedPlace } from "../types/place";

interface Props {
  places: SavedPlace[];
  selectedId: string | null;
  onSelect: (place: SavedPlace) => void;
}

const TOKYO_CENTER = { lat: 35.6812, lng: 139.767 };

export function MapView({ places, selectedId, onSelect }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const markersRef = useRef<Map<string, google.maps.Marker>>(new Map());
  const { isLoaded, error, isConfigured } = useGoogleMaps();

  useEffect(() => {
    if (!isLoaded || !containerRef.current || mapRef.current) return;
    mapRef.current = new google.maps.Map(containerRef.current, {
      center: TOKYO_CENTER,
      zoom: 12,
    });
  }, [isLoaded]);

  useEffect(() => {
    if (!isLoaded || !mapRef.current) return;
    const map = mapRef.current;

    markersRef.current.forEach((marker) => {
      marker.setMap(null);
    });
    markersRef.current.clear();

    places.forEach((place) => {
      const marker = new google.maps.Marker({
        position: { lat: place.latitude, lng: place.longitude },
        map,
        title: place.title,
      });
      marker.addListener("click", () => onSelect(place));
      markersRef.current.set(place.id, marker);
    });

    if (places.length > 0) {
      const bounds = new google.maps.LatLngBounds();
      places.forEach((place) => bounds.extend({ lat: place.latitude, lng: place.longitude }));
      map.fitBounds(bounds, 64);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoaded, places]);

  useEffect(() => {
    if (!isLoaded || !mapRef.current || !selectedId) return;
    const place = places.find((p) => p.id === selectedId);
    if (place) {
      mapRef.current.panTo({ lat: place.latitude, lng: place.longitude });
    }
  }, [isLoaded, selectedId, places]);

  if (!isConfigured) {
    return (
      <div className="map-placeholder">
        <p>Google Maps APIキーが未設定です。</p>
        <p className="muted"><code>web/.env</code> の VITE_GOOGLE_MAPS_API_KEY を設定してください。</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="map-placeholder">
        <p>{error}</p>
      </div>
    );
  }

  return <div className="map-view" ref={containerRef} />;
}
