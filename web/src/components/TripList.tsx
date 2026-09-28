import { useMemo } from "react";
import type { UnifiedTrip } from "../types/unifiedTrip";
import { distanceLabel, tripDateFormatter as dateFormatter } from "../lib/format";
import { findOldMap } from "../lib/oldMapCatalog";
import { useTripEngagementCountsMap } from "../lib/useTripEngagementCounts";
import { compareTrips, REGION_SHORT_LABEL, tripRegion } from "../lib/tripRegion";

interface Props {
  trips: UnifiedTrip[];
  selectedId: string | null;
  onSelect: (trip: UnifiedTrip) => void;
}

interface Engagement {
  likeCount: number;
  commentCount: number;
}

/** 一覧の1行に添える、いいね・コメント件数（0件の間は表示しない）。 */
function TripEngagementCounts({ counts }: { counts: Engagement | undefined }) {
  if (!counts || (counts.likeCount === 0 && counts.commentCount === 0)) return null;
  const { likeCount, commentCount } = counts;
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
function TripMetaLine({ trip, counts }: { trip: UnifiedTrip; counts: Engagement | undefined }) {
  const parts = [dateFormatter.format(trip.startedAt), distanceLabel(trip.totalDistanceMeters)];
  if (trip.stepCount !== null) parts.push(`${trip.stepCount.toLocaleString()}歩`);
  if (trip.ownerDisplayName) parts.push(trip.ownerDisplayName);

  return (
    <span className="trip-row-meta">
      {parts.join(" ・ ")}
      {(trip.kind === "shared" || trip.isShared) && <TripEngagementCounts counts={counts} />}
    </span>
  );
}

/**
 * 「時空旅」タブの一覧。自分の時空旅と、他ユーザーが公開した時空旅を一緒に並べる。
 * リージョンで区切らずに、いいねの多い順（同じ数なら日付の新しい順）に並べ、
 * 各旅の名前の横にリージョン（Japan・Europeなど）を小さく添える。
 */
export function TripList({ trips, selectedId, onSelect }: Props) {
  // いいね・コメントは公開中の旅にしか付かない。公開データに件数（Cloud Functionsが書く）がある旅は
  // それを使い、まだ無い旅だけ集計クエリで数える。
  const idsToCount = useMemo(
    () =>
      trips
        .filter((trip) => (trip.kind === "shared" || trip.isShared) && (trip.likeCount === null || trip.commentCount === null))
        .map((trip) => trip.id),
    [trips],
  );
  const counted = useTripEngagementCountsMap(idsToCount);
  const engagement = useMemo(() => {
    const map = new Map(counted);
    for (const trip of trips) {
      if (trip.likeCount !== null && trip.commentCount !== null) {
        map.set(trip.id, { likeCount: trip.likeCount, commentCount: trip.commentCount });
      }
    }
    return map;
  }, [counted, trips]);

  const sortedTrips = useMemo(
    () => [...trips].sort(compareTrips("likes", (id) => engagement.get(id)?.likeCount ?? 0)),
    [trips, engagement],
  );

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
    <div className="trip-list">
      <ul className="place-list">
        {sortedTrips.map((trip) => {
          const oldMap = findOldMap(trip.overlayMapID);
          // 一覧の左に添えるサムネイル。旅の中の写真（投稿写真を優先、無ければ御朱印の
          // 写真）があればそれを、写真が1枚も無ければ代わりに歩いた古地図の画像を使う。
          const thumbnailUrl = trip.postPhotos[0]?.url ?? trip.stampPhotos[0]?.url ?? oldMap?.imageUrl ?? null;
          return (
            <li key={`${trip.kind}-${trip.id}`}>
              <button
                className={`place-list-item trip-list-item ${trip.id === selectedId ? "is-selected" : ""}`}
                onClick={() => onSelect(trip)}
              >
                <span className="trip-row-thumbnail">
                  {thumbnailUrl && <img src={thumbnailUrl} alt="" loading="lazy" />}
                </span>
                <span className="trip-row-content">
                  <span className="trip-row-title">
                    <span className="trip-row-title-text">
                      {trip.title && trip.title.length > 0 ? trip.title : dateFormatter.format(trip.startedAt)}
                      {oldMap && `（${oldMap.title}）`}
                    </span>
                    <span className="trip-region-badge">{REGION_SHORT_LABEL[tripRegion(trip)]}</span>
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
                  <TripMetaLine trip={trip} counts={engagement.get(trip.id)} />
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
