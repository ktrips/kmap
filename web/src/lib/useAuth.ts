import {
  type User,
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut as firebaseSignOut,
} from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { useCallback, useEffect, useState } from "react";
import { auth, functions } from "./firebase";

/**
 * サインインしたユーザー本人のメールアドレスへ、TestFlightの外部テスト招待を送るよう
 * Cloud Functionへ依頼する。既に送信済みの場合はFunction側で何もしないため、
 * 呼び出し側（ここ）は結果を気にせず一度呼べばよい。
 *
 * - iOSアプリの案内・ダウンロードが目的のため、失敗してもサインイン自体は成立させる
 *   （エラーはコンソールに出すだけで、ユーザー操作をブロックしない）。
 */
function requestTestFlightInviteInBackground() {
  if (!functions) return;
  const call = httpsCallable(functions, "requestTestFlightInvite");
  call().catch((err) => {
    console.warn("TestFlight招待の送信に失敗しました（サインインは成功しています）", err);
  });
}

/**
 * Firebase Authenticationの状態を監視し、Googleサインイン（Web版）を提供する。
 *
 * iOSアプリと同じFirebaseプロジェクトのGoogle providerを使うことで、
 * 同じGoogleアカウントでログインすれば同じ `uid` になり、`users/{uid}/places` を共有できる。
 */
export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [isInitializing, setIsInitializing] = useState(true);
  const [isSigningIn, setIsSigningIn] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth) {
      setIsInitializing(false);
      return;
    }
    const unsubscribe = onAuthStateChanged(auth, (nextUser) => {
      setUser(nextUser);
      setIsInitializing(false);
    });
    return () => unsubscribe();
  }, []);

  const signInWithGoogle = useCallback(async () => {
    if (!auth) {
      setError("Firebaseが設定されていません。");
      return;
    }
    setIsSigningIn(true);
    setError(null);
    try {
      const provider = new GoogleAuthProvider();
      await signInWithPopup(auth, provider);
      requestTestFlightInviteInBackground();
    } catch (err) {
      setError(err instanceof Error ? err.message : "サインインに失敗しました。");
    } finally {
      setIsSigningIn(false);
    }
  }, []);

  const signOut = useCallback(async () => {
    if (!auth) return;
    await firebaseSignOut(auth);
  }, []);

  return {
    user,
    isInitializing,
    isSigningIn,
    error,
    signInWithGoogle,
    signOut,
  };
}
