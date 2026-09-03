import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import jwt from "jsonwebtoken";

admin.initializeApp();
setGlobalOptions({ region: "asia-northeast1", maxInstances: 10 });

const APPSTORE_ISSUER_ID = defineSecret("APPSTORE_CONNECT_ISSUER_ID");
const APPSTORE_KEY_ID = defineSecret("APPSTORE_CONNECT_KEY_ID");
const APPSTORE_PRIVATE_KEY = defineSecret("APPSTORE_CONNECT_PRIVATE_KEY");
const APPSTORE_BETA_GROUP_ID = defineSecret("APPSTORE_CONNECT_BETA_GROUP_ID");

const APPSTORE_API_BASE = "https://api.appstoreconnect.apple.com/v1";

/** App Store Connect APIへの認証に使う短命JWT（ES256）を都度作る。 */
function buildAppStoreConnectToken(): string {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: APPSTORE_ISSUER_ID.value(),
      iat: now,
      exp: now + 19 * 60, // App Store Connect APIのトークンは最長20分
      aud: "appstoreconnect-v1",
    },
    APPSTORE_PRIVATE_KEY.value().replace(/\\n/g, "\n"),
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
    const addBody = await addToGroupResponse.json().catch(() => ({}));
    logger.error("既存betaTesterのグループ追加に失敗", {
      status: addToGroupResponse.status,
      body: addBody,
    });
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
