import {
  type User,
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut as firebaseSignOut,
} from "firebase/auth";
import { useCallback, useEffect, useState } from "react";
import { auth } from "./firebase";
import { useTestFlightInvite } from "./useTestFlightInvite";

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
  const { requestInvite } = useTestFlightInvite();

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
      // iOSアプリの案内が目的のため、失敗してもサインイン自体は成立させる
      // （エラーはコンソールに出すだけで、ユーザー操作をブロックしない）。
      void requestInvite();
    } catch (err) {
      setError(err instanceof Error ? err.message : "サインインに失敗しました。");
    } finally {
      setIsSigningIn(false);
    }
  }, [requestInvite]);

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
