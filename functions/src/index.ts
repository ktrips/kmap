import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import jwt from "jsonwebtoken";
import * as crypto from "node:crypto";

admin.initializeApp();
setGlobalOptions({ region: "asia-northeast1", maxInstances: 10 });

const APPSTORE_ISSUER_ID = defineSecret("APPSTORE_CONNECT_ISSUER_ID");
const APPSTORE_KEY_ID = defineSecret("APPSTORE_CONNECT_KEY_ID");
const APPSTORE_PRIVATE_KEY = defineSecret("APPSTORE_CONNECT_PRIVATE_KEY");
const APPSTORE_BETA_GROUP_ID = defineSecret("APPSTORE_CONNECT_BETA_GROUP_ID");

const APPSTORE_API_BASE = "https://api.appstoreconnect.apple.com/v1";

/**
 * `firebase functions:secrets:set`での貼り付け方（実改行が保持される・
 * リテラルな`\n`になる・ヘッダー無しで本文だけ・CRLFなど）によらず、
 * 常に正しい形のPEM（1行64文字・実改行・BEGIN/ENDヘッダー付き）を作り直す。
 * これをしないと、改行が失われた場合などに`jsonwebtoken`が鍵として
 * 認識できず「secretOrPrivateKey must be an asymmetric key」で失敗する。
 */
function normalizePEMPrivateKey(raw: string): string {
  const cleaned = raw.trim().replace(/\\n/g, "\n").replace(/\r\n/g, "\n");
  const match = cleaned.match(/-----BEGIN ([^-]+)-----([\s\S]*?)-----END \1-----/);
  const label = match?.[1] ?? "PRIVATE KEY";
  const body = (match?.[2] ?? cleaned).replace(/\s+/g, "");
  const lines = body.match(/.{1,64}/g) ?? [];
  return `-----BEGIN ${label}-----\n${lines.join("\n")}\n-----END ${label}-----\n`;
}

/** App Store Connect APIへの認証に使う短命JWT（ES256）を都度作る。 */
function buildAppStoreConnectToken(): string {
  const raw = APPSTORE_PRIVATE_KEY.value();
  const pem = normalizePEMPrivateKey(raw);

  // 実際に鍵として読めるかどうかを先に検証し、読めない場合は「値の中身」を一切出さずに
  // 診断に必要な情報（長さ・改行の有無・鍵種別など）だけログへ出す。
  // これで、Secret Managerに保存された値そのものがおかしいのか、
  // このコード側の変換がおかしいのかを、秘密鍵をログに残さず切り分けられる。
  let keyObject: crypto.KeyObject;
  try {
    keyObject = crypto.createPrivateKey(pem);
  } catch (err) {
    logger.error("App Store Connect秘密鍵のパースに失敗", {
      rawLength: raw.length,
      rawContainsLiteralBackslashN: raw.includes("\\n"),
      rawContainsRealNewline: raw.includes("\n"),
      rawHasBeginMarker: raw.includes("BEGIN"),
      rawHasEndMarker: raw.includes("END"),
      normalizedLength: pem.length,
      parseError: err instanceof Error ? err.message : String(err),
    });
    throw new HttpsError("internal", "App Store Connect秘密鍵の設定が不正です。");
  }
  if (keyObject.asymmetricKeyType !== "ec") {
    logger.error("App Store Connect秘密鍵の種類が不正（ECではない）", {
      asymmetricKeyType: keyObject.asymmetricKeyType,
    });
    throw new HttpsError(
      "internal",
      `App Store Connect秘密鍵の種類が不正です（${keyObject.asymmetricKeyType}）。.p8ファイルの中身を確認してください。`,
    );
  }

  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: APPSTORE_ISSUER_ID.value(),
      iat: now,
      exp: now + 19 * 60, // App Store Connect APIのトークンは最長20分
      aud: "appstoreconnect-v1",
    },
    keyObject,
    {
      algorithm: "ES256",
      header: {
        alg: "ES256",
        kid: APPSTORE_KEY_ID.value(),
        typ: "JWT",
      },
    },
  );
}

interface AppStoreErrorBody {
  errors?: Array<{ status?: string; code?: string; title?: string; detail?: string }>;
}

