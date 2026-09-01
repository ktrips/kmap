import type { UnifiedTrip } from "../types/unifiedTrip";
import { findOldMap } from "../lib/oldMapCatalog";

interface Props {
  trips: UnifiedTrip[];
  selectedId: string | null;
  onSelect: (trip: UnifiedTrip) => void;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  dateStyle: "medium",
  timeStyle: "short",
});

function distanceLabel(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

/** 「時空旅」タブの一覧。自分の時空旅と、他ユーザーが公開した時空旅を一緒に並べる。 */
export function TripList({ trips, selectedId, onSelect }: Props) {
  if (trips.length === 0) {
    return (
      <div className="place-list-empty">
        <p>まだ時空旅の記録がありません。</p>
        <p className="muted">
          iOSアプリ（またはApple Watch）で「スタート」して記録を保存すると、ここに表示されます。
        </p>
      </div>
    );
  }

  return (
    <ul className="place-list">
      {trips.map((trip) => {
        const oldMap = findOldMap(trip.overlayMapID);
        return (
          <li key={`${trip.kind}-${trip.id}`}>
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
                {trip.kind === "shared" && trip.ownerDisplayName ? ` ・ ${trip.ownerDisplayName}` : ""}
                {trip.kind === "own" ? " ・ 自分の時空旅" : " ・ 共有された時空旅"}
              </span>
              <span className="place-date">{dateFormatter.format(trip.startedAt)}</span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
