import { collection, getCount } from "firebase/firestore/lite";
import { useEffect, useState } from "react";
import { db } from "./firebase";

interface Counts {
  likeCount: number;
  commentCount: number;
}

/** 一覧の件数は多少古くても困らないため、同じ旅は一定時間このキャッシュを使う。 */
const CACHE_TTL_MS = 60_000;
const cache = new Map<string, { counts: Counts; fetchedAt: number }>();
const inFlight = new Map<string, Promise<Counts>>();

function fetchCounts(tripId: string): Promise<Counts> {
  const cached = cache.get(tripId);
  if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) return Promise.resolve(cached.counts);
  const pending = inFlight.get(tripId);
  if (pending) return pending;
  const firestore = db;
  if (!firestore) return Promise.resolve({ likeCount: 0, commentCount: 0 });
  const request = Promise.all([
    getCount(collection(firestore, "sharedTrips", tripId, "likes")),
    getCount(collection(firestore, "sharedTrips", tripId, "comments")),
  ])
    .then(([likes, comments]) => {
      const counts = { likeCount: likes.data().count, commentCount: comments.data().count };
      cache.set(tripId, { counts, fetchedAt: Date.now() });
      return counts;
    })
    .finally(() => inFlight.delete(tripId));
  inFlight.set(tripId, request);
  return request;
}

/**
 * 一覧の旅すべての、いいね・コメントの件数（いいね順に並べるためにまとめて数える）。
 * 1件ずつの取得・キャッシュは`useTripEngagementCounts`と共通。
 */
export function useTripEngagementCountsMap(tripIds: string[]): Map<string, Counts> {
  const key = tripIds.join(",");
  const [counts, setCounts] = useState<Map<string, Counts>>(() => {
    const initial = new Map<string, Counts>();
    for (const id of tripIds) {
      const cached = cache.get(id);
      if (cached) initial.set(id, cached.counts);
    }
    return initial;
  });

  useEffect(() => {
    let cancelled = false;
    const ids = key.length > 0 ? key.split(",") : [];
    Promise.all(ids.map((id) => fetchCounts(id).then((c) => [id, c] as const).catch(() => null))).then((entries) => {
      if (cancelled) return;
      const next = new Map<string, Counts>();
      for (const entry of entries) {
        if (entry) next.set(entry[0], entry[1]);
      }
      setCounts(next);
    });
    return () => {
      cancelled = true;
    };
  }, [key]);

  return counts;
}

/**
 * 一覧の1行に添える、いいね・コメントの件数。
 *
 * 以前は行ごとに`likes`・`comments`をリアルタイム購読していたため、一覧（最大50件）を
 * 開くだけで100本の購読が張られ、いいね・コメントのドキュメントを全件読み込んでいた。
 * 件数だけ分かればよいので、集計クエリ（`getCountFromServer`）で1回だけ数え、
 * 短時間キャッシュする（iOSアプリの`fetchEngagementCounts`と同じ方式）。
 * 詳細画面では`useTripLikes`・`useTripComments`がリアルタイムに最新の件数を出す。
 */
export function useTripEngagementCounts(tripId: string | null): Counts {
  const [counts, setCounts] = useState<Counts>(
    () => (tripId ? cache.get(tripId)?.counts : undefined) ?? { likeCount: 0, commentCount: 0 },
  );

  useEffect(() => {
    if (!tripId) {
      setCounts({ likeCount: 0, commentCount: 0 });
      return;
    }
    let cancelled = false;
    fetchCounts(tripId)
      .then((next) => {
        if (!cancelled) setCounts(next);
      })
      .catch(() => {
        // 件数は添え物なので、取れなければ表示しないだけにする。
      });
    return () => {
      cancelled = true;
    };
  }, [tripId]);

  return counts;
}
