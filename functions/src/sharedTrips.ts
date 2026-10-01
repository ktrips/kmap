import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { ADMIN_EMAIL } from "./adminEmail";

/**
 * 「みんなの時空旅」（公開した旅）の処理。
 *
 * 旅の正本は`users/{uid}/walkRoutes/{tripId}`の1か所だけで、公開・非公開は文書の`isSharedPublicly`で切り替える
 * （firestore.rules で「本人、または`isSharedPublicly == true`なら誰でも読める」）。公開ページに必要な次の項目は、
 * ここ（Cloud Functions）が旅の文書に書き込む。クライアントは旅・御朱印・投稿写真を普段どおり保存するだけでよい。
 *
 * - `tripId`・`ownerUserID`・`ownerDisplayName`（Googleの表示名の先頭6文字）
 * - `stampPhotos`・`postPhotos`: その旅の御朱印・投稿写真（写真のある分。見られるかどうかは旅の公開状況だけで決まる）
 * - `likeCount`・`commentCount`: いいね・コメントの件数（いいね・コメントは`sharedTrips/{tripId}/likes|comments`）
 *
 * 御朱印・投稿写真そのもの（`users/{uid}/stamps`・`photoPosts`）は本人しか読めない。公開されるのは旅の文書だけ。
 * Firestoreのデータベースが米国のマルチリージョン（nam5）にあるため、トリガーはus-central1に置く。
 */

const REGION = "us-central1";

interface PublicPhoto {
  url: string;
  photoID: string;
  siteID?: string;
  siteName?: string;
  placeName?: string;
  detail: string;
}

const db = () => admin.firestore();

function routeRef(uid: string, tripId: string) {
  return db().collection("users").doc(uid).collection("walkRoutes").doc(tripId);
}

/** 旅に紐づく御朱印・投稿写真（写真のあるもの）を、公開ページ用の一覧にする。 */
async function buildPublicPhotos(
  uid: string,
  tripId: string,
): Promise<{ stampPhotos: PublicPhoto[]; postPhotos: PublicPhoto[] }> {
  const user = db().collection("users").doc(uid);
  const [stamps, posts] = await Promise.all([
    user.collection("stamps").where("walkRouteID", "==", tripId).get(),
    user.collection("photoPosts").where("walkRouteID", "==", tripId).get(),
  ]);

  const millis = (value: unknown) => (value instanceof admin.firestore.Timestamp ? value.toMillis() : 0);
  const stampPhotos = stamps.docs
    .filter((doc) => typeof doc.get("photoURL") === "string")
    .sort((a, b) => millis(a.get("collectedAt")) - millis(b.get("collectedAt")))
    .map((doc) => ({
      url: doc.get("photoURL") as string,
      photoID: doc.id,
      siteID: (doc.get("siteID") as string | undefined) ?? "",
      siteName: (doc.get("siteName") as string | undefined) ?? "御朱印",
      detail: (doc.get("detail") as string | undefined) ?? "",
    }));
  const postPhotos = posts.docs
    .filter((doc) => typeof doc.get("photoURL") === "string")
    .sort((a, b) => millis(a.get("postedAt")) - millis(b.get("postedAt")))
    .map((doc) => ({
      url: doc.get("photoURL") as string,
      photoID: doc.id,
      placeName: ((doc.get("userTitle") as string | null) || (doc.get("placeName") as string | null)) ?? "",
      detail: (doc.get("storyBody") as string | null) ?? "",
    }));
  return { stampPhotos, postPhotos };
}

/** 公開する名前は、プライバシーのためGoogleの表示名の先頭6文字だけにする（以前のiOSアプリと同じ）。 */
async function ownerDisplayName(uid: string): Promise<string | null> {
  try {
    const user = await admin.auth().getUser(uid);
    return user.displayName ? user.displayName.slice(0, 6) : null;
  } catch {
    return null;
  }
}

/** 旅の文書に、公開ページ用の項目を書き込む。値が変わらない時は書かない（自分自身のトリガーの繰り返しを止める）。 */
async function refreshRoute(uid: string, tripId: string, data: admin.firestore.DocumentData): Promise<void> {
  const updates: Record<string, unknown> = {};
  if (data.tripId !== tripId) updates.tripId = tripId;
  if (data.ownerUserID !== uid) updates.ownerUserID = uid;
  if (data.ownerDisplayName === undefined) updates.ownerDisplayName = await ownerDisplayName(uid);

  if (data.isSharedPublicly === true) {
    const photos = await buildPublicPhotos(uid, tripId);
    if (JSON.stringify(photos.stampPhotos) !== JSON.stringify(data.stampPhotos ?? [])) {
      updates.stampPhotos = photos.stampPhotos;
    }
    if (JSON.stringify(photos.postPhotos) !== JSON.stringify(data.postPhotos ?? [])) {
      updates.postPhotos = photos.postPhotos;
    }
  }
  if (Object.keys(updates).length > 0) {
    await routeRef(uid, tripId).update(updates);
  }
}

