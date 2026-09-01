import type { WalkTrip } from "../types/walkRoute";
import { findOldMap } from "../lib/oldMapCatalog";

interface Props {
  trips: WalkTrip[];
  selectedId: string | null;
  onSelect: (trip: WalkTrip) => void;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  dateStyle: "medium",
  timeStyle: "short",
});

function distanceLabel(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

interface TripGroup {
  overlayMapID: string | null;
  mapTitle: string;
  trips: WalkTrip[];
}

function groupTrips(trips: WalkTrip[]): TripGroup[] {
  const order: (string | null)[] = [];
  const byKey = new Map<string | null, WalkTrip[]>();

  for (const trip of trips) {
    const key = trip.overlayMapID;
    if (!byKey.has(key)) {
      order.push(key);
      byKey.set(key, []);
    }
    byKey.get(key)!.push(trip);
  }

  return order.map((key) => ({
    overlayMapID: key,
    mapTitle: findOldMap(key)?.title ?? "古地図なし",
    trips: byKey.get(key) ?? [],
  }));
}

/** My TimeTripの「歩いた地図」と対になる、古地図ごとにまとめた時間旅の一覧。 */
export function TripList({ trips, selectedId, onSelect }: Props) {
  if (trips.length === 0) {
    return (
      <div className="place-list-empty">
        <p>まだ時間旅の記録がありません。</p>
        <p className="muted">iOSアプリ（またはApple Watch）で「スタート」して記録を保存すると、ここに表示されます。</p>
      </div>
    );
  }

  const groups = groupTrips(trips);

  return (
    <div className="trip-groups">
      {groups.map((group) => (
        <section key={group.overlayMapID ?? "none"} className="trip-group">
          <h3 className="trip-group-title">
            {group.mapTitle}
            <span className="trip-group-count">{group.trips.length}回</span>
          </h3>
          <ul className="place-list">
            {group.trips.map((trip) => (
              <li key={trip.id}>
                <button
                  className={`place-list-item ${trip.id === selectedId ? "is-selected" : ""}`}
                  onClick={() => onSelect(trip)}
                >
                  <span className="place-title">
                    {trip.title && trip.title.length > 0 ? trip.title : dateFormatter.format(trip.startedAt)}
                  </span>
                  <span className="place-story-preview">
                    {distanceLabel(trip.totalDistanceMeters)}
                    {trip.stepCount ? ` ・ ${trip.stepCount}歩` : ""}
                  </span>
                  <span className="place-date">{dateFormatter.format(trip.startedAt)}</span>
                </button>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}
