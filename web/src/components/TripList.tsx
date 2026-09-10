import type { UnifiedTrip } from "../types/unifiedTrip";
import { findOldMap } from "../lib/oldMapCatalog";
import { useTripEngagementCounts } from "../lib/useTripEngagementCounts";

interface Props {
  trips: UnifiedTrip[];
  selectedId: string | null;
  onSelect: (trip: UnifiedTrip) => void;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  year: "numeric",
  month: "numeric",
  day: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
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
    <>
      {" ・ "}
      {likeCount > 0 ? `❤️ ${likeCount}` : ""}
      {likeCount > 0 && commentCount > 0 ? "　" : ""}
      {commentCount > 0 ? `💬 ${commentCount}` : ""}
    </>
  );
}

/** 2行目：日付・距離・歩数・投稿者のGoogle名・いいね数・コメント数をコンパクトに1行で。 */
function TripMetaLine({ trip }: { trip: UnifiedTrip }) {
  const parts = [dateFormatter.format(trip.startedAt), distanceLabel(trip.totalDistanceMeters)];
  if (trip.stepCount !== null) parts.push(`${trip.stepCount.toLocaleString()}歩`);
  if (trip.ownerDisplayName) parts.push(trip.ownerDisplayName);

  return (
    <span className="trip-row-meta">
      {parts.join(" ・ ")}
      {(trip.kind === "shared" || trip.isShared) && <TripEngagementCounts tripId={trip.id} />}
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
              <span className="trip-row-title">
                {trip.title && trip.title.length > 0 ? trip.title : dateFormatter.format(trip.startedAt)}
                {oldMap && `（${oldMap.title}）`}
                {trip.journalMarkdown && (
                  <span className="trip-shared-icon" title="旅日記あり" aria-label="旅日記あり">
                    📖
                  </span>
                )}
                {(trip.kind === "shared" || trip.isShared) && (
                  <span
                    className="trip-shared-icon"
                    title={trip.kind === "shared" ? "みんなの時空旅で公開中" : "自分の記録・公開中"}
                    aria-label="公開中"
                  >
                    🌐
                  </span>
                )}
              </span>
              <TripMetaLine trip={trip} />
            </button>
          </li>
        );
      })}
    </ul>
  );
}
