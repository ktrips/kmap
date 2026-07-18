import {
  type User,
  GoogleAuthProvider,
  OAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut as firebaseSignOut,
} from "firebase/auth";
import { useCallback, useEffect, useState } from "react";
import { auth } from "./firebase";

/**
 * Firebase Authenticationの状態を監視し、Sign in with Apple / Googleサインイン（Web版）を提供する。
 *
 * iOSアプリと同じFirebaseプロジェクトのApple/Google providerを使うことで、
 * 同じアカウントでログインすれば同じ `uid` になり、`users/{uid}/places` を共有できる。
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

  const signInWithApple = useCallback(async () => {
    if (!auth) {
      setError("Firebaseが設定されていません。");
      return;
    }
    setIsSigningIn(true);
    setError(null);
    try {
      const provider = new OAuthProvider("apple.com");
      provider.addScope("email");
      provider.addScope("name");
      await signInWithPopup(auth, provider);
    } catch (err) {
      setError(err instanceof Error ? err.message : "サインインに失敗しました。");
    } finally {
      setIsSigningIn(false);
    }
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
    signInWithApple,
    signInWithGoogle,
    signOut,
  };
}
