import type { UnifiedTrip } from "../types/unifiedTrip";
import { findOldMap } from "../lib/oldMapCatalog";
import { useTripEngagementCounts } from "../lib/useTripEngagementCounts";

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

/** 一覧の1行に添える、いいね・コメント件数（0件の間は表示しない）。 */
function TripEngagementCounts({ tripId }: { tripId: string }) {
  const { likeCount, commentCount } = useTripEngagementCounts(tripId);
  if (likeCount === 0 && commentCount === 0) return null;
  return (
    <span className="place-story-preview trip-engagement-counts">
      {likeCount > 0 ? `❤️ ${likeCount}` : ""}
      {likeCount > 0 && commentCount > 0 ? "　" : ""}
      {commentCount > 0 ? `💬 ${commentCount}` : ""}
    </span>
  );
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
                {trip.kind === "own" && trip.isShared && (
                  <span className="trip-shared-icon" title="みんなの時空旅に公開中" aria-label="公開中">
                    🌐
                  </span>
                )}
              </span>
              {oldMap && <span className="place-era">{oldMap.title}</span>}
              <span className="place-story-preview">
                {distanceLabel(trip.totalDistanceMeters)}
                {trip.kind === "shared" && trip.ownerDisplayName ? ` ・ ${trip.ownerDisplayName}` : ""}
                {trip.kind === "own" ? " ・ 自分の時空旅" : " ・ 共有された時空旅"}
              </span>
              {(trip.kind === "shared" || trip.isShared) && <TripEngagementCounts tripId={trip.id} />}
              <span className="place-date">{dateFormatter.format(trip.startedAt)}</span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
