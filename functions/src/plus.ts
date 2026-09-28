import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import jwt from "jsonwebtoken";
import * as crypto from "node:crypto";
import { normalizePEMPrivateKey } from "./pem";
import { ADMIN_EMAIL } from "./adminEmail";

/**
 * Komap Plus（iOSアプリの自動更新サブスクリプション）の購入状態を、Apple の
 * App Store Server API に直接問い合わせて確かめ、Firestore の `entitlements/{uid}` に記録する。
 *
 * 端末から届いた値（購入済みかどうか・有効期限）は信用せず、端末からは取引ID
 * （originalTransactionId）だけを受け取り、中身は必ず Apple から取り直す。
 * Web版の「Kindle本の全文」は、この記録を見て Plus の人にだけ本文を返す。
 *
 * App Store Server API は、App Store Connect の「ユーザとアクセス」→「統合」→
 * 「App内課金」で発行する「App内課金キー」で署名したJWTが必要（TestFlight招待で使っている
 * App Store Connect APIキーとは別の種類）。発行者ID（Issuer ID）は共通。
 */

const APPSTORE_ISSUER_ID = defineSecret("APPSTORE_CONNECT_ISSUER_ID");
const APPSTORE_IAP_KEY_ID = defineSecret("APPSTORE_IAP_KEY_ID");
const APPSTORE_IAP_PRIVATE_KEY = defineSecret("APPSTORE_IAP_PRIVATE_KEY");

const APP_BUNDLE_ID = "com.komap.Komap";

/** Komap Plus の商品ID（iOSの`PlusStore.productIDs`と同じ値）。 */
const PLUS_PRODUCT_IDS = new Set(["com.komap.Komap.plus.monthly", "com.komap.Komap.plus.yearly"]);

/** Kindle本の全文（Markdown）を置く Storage のパス。クライアントからは読めない（storage.rulesに一致なし）。 */
const KINDLE_FULL_TEXT_PATH = "premium/kindle-full.md";

const SERVER_API_HOSTS = {
  Production: "https://api.storekit.itunes.apple.com",
  Sandbox: "https://api.storekit-sandbox.itunes.apple.com",
} as const;
type AppStoreEnvironment = keyof typeof SERVER_API_HOSTS;

/** App Store Server API のサブスクリプション状態のうち、特典を使ってよいもの（1: 有効、4: 猶予期間）。 */
const ENTITLED_STATUSES = new Set([1, 4]);

interface SubscriptionStatusesResponse {
  data?: {
    lastTransactions?: {
      originalTransactionId?: string;
      status?: number;
      signedTransactionInfo?: string;
    }[];
  }[];
}

interface TransactionPayload {
  bundleId?: string;
  productId?: string;
  originalTransactionId?: string;
  expiresDate?: number;
  revocationDate?: number;
  appAccountToken?: string;
}

interface PlusStatus {
  isPlus: boolean;
  productId: string | null;
  expiresAt: Date | null;
  appAccountToken: string | null;
  environment: AppStoreEnvironment;
}

/**
 * Firebase の uid から、購入時に StoreKit へ渡す`appAccountToken`（UUID）を作る。
 * iOS側の`PlusStore.appAccountToken(for:)`と同じ計算（SHA-256の先頭16バイト）。
 * 別のアカウントの購入を自分のものとして登録されるのを防ぐために照合する。
 */
function appAccountToken(uid: string): string {
  const hex = crypto.createHash("sha256").update(uid, "utf8").digest("hex").slice(0, 32);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

/** App Store Server API 用の短命JWT（ES256）。 */
function buildServerAPIToken(): string {
  const key = crypto.createPrivateKey(normalizePEMPrivateKey(APPSTORE_IAP_PRIVATE_KEY.value()));
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: APPSTORE_ISSUER_ID.value(),
      iat: now,
      exp: now + 15 * 60,
      aud: "appstoreconnect-v1",
      bid: APP_BUNDLE_ID,
    },
    key,
    { algorithm: "ES256", header: { alg: "ES256", kid: APPSTORE_IAP_KEY_ID.value(), typ: "JWT" } },
  );
}

