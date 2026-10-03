import { Timestamp, type DocumentData } from "firebase/firestore/lite";

/**
 * FirestoreのREST API（`runQuery`）で、指定した項目だけを読む。
 *
 * SDK（軽量版を含む）には読む項目を絞る方法が無く、公開中の旅の一覧が、一覧では使わない軌跡の座標
 * （`latitudes`・`longitudes`。旅の文書の大半を占める）まで毎回読んでいたため、一覧だけこちらで読む。
 * サインインしていない訪問者も読める（公開中の旅は Firestore ルールで誰でも読める）ので、認証は付けない。
 */
export async function runProjectedQuery(
  structuredQuery: Record<string, unknown>,
  fields: string[],
): Promise<{ path: string; data: DocumentData }[]> {
  const projectId = import.meta.env.VITE_FIREBASE_PROJECT_ID;
  const apiKey = import.meta.env.VITE_FIREBASE_API_KEY;
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        structuredQuery: { ...structuredQuery, select: { fields: fields.map((fieldPath) => ({ fieldPath })) } },
      }),
    },
  );
  if (!response.ok) throw new Error(`読み込みに失敗しました（${response.status}）。`);
  const results = (await response.json()) as { document?: { name: string; fields?: Record<string, RestValue> } }[];
  const prefix = `projects/${projectId}/databases/(default)/documents/`;
  return results.flatMap(({ document }) =>
    document ? [{ path: document.name.slice(prefix.length), data: decodeFields(document.fields ?? {}) }] : [],
  );
}

type RestValue = Record<string, unknown>;

function decodeFields(fields: Record<string, RestValue>): DocumentData {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

/** RESTの値（`{"stringValue": "..."}`など）を、SDKで読んだ時と同じ形にする（日時はSDKの`Timestamp`）。 */
function decodeValue(value: RestValue): unknown {
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return Timestamp.fromDate(new Date(value.timestampValue as string));
  if ("mapValue" in value) return decodeFields((value.mapValue as { fields?: Record<string, RestValue> }).fields ?? {});
  if ("arrayValue" in value) return ((value.arrayValue as { values?: RestValue[] }).values ?? []).map(decodeValue);
  return null;
}
