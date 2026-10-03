import { type FirebaseApp, initializeApp } from "firebase/app";
import { type Auth, getAuth } from "firebase/auth";
import { type Firestore, getFirestore } from "firebase/firestore/lite";
import type { Functions } from "firebase/functions";
import type { Analytics } from "firebase/analytics";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
  measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID,
};

/** `.env` にFirebaseの設定値が入っているかどうか（未設定ならセットアップ案内を表示する）。 */
export const isFirebaseConfigured = Boolean(
  firebaseConfig.apiKey && firebaseConfig.projectId && firebaseConfig.appId,
);

let app: FirebaseApp | undefined;
let authInstance: Auth | undefined;
let dbInstance: Firestore | undefined;
let realtimeDbInstance: import("firebase/firestore").Firestore | undefined;
let functionsInstance: Functions | undefined;
let analyticsInstance: Analytics | undefined;

if (isFirebaseConfigured) {
  app = initializeApp(firebaseConfig);
  authInstance = getAuth(app);
  dbInstance = getFirestore(app);

  // Analyticsは初期表示には不要な上、Safariのプライベートモードなど一部環境で
  // 未サポートのため、動的importで遅延読み込みし、対応している場合のみ初期化する
  // （未対応・未使用でも初期バンドルを太らせない）。
  // さらに、画面の表示に必要な読み込み（一覧の取得など）と通信を取り合わないよう、ページの読み込みが終わってから始める。
  const startAnalytics = () =>
    import("firebase/analytics")
      .then(({ isSupported, getAnalytics }) => isSupported().then((supported) => ({ supported, getAnalytics })))
      .then(({ supported, getAnalytics }) => {
        if (supported && app) {
          analyticsInstance = getAnalytics(app);
        }
      })
      .catch(() => {
        // Analyticsが使えない環境は無視して続行する。
      });
  if (firebaseConfig.measurementId) {
    if (document.readyState === "complete") setTimeout(startAnalytics, 1000);
    else window.addEventListener("load", () => setTimeout(startAnalytics, 1000), { once: true });
  }
}

export const auth = authInstance;
/**
 * 読み書き用のFirestore（軽量版 `firebase/firestore/lite`。リアルタイム更新は無い）。
 * 公開ページ（未サインインの訪問者）が最初に読み込む量を減らすため、通常はこちらを使う。
 */
export const db = dbInstance;

/**
 * リアルタイム更新（`onSnapshot`）が必要な、サインイン後の自分の記録の購読だけで使う完全版のFirestore。
 * 初回表示に含めないよう、初めて必要になった時に読み込む。
 */
export async function loadRealtimeFirestore() {
  const module = await import("firebase/firestore");
  if (!realtimeDbInstance && app) {
    realtimeDbInstance = module.getFirestore(app);
  }
  return { firestore: module, db: realtimeDbInstance };
}

/**
 * Cloud Functions（管理者レポート・TestFlight招待）はサインインした人しか使わないため、
 * SDKを初期バンドルに含めず、初めて呼ぶ時に読み込む（未サインインの訪問者の読み込み量を減らす）。
 * Cloud Functionsは `functions/src/index.ts` の `setGlobalOptions` と同じリージョン
 * （asia-northeast1）を指定する必要がある。
 */
export async function loadFunctions(region: "asia-northeast1" | "us-central1" = "asia-northeast1") {
  const module = await import("firebase/functions");
  if (region !== "asia-northeast1") {
    // Firestoreのトリガーと同じ場所に置いた関数（`functions/src/sharedTrips.ts`の移行など）。
    return { functions: app ? module.getFunctions(app, region) : undefined, httpsCallable: module.httpsCallable, FunctionsError: module.FunctionsError };
  }
  if (!functionsInstance && app) {
    functionsInstance = module.getFunctions(app, "asia-northeast1");
  }
  return { functions: functionsInstance, httpsCallable: module.httpsCallable, FunctionsError: module.FunctionsError };
}
export function getAnalyticsInstance(): Analytics | undefined {
  return analyticsInstance;
}
