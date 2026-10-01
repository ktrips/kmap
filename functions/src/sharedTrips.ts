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
 * - `tripId`（旅のIDで探すため）・`ownerDisplayName`（Googleの表示名の先頭6文字）。持ち主のuidは文書の場所から分かる
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
  if (data.ownerDisplayName === undefined) updates.ownerDisplayName = await ownerDisplayName(uid);

  if (data.isSharedPublicly === true) {
    // 公開した時点で件数を持たせる（クライアントは件数を数え直さず、旅の文書を読むだけで済む）。
    if (typeof data.likeCount !== "number" || typeof data.commentCount !== "number") {
      Object.assign(updates, await countEngagement(tripId));
    }
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
async function countEngagement(tripId: string): Promise<{ likeCount: number; commentCount: number }> {
  const engagement = db().collection("sharedTrips").doc(tripId);
  const [likes, comments] = await Promise.all([
    engagement.collection("likes").count().get(),
    engagement.collection("comments").count().get(),
  ]);
  return { likeCount: likes.data().count, commentCount: comments.data().count };
}

async function recountEngagement(tripId: string): Promise<void> {
  const routes = await db().collectionGroup("walkRoutes").where("tripId", "==", tripId).limit(1).get();
  const route = routes.docs[0];
  if (!route) return;
  await route.ref.update(await countEngagement(tripId));
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
 * 管理者が実行する後片付け。以前のiOSアプリが作っていた公開用のコピーを消す。
 * - `sharedTrips/{tripId}`の文書のうち、旅の中身を持つもの（コピー）。いいね・コメント（サブコレクション）は残る。
 * - Storage の`sharedPhotos/`（写真の複製）のうち、どの公開中の旅の写真の一覧からも使われていないもの。
 * 古いアプリが残っている間は新しいコピーが作られることがあるので、何度実行してもよい。
 */
export const cleanupLegacySharedTrips = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const token = request.auth?.token;
  if (token?.email !== ADMIN_EMAIL || token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "管理者だけが実行できます。");
  }
  const copies = (await db().collection("sharedTrips").get()).docs.filter((doc) => doc.get("latitudes") !== undefined);
  await Promise.all(copies.map((doc) => doc.ref.delete()));

  const publicRoutes = await db().collectionGroup("walkRoutes").where("isSharedPublicly", "==", true).get();
  const usedURLs = publicRoutes.docs
    .flatMap((doc) => [...(doc.get("stampPhotos") ?? []), ...(doc.get("postPhotos") ?? [])])
    .map((photo: PublicPhoto) => photo.url)
    .join("\n");
  const [files] = await admin.storage().bucket().getFiles({ prefix: "sharedPhotos/" });
  const unused = files.filter((file) => !usedURLs.includes(encodeURIComponent(file.name)));
  await Promise.all(unused.map((file) => file.delete()));

  logger.info("以前の公開用のコピーを片付けました", { copies: copies.length, photos: unused.length });
  return { copies: copies.length, photos: unused.length };
});
