import { useMemo, useState } from "react";
import type { UnifiedTrip } from "../types/unifiedTrip";
import { distanceLabel, tripDateFormatter as dateFormatter } from "../lib/format";
import { findOldMap } from "../lib/oldMapCatalog";
import { useTripEngagementCountsMap } from "../lib/useTripEngagementCounts";
import {
  compareTrips,
  REGION_LABEL,
  REGION_ORDER,
  SORT_LABEL,
  tripRegion,
  type TripSortOrder,
} from "../lib/tripRegion";

interface Props {
  trips: UnifiedTrip[];
  selectedId: string | null;
  onSelect: (trip: UnifiedTrip) => void;
}

const SORT_STORAGE_KEY = "komap-trip-sort";
const SORT_ORDERS: TripSortOrder[] = ["likes", "date", "distance"];

function loadSortOrder(): TripSortOrder {
  try {
    const saved = localStorage.getItem(SORT_STORAGE_KEY);
    if (saved === "likes" || saved === "date" || saved === "distance") return saved;
  } catch {
    // 保存できない環境（プライベートブラウズなど）では既定のいいね順にする。
  }
  return "likes";
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
 * リージョンごと（Europe → America → Japan → Asia）に分け、各リージョンの中は
 * 選んだ順番（いいね順・日付順・距離順）で並べる（iOSアプリの「みんなの旅」と同じ）。
 */
export function TripList({ trips, selectedId, onSelect }: Props) {
  const [sortOrder, setSortOrder] = useState<TripSortOrder>(loadSortOrder);
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

  const groups = useMemo(() => {
    const byRegion = new Map<string, UnifiedTrip[]>();
    for (const trip of trips) {
      const region = tripRegion(trip);
      const list = byRegion.get(region);
      if (list) list.push(trip);
      else byRegion.set(region, [trip]);
    }
    const compare = compareTrips(sortOrder, (id) => engagement.get(id)?.likeCount ?? 0);
    return REGION_ORDER.filter((region) => byRegion.has(region)).map((region) => ({
      region,
      trips: [...(byRegion.get(region) ?? [])].sort(compare),
    }));
  }, [trips, sortOrder, engagement]);

  const changeSortOrder = (order: TripSortOrder) => {
    setSortOrder(order);
    try {
      localStorage.setItem(SORT_STORAGE_KEY, order);
    } catch {
      // 保存できなくても、今の表示の並び替えはそのまま行う。
    }
  };

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
      <div className="trip-sort" role="group" aria-label="並び順">
        {SORT_ORDERS.map((order) => (
          <button
            key={order}
            type="button"
            className={`trip-sort-button ${order === sortOrder ? "is-active" : ""}`}
            aria-pressed={order === sortOrder}
            onClick={() => changeSortOrder(order)}
          >
            {SORT_LABEL[order]}
          </button>
        ))}
      </div>
      {groups.map(({ region, trips: regionTrips }) => (
        <section key={region} className="trip-region">
          <h3 className="trip-region-title">{REGION_LABEL[region]}</h3>
          <ul className="place-list">
            {regionTrips.map((trip) => {
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
                      <TripMetaLine trip={trip} counts={engagement.get(trip.id)} />
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      ))}
    </div>
  );
}