/**
 * メールアドレス宛にTestFlightの外部テスト招待を送る。
 *
 * - 既に（当ベータグループに）招待済みのメールなら何もしない（Firestoreで記録して判定）。
 * - App Store Connect側に同じメールのテスターが既に存在する場合（別グループ経由など）は、
 *   新規作成ではなく既存テスターを対象のベータグループへ追加する形にフォールバックする。
 */
async function inviteToTestFlight(params: {
  email: string;
  firstName: string;
  lastName: string;
}): Promise<"sent" | "already-invited"> {
  const db = admin.firestore();
  const inviteRef = db.collection("testflightInvites").doc(params.email.toLowerCase());
  const existing = await inviteRef.get();
  if (existing.exists && existing.data()?.status === "sent") {
    return "already-invited";
  }

  const token = buildAppStoreConnectToken();
  const groupId = APPSTORE_BETA_GROUP_ID.value();

  const createResponse = await fetch(`${APPSTORE_API_BASE}/betaTesters`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {
        type: "betaTesters",
        attributes: {
          email: params.email,
          firstName: params.firstName,
          lastName: params.lastName,
        },
        relationships: {
          betaGroups: {
            data: [{ type: "betaGroups", id: groupId }],
          },
        },
      },
    }),
  });

  if (createResponse.status === 201) {
    await inviteRef.set({
      email: params.email,
      status: "sent",
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return "sent";
  }

  const body = (await createResponse.json().catch(() => ({}))) as AppStoreErrorBody;
  const isConflict =
    createResponse.status === 409 ||
    body.errors?.some((e) => e.code === "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE");

  if (!isConflict) {
    logger.error("App Store Connect betaTesters作成に失敗", {
      status: createResponse.status,
      body,
    });
    throw new HttpsError("internal", "TestFlight招待の送信に失敗しました。");
  }

  // 既に同じメールのテスターが存在する場合、既存テスターを探して
  // 対象のベータグループへ追加する（招待メールはグループ追加時に飛ぶ）。
  const lookupResponse = await fetch(
    `${APPSTORE_API_BASE}/betaTesters?filter[email]=${encodeURIComponent(params.email)}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!lookupResponse.ok) {
    logger.error("既存betaTesterの検索に失敗", { status: lookupResponse.status });
    throw new HttpsError("internal", "TestFlight招待の送信に失敗しました。");
  }
  const lookupBody = (await lookupResponse.json()) as { data?: Array<{ id: string }> };
  const existingTesterId = lookupBody.data?.[0]?.id;
  if (!existingTesterId) {
    logger.error("既存betaTesterが見つからない", { email: params.email });
    throw new HttpsError("internal", "TestFlight招待の送信に失敗しました。");
  }

  const addToGroupResponse = await fetch(
    `${APPSTORE_API_BASE}/betaGroups/${groupId}/relationships/betaTesters`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        data: [{ type: "betaTesters", id: existingTesterId }],
      }),
    },
  );
  if (!addToGroupResponse.ok && addToGroupResponse.status !== 204) {
    const addBody = (await addToGroupResponse.json().catch(() => ({}))) as AppStoreErrorBody;
    logger.error("既存betaTesterのグループ追加に失敗", {
      status: addToGroupResponse.status,
      body: addBody,
    });
    // App Store Connect APIは409 STATE_ERROR（"Tester(s) cannot be assigned"）を、
    // 主に次の2パターンで返す。
    //   1. 対象の外部テストグループにベータ版App Reviewを通過したビルドがまだ無い
    //   2. 招待先のメールアドレスが、既にApp Store Connectのチームメンバー
    //      （Admin等）として登録済みのアカウントである（本人のアカウントで
    //      このWeb版の自動招待を試した場合など）
    // どちらのAPIレスポンスも同じエラーコードのため区別できず、汎用の
    // 「送信に失敗しました」のままだと毎回サーバーログを確認しないと原因が
    // 分からないため、両方の可能性を案内する。
    const isStateError =
      addToGroupResponse.status === 409 &&
      addBody.errors?.some((e) => e.code === "STATE_ERROR");
    if (isStateError) {
      throw new HttpsError(
        "failed-precondition",
        "TestFlightへの招待に失敗しました。ビルドが未審査か、このメールアドレスが既にチームメンバーとして登録されている可能性があります。別のメールアドレスで、審査済みのビルドがある状態で再度お試しください。",
      );
    }
    throw new HttpsError("internal", "TestFlight招待の送信に失敗しました。");
  }

  await inviteRef.set({
    email: params.email,
    status: "sent",
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    viaExistingTester: true,
  });
  return "sent";
}

/**
 * Web版でGoogleサインインした直後にクライアントから呼び出す。
 * サインイン済みユーザー本人のメールアドレスにだけ、TestFlightの外部テスト招待を送る
 * （なりすまし防止のため、リクエストで渡されたメールではなく`request.auth`のメールを使う）。
 */
/**
 * 管理者レポート（`getAdminFunnelReport`）の利用を許可するメールアドレス。
 * 個人開発の1人プロジェクトのため、複数管理者を想定した仕組み（Firestoreの
 * 管理者フラグなど）は導入せず、固定のメールアドレス比較で十分とした。
 */
const ADMIN_EMAIL = "kenichiyoshida13@gmail.com";

/**
 * `getAdminFunnelReport`の集計結果を、関数インスタンス内に一定時間だけ
 * キャッシュしておく（Cloud Functionsのウォームインスタンスはモジュール
 * レベルの変数を呼び出しをまたいで保持する）。
 * 全ユーザー・全`walkRoutes`/`stamps`/`sharedTrips`ドキュメントを毎回
 * スキャンする重い集計のため、ダッシュボードを開き直す・数分おきに
 * リロードするような使い方でも、その都度読み直さずに済むようにする。
 */
let cachedFunnelReport: { computedAt: number; result: Awaited<ReturnType<typeof computeAdminFunnelReport>> } | null =
  null;
const FUNNEL_REPORT_CACHE_TTL_MS = 15 * 60 * 1000;

/** 生存確認（`presence`）がこれより古い場合は「もういない」とみなす（`usePresence.ts`と同じ基準）。 */
const PRESENCE_STALE_AFTER_MS = 45_000;

interface FunnelPhase {
  key: "signedInOnly" | "startedTrip" | "collectedStamp" | "shared";
  label: string;
  count: number;
  suggestion: string;
}

/**
 * Web経由でアクセスしたユーザーが、利用のどの段階（フェーズ）にいるかを
 * 既存のFirestoreデータから集計する管理者向けレポート。新しい計測の仕込みは
 * 行わず、今すでに保存されているデータ（Firebase Authのユーザー一覧、
 * `users/{uid}/walkRoutes`・`stamps`・`sharedTrips`）から判定する。
 *
 * フェーズは次の4段階（後の段階に該当すればそちらを優先）:
 *   1. サインインのみ（時空旅未開始）
 *   2. 時空旅を開始（御朱印未収集）
 *   3. 御朱印を収集（時空旅は未共有）
 *   4. 時空旅を共有済み
 *
 * 呼び出し元の`request.auth.token.email`が{@link ADMIN_EMAIL}と一致する場合のみ
 * 結果を返す（なりすまし防止のため、クライアントから渡された値ではなく
 * Firebase Authが検証済みのトークンの中身を使う）。
 */
export const getAdminFunnelReport = onCall(async (request) => {
  if (request.auth?.token.email !== ADMIN_EMAIL) {
    throw new HttpsError("permission-denied", "管理者のみ利用できます。");
  }

  // 「現在の匿名閲覧者数」だけは文字通り"現在"の値であるべきなので、キャッシュせず
  // 毎回問い合わせる（`.count()`の集計クエリ1件だけなので軽い）。それ以外の重い
  // 集計（全ユーザー一覧・全`walkRoutes`/`stamps`/`sharedTrips`のスキャン）は
  // 一定時間キャッシュする。
  const db = admin.firestore();
  const presenceCountSnapshot = await db
    .collection("presence")
    .where("lastSeen", ">", admin.firestore.Timestamp.fromMillis(Date.now() - PRESENCE_STALE_AFTER_MS))
    .count()
    .get();

  const now = Date.now();
  if (!cachedFunnelReport || now - cachedFunnelReport.computedAt >= FUNNEL_REPORT_CACHE_TTL_MS) {
    cachedFunnelReport = { computedAt: now, result: await computeAdminFunnelReport(db) };
  }
  return {
    ...cachedFunnelReport.result,
    currentAnonymousViewers: presenceCountSnapshot.data().count,
  };
});

async function computeAdminFunnelReport(db: admin.firestore.Firestore) {
  let totalUsers = 0;
  let pageToken: string | undefined;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    totalUsers += page.users.length;
    pageToken = page.pageToken;
  } while (pageToken);

  const countDocsByOwnerUID = async (collectionGroupId: string): Promise<Map<string, number>> => {
    const counts = new Map<string, number>();
    const snapshot = await db.collectionGroup(collectionGroupId).get();
    snapshot.forEach((doc) => {
      const uid = doc.ref.parent.parent?.id;
      if (!uid) return;
      counts.set(uid, (counts.get(uid) ?? 0) + 1);
    });
    return counts;
  };

  const [walkRouteCountsByUID, stampCountsByUID, sharedTripsSnapshot] = await Promise.all([
    countDocsByOwnerUID("walkRoutes"),
    countDocsByOwnerUID("stamps"),
    db.collection("sharedTrips").get(),
  ]);

  const sharedTripCountsByUID = new Map<string, number>();
  sharedTripsSnapshot.forEach((doc) => {
    const ownerUID = doc.data().ownerUserID as string | undefined;
    if (!ownerUID) return;
    sharedTripCountsByUID.set(ownerUID, (sharedTripCountsByUID.get(ownerUID) ?? 0) + 1);
  });

  const activeUIDs = new Set<string>([
    ...walkRouteCountsByUID.keys(),
    ...stampCountsByUID.keys(),
    ...sharedTripCountsByUID.keys(),
  ]);

  let startedTripCount = 0;
  let collectedStampCount = 0;
  let sharedCount = 0;
  for (const uid of activeUIDs) {
    if ((sharedTripCountsByUID.get(uid) ?? 0) > 0) {
      sharedCount += 1;
    } else if ((stampCountsByUID.get(uid) ?? 0) > 0) {
      collectedStampCount += 1;
    } else if ((walkRouteCountsByUID.get(uid) ?? 0) > 0) {
      startedTripCount += 1;
    }
  }
  // Firebase Authには登録済みだが、上記のどのアクティビティも無いユーザー
  // （サインインしただけで時空旅を始めていない層）。
  const signedInOnlyCount = Math.max(totalUsers - activeUIDs.size, 0);

  const phases: FunnelPhase[] = [
    {
      key: "signedInOnly",
      label: "サインインのみ（時空旅未開始）",
      count: signedInOnlyCount,
      suggestion: "初回起動〜最初の古地図が浮かび上がる演出やプッシュ通知で、最初の「スタート」を後押しする。",
    },
    {
      key: "startedTrip",
      label: "時空旅を開始（御朱印は未収集）",
      count: startedTripCount,
      suggestion: "チェックポイントまでの距離が分かる導線を強化し、最初の御朱印を獲得しやすくする。",
    },
    {
      key: "collectedStamp",
      label: "御朱印を収集（時空旅は未共有）",
      count: collectedStampCount,
      suggestion: "「みんなの時空旅」への共有導線・シェアの心理的ハードルを下げるコピーを見直す。",
    },
    {
      key: "shared",
      label: "時空旅を共有済み",
      count: sharedCount,
      suggestion: "アンバサダー候補。レビュー依頼やリファラル施策の対象として優先的にアプローチする。",
    },
  ];

  return {
    totalUsers,
    phases,
  };
}

export const requestTestFlightInvite = onCall(
  {
    secrets: [
      APPSTORE_ISSUER_ID,
      APPSTORE_KEY_ID,
      APPSTORE_PRIVATE_KEY,
      APPSTORE_BETA_GROUP_ID,
    ],
  },
  async (request) => {
    if (!request.auth?.token.email) {
      throw new HttpsError("unauthenticated", "サインインが必要です。");
    }
    const email = request.auth.token.email;
    const displayName = (request.auth.token.name as string | undefined) ?? "";
    const [firstName, ...rest] = displayName.split(" ").filter(Boolean);
    const lastName = rest.join(" ");

    const status = await inviteToTestFlight({
      email,
      firstName: firstName || "Komap",
      lastName: lastName || "Tester",
    });
    return { status };
  },
);
