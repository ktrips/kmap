import type { SharedTrip } from "../types/sharedTrip";
import { findOldMap } from "../lib/oldMapCatalog";

interface Props {
  trips: SharedTrip[];
  selectedId: string | null;
  onSelect: (trip: SharedTrip) => void;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  dateStyle: "medium",
  timeStyle: "short",
});

function distanceLabel(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

/** 全ユーザーが公開している時空旅の一覧。 */
export function SharedTripList({ trips, selectedId, onSelect }: Props) {
  if (trips.length === 0) {
    return (
      <div className="place-list-empty">
        <p>まだ公開されている時空旅がありません。</p>
        <p className="muted">
          iOSアプリの時間旅の記録詳細で「みんなの時空旅に公開する」を選ぶと、ここに表示されます。
        </p>
      </div>
    );
  }

  return (
    <ul className="place-list">
      {trips.map((trip) => {
        const oldMap = findOldMap(trip.overlayMapID);
        return (
          <li key={trip.id}>
            <button
              className={`place-list-item ${trip.id === selectedId ? "is-selected" : ""}`}
              onClick={() => onSelect(trip)}
            >
              <span className="place-title">
                {trip.title && trip.title.length > 0 ? trip.title : dateFormatter.format(trip.startedAt)}
              </span>
              {oldMap && <span className="place-era">{oldMap.title}</span>}
              <span className="place-story-preview">
                {distanceLabel(trip.totalDistanceMeters)}
                {trip.ownerDisplayName ? ` ・ ${trip.ownerDisplayName}` : ""}
              </span>
              <span className="place-date">{dateFormatter.format(trip.startedAt)}</span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