/**
 * Apple から返ってきた署名付きの取引情報（JWS）の中身を読む。HTTPSで Apple の
 * サーバーから直接受け取ったものなので、ここでは署名の検証はせず中身だけ取り出す。
 */
function decodeTransaction(jws: string): TransactionPayload {
  const decoded = jwt.decode(jws);
  return decoded && typeof decoded === "object" ? (decoded as TransactionPayload) : {};
}

/**
 * 取引IDのサブスクリプション状態を Apple に問い合わせる。本番で見つからなければ
 * Sandbox（Xcode・TestFlightでの購入）を試す。どちらにも無ければ`null`。
 */
async function fetchPlusStatus(originalTransactionId: string): Promise<PlusStatus | null> {
  const token = buildServerAPIToken();
  for (const environment of ["Production", "Sandbox"] as AppStoreEnvironment[]) {
    const response = await fetch(
      `${SERVER_API_HOSTS[environment]}/inApps/v1/subscriptions/${encodeURIComponent(originalTransactionId)}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (response.status === 404) continue;
    if (!response.ok) {
      logger.error("App Store Server APIの呼び出しに失敗", { environment, status: response.status });
      throw new HttpsError("unavailable", "購入状態を確認できませんでした。時間をおいて再度お試しください。");
    }
    const body = (await response.json()) as SubscriptionStatusesResponse;
    const candidates = (body.data ?? [])
      .flatMap((group) => group.lastTransactions ?? [])
      .map((last) => ({ status: last.status ?? 0, payload: decodeTransaction(last.signedTransactionInfo ?? "") }))
      .filter(({ payload }) => payload.bundleId === APP_BUNDLE_ID && PLUS_PRODUCT_IDS.has(payload.productId ?? ""));
    if (candidates.length === 0) continue;

    // 有効なものを優先し、その中で有効期限が一番先のものを採用する。
    candidates.sort((a, b) => {
      const activeA = ENTITLED_STATUSES.has(a.status) ? 1 : 0;
      const activeB = ENTITLED_STATUSES.has(b.status) ? 1 : 0;
      if (activeA !== activeB) return activeB - activeA;
      return (b.payload.expiresDate ?? 0) - (a.payload.expiresDate ?? 0);
    });
    const { status, payload } = candidates[0];
    return {
      isPlus: ENTITLED_STATUSES.has(status) && !payload.revocationDate,
      productId: payload.productId ?? null,
      expiresAt: payload.expiresDate ? new Date(payload.expiresDate) : null,
      appAccountToken: payload.appAccountToken?.toLowerCase() ?? null,
      environment,
    };
  }
  return null;
}

/**
 * 取引IDを確かめて`entitlements/{uid}`に書き込む。1つの購入を複数のアカウントで
 * 使い回せないよう、`plusTransactions/{originalTransactionId}`に最初に登録したuidを記録し、
 * 別のuidからの登録は受け付けない。
 */
async function recordPlusStatus(uid: string, originalTransactionId: string): Promise<PlusStatus | null> {
  const status = await fetchPlusStatus(originalTransactionId);
  if (!status) return null;
  if (status.appAccountToken && status.appAccountToken !== appAccountToken(uid)) {
    throw new HttpsError("permission-denied", "この購入は別のアカウントで行われたものです。");
  }

  const db = admin.firestore();
  const transactionRef = db.collection("plusTransactions").doc(originalTransactionId);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(transactionRef);
    const ownerUID = existing.exists ? (existing.get("uid") as string | undefined) : undefined;
    if (ownerUID && ownerUID !== uid) {
      throw new HttpsError("permission-denied", "この購入は別のアカウントに登録済みです。");
    }
    if (!ownerUID) {
      tx.set(transactionRef, { uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    }
    tx.set(db.collection("entitlements").doc(uid), {
      isPlus: status.isPlus,
      productId: status.productId,
      originalTransactionId,
      expiresAt: status.expiresAt ? admin.firestore.Timestamp.fromDate(status.expiresAt) : null,
      environment: status.environment,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return status;
}

/**
 * iOSアプリから呼ぶ。購入・復元・起動時に、端末で確認できた Plus の取引IDを渡してもらい、
 * Apple に確かめてから記録する。
 */
export const syncPlusEntitlement = onCall(
  { secrets: [APPSTORE_ISSUER_ID, APPSTORE_IAP_KEY_ID, APPSTORE_IAP_PRIVATE_KEY] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "サインインが必要です。");
    const originalTransactionId = request.data?.originalTransactionId;
    if (typeof originalTransactionId !== "string" || !/^\d{1,32}$/.test(originalTransactionId)) {
      throw new HttpsError("invalid-argument", "取引IDが正しくありません。");
    }
    const status = await recordPlusStatus(uid, originalTransactionId);
    if (!status) throw new HttpsError("not-found", "Komap Plus の購入が見つかりませんでした。");
    return { isPlus: status.isPlus, expiresAt: status.expiresAt?.toISOString() ?? null };
  },
);

/**
 * `entitlements/{uid}`を読み、有効期限が過ぎていれば Apple に更新を確かめ直してから、
 * いま Plus かどうかを返す（自動更新された分は、アプリを開かなくてもWebで反映される）。
 */
async function isPlusNow(uid: string): Promise<boolean> {
  const snapshot = await admin.firestore().collection("entitlements").doc(uid).get();
  if (!snapshot.exists) return false;
  const expiresAt = (snapshot.get("expiresAt") as admin.firestore.Timestamp | null)?.toDate();
  if (snapshot.get("isPlus") === true && expiresAt && expiresAt.getTime() > Date.now()) return true;

  const originalTransactionId = snapshot.get("originalTransactionId") as string | undefined;
  if (!originalTransactionId) return false;
  const refreshed = await recordPlusStatus(uid, originalTransactionId);
  return refreshed?.isPlus === true;
}

/** 管理者がプロモユーザー（`plusPromoUsers/{小文字のメールアドレス}`）に登録しているか。 */
async function isPromoUser(email: string): Promise<boolean> {
  const snapshot = await admin.firestore().collection("plusPromoUsers").doc(email).get();
  return snapshot.exists;
}

/**
 * Web版から呼ぶ。Plus の人には Kindle本の全文（Markdown）を返し、それ以外には
 * `not-plus`だけを返す（その場合、Web側は冒頭の無料部分だけを表示する）。
 */
export const getKindleFullText = onCall(
  { secrets: [APPSTORE_ISSUER_ID, APPSTORE_IAP_KEY_ID, APPSTORE_IAP_PRIVATE_KEY] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) return { status: "not-plus" as const };
    // 管理者と、管理者が登録したプロモユーザーは、購入しなくても Plus として扱う
    // （iOSアプリの`PlusStore.isAdminGrant`・`isPromoGrant`と同じ判定）。
    const token = request.auth?.token;
    const verifiedEmail = token?.email_verified === true ? token.email?.toLowerCase() : undefined;
    const isGranted = verifiedEmail !== undefined && (verifiedEmail === ADMIN_EMAIL || (await isPromoUser(verifiedEmail)));
    if (!isGranted && !(await isPlusNow(uid))) return { status: "not-plus" as const };

    const file = admin.storage().bucket().file(KINDLE_FULL_TEXT_PATH);
    const [exists] = await file.exists();
    if (!exists) {
      logger.error("Kindle本の全文ファイルがStorageにありません", { path: KINDLE_FULL_TEXT_PATH });
      throw new HttpsError("not-found", "全文の準備ができていません。時間をおいて再度お試しください。");
    }
    const [contents] = await file.download();
    return { status: "ok" as const, markdown: contents.toString("utf8") };
  },
);
