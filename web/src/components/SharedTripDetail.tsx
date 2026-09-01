import { findOldMap } from "../lib/oldMapCatalog";
import type { SharedTrip } from "../types/sharedTrip";

interface Props {
  trip: SharedTrip | null;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  dateStyle: "medium",
  timeStyle: "short",
});

function distanceLabel(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

function durationLabel(trip: SharedTrip): string | null {
  if (!trip.endedAt) return null;
  const totalMinutes = Math.round((trip.endedAt.getTime() - trip.startedAt.getTime()) / 60000);
  if (totalMinutes >= 60) return `${Math.floor(totalMinutes / 60)}時間${totalMinutes % 60}分`;
  return `${Math.max(totalMinutes, 1)}分`;
}

export function SharedTripDetail({ trip }: Props) {
  if (!trip) {
    return (
      <div className="place-detail place-detail-empty">
        <p>左のリストから、みんなの時空旅を選んでください。</p>
      </div>
    );
  }

  const oldMap = findOldMap(trip.overlayMapID);
  const duration = durationLabel(trip);

  return (
    <div className="place-detail">
      <p className="place-detail-era">{dateFormatter.format(trip.startedAt)}</p>
      <h2>{trip.title && trip.title.length > 0 ? trip.title : "時空旅の記録"}</h2>
      {trip.ownerDisplayName && <p className="place-detail-oldmap">投稿者：{trip.ownerDisplayName}</p>}
      {oldMap && <p className="place-detail-oldmap">使っていた古地図：{oldMap.title}</p>}
      <p className="place-detail-coordinate">
        {distanceLabel(trip.totalDistanceMeters)}
        {duration ? ` ・ ${duration}` : ""}
        {trip.stepCount ? ` ・ ${trip.stepCount}歩` : ""}
      </p>
    </div>
  );
}
