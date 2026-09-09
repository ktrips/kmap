import { useEffect, useMemo, useState } from "react";
import { marked } from "marked";
import { findOldMap } from "../lib/oldMapCatalog";
import { sitesForOverlay } from "../lib/historicSiteCatalog";
import { saveTripDetails } from "../lib/tripEditing";
import { useTripComments } from "../lib/useTripComments";
import { useTripLikes } from "../lib/useTripLikes";
import { TripMapView } from "./TripMapView";
import type { UnifiedTrip } from "../types/unifiedTrip";

interface CurrentUser {
  uid: string;
  displayName: string | null;
}

interface Props {
  trip: UnifiedTrip | null;
  /** サインイン中のユーザー。いいね・コメントの投稿に使う（未サインインならnull）。 */
  currentUser?: CurrentUser | null;
  /** 未サインインの訪問者がいいね・コメントしようとした時に呼ぶ（サインイン画面への誘導用）。 */
  onRequestSignIn?: () => void;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  dateStyle: "medium",
  timeStyle: "short",
});

const commentDateFormatter = new Intl.DateTimeFormat("ja-JP", {
  month: "numeric",
  day: "numeric",
  hour: "2-digit",
  minute: "2-digit",
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
export function TripDetail({ trip, currentUser = null, onRequestSignIn }: Props) {
  const [commentText, setCommentText] = useState("");
  const { likeCount, isLikedByMe, toggleLike, isToggling } = useTripLikes(trip?.id ?? null, currentUser?.uid ?? null);
  const { comments, postComment, deleteComment, isPosting } = useTripComments(trip?.id ?? null);

  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [isSaving, setIsSaving] = useState(false);

  // 選ぶ時空旅を切り替えたら、編集中だった内容は破棄する。
  useEffect(() => {
    setIsEditing(false);
  }, [trip?.id]);

  const oldMap = trip ? findOldMap(trip.overlayMapID) : undefined;
  // `sitesForOverlay`は呼ぶたびに新しい配列を返すため、useMemoなしだと
  // いいね・コメントのリアルタイム更新でTripDetailが再描画されるたびに
  // 新しい配列参照になり、変わっていないTripMapView側の重い再描画
  // （古地図オーバーレイの再取得・マーカーの作り直し）を毎回引き起こしていた。
  const checkpoints = useMemo(() => sitesForOverlay(oldMap?.id ?? null), [oldMap]);
  const journalHtml = useMemo(
    () => (trip?.journalMarkdown ? (marked.parse(trip.journalMarkdown, { async: false }) as string) : null),
    [trip?.journalMarkdown],
  );
  // いいね・コメントのリアルタイム更新のたびに、`trip`を渡している親（一覧全体を
  // Firestoreスナップショットのたびに丸ごと作り直している）経由で`trip.latitudes`/
  // `longitudes`も新しい配列参照になりがちで、内容は変わっていないのに
  // `TripMapView`側のマーカー・オーバーレイ再構築を毎回引き起こしていた。
  // 選んでいる時空旅の記録済みルートは作成後に変わらないため、`trip.id`と
  // 点数が変わらない限り、前回と同じ配列参照を使い回す。
  const routeCoordinates = useMemo(
    () => ({ latitudes: trip?.latitudes ?? [], longitudes: trip?.longitudes ?? [] }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [trip?.id, trip?.latitudes.length, trip?.longitudes.length]
  );

  if (!trip) {
    return (
      <div className="trip-detail place-detail-empty">
        <p>リストから、時空旅を選んでください。</p>
      </div>
    );
  }

  const duration = durationLabel(trip);
  const canEdit = trip.kind === "own" && currentUser !== null;

  const startEditing = () => {
    setEditTitle(trip.title ?? "");
    setEditDescription(trip.description ?? "");
    setIsEditing(true);
  };

  const handleSaveEdits = async () => {
    if (!currentUser) return;
    setIsSaving(true);
    try {
      await saveTripDetails(currentUser.uid, trip.id, trip.isShared, {
        title: editTitle.trim().length > 0 ? editTitle.trim() : null,
        description: editDescription.trim().length > 0 ? editDescription.trim() : null,
      });
      setIsEditing(false);
    } finally {
      setIsSaving(false);
    }
  };

  const handleLikeClick = () => {
    if (!currentUser) {
      onRequestSignIn?.();
      return;
    }
    void toggleLike();
  };

  const handleCommentSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser) {
      onRequestSignIn?.();
      return;
    }
    void postComment(commentText, currentUser).then(() => setCommentText(""));
  };

  return (
    <div className="trip-detail">
      {trip.latitudes.length > 0 && (
        <TripMapView
          latitudes={routeCoordinates.latitudes}
          longitudes={routeCoordinates.longitudes}
          oldMap={oldMap}
          checkpoints={checkpoints}
        />
      )}

      <p className="place-detail-era">{dateFormatter.format(trip.startedAt)}</p>

      {isEditing ? (
        <div className="trip-edit-form">
          <input
            type="text"
            className="trip-edit-title-input"
            placeholder="旅の名称"
            value={editTitle}
            onChange={(e) => setEditTitle(e.target.value)}
            maxLength={100}
          />
          <textarea
            className="trip-edit-description-input"
            placeholder="感想・説明を書く…"
            value={editDescription}
            onChange={(e) => setEditDescription(e.target.value)}
            maxLength={1000}
            rows={4}
          />
          <div className="trip-edit-actions">
            <button type="button" className="trip-edit-save" onClick={() => void handleSaveEdits()} disabled={isSaving}>
              {isSaving ? "保存中…" : "保存"}
            </button>
            <button type="button" className="trip-edit-cancel" onClick={() => setIsEditing(false)} disabled={isSaving}>
              キャンセル
            </button>
          </div>
        </div>
      ) : (
        <>
          <div className="trip-title-row">
            {trip.title && trip.title.length > 0 && <h2>{trip.title}</h2>}
            {canEdit && (
              <button type="button" className="trip-edit-button" onClick={startEditing}>
                ✏️ 編集
              </button>
            )}
          </div>
          {trip.description && trip.description.length > 0 && (
            <p className="trip-description-text">{trip.description}</p>
          )}
        </>
      )}

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

      <div className="trip-engagement">
        <button
          type="button"
          className={`trip-like-button ${isLikedByMe ? "is-liked" : ""}`}
          onClick={handleLikeClick}
          disabled={isToggling}
        >
          {isLikedByMe ? "❤️" : "🤍"} いいね{likeCount > 0 ? ` ${likeCount}` : ""}
        </button>
      </div>

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

      {journalHtml && (
        <div className="trip-journal-section">
          <p className="shared-trip-photo-section-title">旅行記{trip.journalTitle ? `：${trip.journalTitle}` : ""}</p>
          <div className="trip-journal-body" dangerouslySetInnerHTML={{ __html: journalHtml }} />
        </div>
      )}

      <div className="trip-comments">
        <p className="shared-trip-photo-section-title">コメント{comments.length > 0 ? ` ${comments.length}件` : ""}</p>
        {comments.length > 0 && (
          <ul className="trip-comment-list">
            {comments.map((comment) => (
              <li key={comment.id} className="trip-comment-item">
                <div className="trip-comment-meta">
                  <span className="trip-comment-author">{comment.authorDisplayName}</span>
                  <span className="trip-comment-date">{commentDateFormatter.format(comment.createdAt)}</span>
                  {currentUser?.uid === comment.authorUserID && (
                    <button type="button" className="trip-comment-delete" onClick={() => void deleteComment(comment.id)}>
                      削除
                    </button>
                  )}
                </div>
                <p className="trip-comment-text">{comment.text}</p>
              </li>
            ))}
          </ul>
        )}
        <form className="trip-comment-form" onSubmit={handleCommentSubmit}>
          <input
            type="text"
            className="trip-comment-input"
            placeholder={currentUser ? "コメントを書く…" : "サインインするとコメントできます"}
            value={commentText}
            onChange={(e) => setCommentText(e.target.value)}
            onFocus={() => {
              if (!currentUser) onRequestSignIn?.();
            }}
            maxLength={500}
          />
          <button type="submit" className="trip-comment-submit" disabled={isPosting || commentText.trim().length === 0}>
            投稿
          </button>
        </form>
      </div>
    </div>
  );
}
