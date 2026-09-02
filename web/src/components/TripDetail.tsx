import { findOldMap } from "../lib/oldMapCatalog";
import { TripMapView } from "./TripMapView";
import type { UnifiedTrip } from "../types/unifiedTrip";

interface Props {
  trip: UnifiedTrip | null;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  dateStyle: "medium",
  timeStyle: "short",
});

function distanceLabel(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

function durationLabel(trip: UnifiedTrip): string | null {
  if (!trip.endedAt) return null;
  const totalMinutes = Math.round((trip.endedAt.getTime() - trip.startedAt.getTime()) / 60000);
  if (totalMinutes >= 60) return `${Math.floor(totalMinutes / 60)}時間${totalMinutes % 60}分`;
  return `${Math.max(totalMinutes, 1)}分`;
}

/** 選んだ時空旅の、使った古地図・歩いたルート・写真・御朱印をまとめて見せる詳細パネル。 */
export function TripDetail({ trip }: Props) {
  if (!trip) {
    return (
      <div className="place-detail place-detail-empty">
        <p>左のリストから、時空旅を選んでください。</p>
      </div>
    );
  }

  const oldMap = findOldMap(trip.overlayMapID);
  const duration = durationLabel(trip);

  return (
    <div className="place-detail">
      {trip.latitudes.length > 0 && <TripMapView latitudes={trip.latitudes} longitudes={trip.longitudes} />}

      <p className="place-detail-era">{dateFormatter.format(trip.startedAt)}</p>
      <h2>{trip.title && trip.title.length > 0 ? trip.title : "時空旅の記録"}</h2>
      {trip.kind === "shared" && trip.ownerDisplayName && (
        <p className="place-detail-oldmap">投稿者：{trip.ownerDisplayName}</p>
      )}
      {oldMap && <p className="place-detail-oldmap">使っていた古地図：{oldMap.title}</p>}
      <p className="place-detail-coordinate">
        {distanceLabel(trip.totalDistanceMeters)}
        {duration ? ` ・ ${duration}` : ""}
        {trip.stepCount ? ` ・ ${trip.stepCount}歩` : ""}
        {trip.stampCount !== null ? ` ・ 御朱印 ${trip.stampCount}件` : ""}
      </p>

      {trip.stampPhotos.length > 0 && (
        <div className="shared-trip-photo-section">
          <p className="shared-trip-photo-section-title">御朱印</p>
          <div className="shared-trip-photos">
            {trip.stampPhotos.map((photo) => (
              <figure key={photo.url} className="shared-trip-photo-item">
                <img src={photo.url} alt={photo.label} className="shared-trip-photo" loading="lazy" />
                <figcaption>{photo.label}</figcaption>
              </figure>
            ))}
          </div>
        </div>
      )}

      {trip.postPhotos.length > 0 && (
        <div className="shared-trip-photo-section">
          <p className="shared-trip-photo-section-title">投稿写真</p>
          <div className="shared-trip-photos">
            {trip.postPhotos.map((photo) => (
              <figure key={photo.url} className="shared-trip-photo-item">
                <img src={photo.url} alt={photo.label} className="shared-trip-photo" loading="lazy" />
                {photo.label && <figcaption>{photo.label}</figcaption>}
              </figure>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
