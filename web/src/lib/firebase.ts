import { type FirebaseApp, initializeApp } from "firebase/app";
import { type Analytics, isSupported as isAnalyticsSupported, getAnalytics } from "firebase/analytics";
import { type Auth, getAuth } from "firebase/auth";
import { type Firestore, getFirestore } from "firebase/firestore";

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
let analyticsInstance: Analytics | undefined;

if (isFirebaseConfigured) {
  app = initializeApp(firebaseConfig);
  authInstance = getAuth(app);
  dbInstance = getFirestore(app);

  // Analytics はSafariのプライベートモードなど一部環境で未サポートのため、
  // 対応している場合のみ初期化する（未対応でもアプリ本体は問題なく動く）。
  if (firebaseConfig.measurementId) {
    isAnalyticsSupported()
      .then((supported) => {
        if (supported && app) {
          analyticsInstance = getAnalytics(app);
        }
      })
      .catch(() => {
        // Analyticsが使えない環境は無視して続行する。
      });
  }
}

export const auth = authInstance;
export const db = dbInstance;
export function getAnalyticsInstance(): Analytics | undefined {
  return analyticsInstance;
}