export const onWalkRouteWritten = onDocumentWritten(
  { document: "users/{uid}/walkRoutes/{tripId}", region: REGION },
  async (event) => {
    const data = event.data?.after.data();
    if (!data) return; // 削除された旅は、文書ごと見えなくなるので何もしない。
    await refreshRoute(event.params.uid, event.params.tripId, data);
  },
);

/** 御朱印・投稿写真が変わったら、紐づく旅（変更前・変更後）の公開用の写真を作り直す。 */
async function refreshRoutesOf(uid: string, walkRouteIDs: (string | undefined)[]): Promise<void> {
  for (const tripId of new Set(walkRouteIDs.filter((id): id is string => typeof id === "string" && id.length > 0))) {
    const route = await routeRef(uid, tripId).get();
    const data = route.data();
    if (data) await refreshRoute(uid, tripId, data);
  }
}

export const onStampWritten = onDocumentWritten(
  { document: "users/{uid}/stamps/{stampId}", region: REGION },
  async (event) => {
    await refreshRoutesOf(event.params.uid, [
      event.data?.before.get("walkRouteID"),
      event.data?.after.get("walkRouteID"),
    ]);
  },
);

export const onPhotoPostWritten = onDocumentWritten(
  { document: "users/{uid}/photoPosts/{postId}", region: REGION },
  async (event) => {
    await refreshRoutesOf(event.params.uid, [
      event.data?.before.get("walkRouteID"),
      event.data?.after.get("walkRouteID"),
    ]);
  },
);

/**
 * いいね・コメントの件数を、旅の文書（`likeCount`・`commentCount`）に書く。
 * 増減の差分ではなく毎回数え直すので、取りこぼしや二重実行があっても正しい値に戻る。
 */
async function recountEngagement(tripId: string): Promise<void> {
  const engagement = db().collection("sharedTrips").doc(tripId);
  const [routes, likes, comments] = await Promise.all([
    db().collectionGroup("walkRoutes").where("tripId", "==", tripId).limit(1).get(),
    engagement.collection("likes").count().get(),
    engagement.collection("comments").count().get(),
  ]);
  const route = routes.docs[0];
  if (!route) return;
  await route.ref.update({
    likeCount: likes.data().count,
    commentCount: comments.data().count,
  });
}

export const syncTripLikeCount = onDocumentWritten(
  { document: "sharedTrips/{tripId}/likes/{uid}", region: REGION },
  async (event) => {
    await recountEngagement(event.params.tripId);
  },
);

export const syncTripCommentCount = onDocumentWritten(
  { document: "sharedTrips/{tripId}/comments/{commentId}", region: REGION },
  async (event) => {
    await recountEngagement(event.params.tripId);
  },
);

/**
 * 管理者が一度だけ実行する移行。以前の公開用のコピー（`sharedTrips/{tripId}`の文書）から、
 * 旅の文書に公開の印と公開ページ用の項目を写す。旅の文書が無い（コピーにしか無い）旅は、コピーから作る。
 * 公開用の写真の一覧は、旅の文書を書いた直後に`onWalkRouteWritten`が本人の御朱印・投稿写真から作り直す。
 * 何度実行しても同じ結果になる。
 */
export const migrateSharedTrips = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const token = request.auth?.token;
  if (token?.email !== ADMIN_EMAIL || token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "管理者だけが実行できます。");
  }
  const legacy = await db().collection("sharedTrips").get();
  let migrated = 0;
  for (const doc of legacy.docs) {
    const data = doc.data();
    const uid = data.ownerUserID as string | undefined;
    if (!uid || data.latitudes === undefined) continue; // いいね・コメントだけの（中身の無い）文書は飛ばす。
    const [likes, comments] = await Promise.all([
      doc.ref.collection("likes").count().get(),
      doc.ref.collection("comments").count().get(),
    ]);
    const route = routeRef(uid, doc.id);
    const existing = await route.get();
    const fromCopy = existing.exists
      ? {}
      : {
          title: data.title ?? null,
          notes: data.notes ?? null,
          latitudes: data.latitudes ?? [],
          longitudes: data.longitudes ?? [],
          startedAt: data.startedAt ?? null,
          endedAt: data.endedAt ?? null,
          stepCount: data.stepCount ?? null,
          overlayMapID: data.overlayMapID ?? null,
          totalDistanceMeters: data.totalDistanceMeters ?? 0,
          travelJournalTitle: data.travelJournalTitle ?? null,
          travelJournalMarkdown: data.travelJournalMarkdown ?? null,
          travelJournalGeneratedAt: data.travelJournalGeneratedAt ?? null,
          tripVideoURL: data.tripVideoURL ?? null,
        };
    await route.set(
      {
        ...fromCopy,
        isSharedPublicly: true,
        tripId: doc.id,
        ownerUserID: uid,
        ownerDisplayName: data.ownerDisplayName ?? null,
        likeCount: likes.data().count,
        commentCount: comments.data().count,
      },
      { merge: true },
    );
    migrated += 1;
  }
  logger.info("公開中の旅を移行しました", { migrated });
  return { migrated };
});
