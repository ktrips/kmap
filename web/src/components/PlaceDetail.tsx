import { findOldMap } from "../lib/oldMapCatalog";
import type { SavedPlace } from "../types/place";

interface Props {
  place: SavedPlace | null;
}

export function PlaceDetail({ place }: Props) {
  if (!place) {
    return (
      <div className="place-detail place-detail-empty">
        <p>リストまたは地図のピンから、記録を選んでください。</p>
      </div>
    );
  }

  const oldMap = findOldMap(place.overlayMapID);

  return (
    <div className="place-detail">
      <p className="place-detail-era">{place.era}</p>
      <h2>{place.title}</h2>
      {oldMap && <p className="place-detail-oldmap">重ねていた古地図：{oldMap.title}</p>}
      <p className="place-detail-coordinate">
        緯度 {place.latitude.toFixed(5)} / 経度 {place.longitude.toFixed(5)}
      </p>
      <p className="place-detail-story">{place.storyText}</p>
    </div>
  );
}
