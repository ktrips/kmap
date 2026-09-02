import { lazy, Suspense } from "react";
import { PublicSharedTripsView } from "./components/PublicSharedTripsView";
import { isFirebaseConfigured } from "./lib/firebase";
import { useAuth } from "./lib/useAuth";
import { useSharedTrips } from "./lib/useSharedTrips";

// サインインしていないと使わない画面（保存した物語・自分の時空旅、および
// それが使うFirestoreフック群）はサインインするまで読み込まない。
// 未サインインの訪問者（＝「みんなの時空旅」を見るだけの大半の来訪者）が
// 最初に読み込むJSの量を減らすため。
const AuthenticatedApp = lazy(() => import("./AuthenticatedApp"));

export default function App() {
  const { user, isInitializing, isSigningIn, error, signInWithGoogle, signOut } = useAuth();
  const { trips: sharedTrips } = useSharedTrips();

  if (isInitializing) {
    return (
      <div className="loading-screen">
        <p>読み込み中…</p>
      </div>
    );
  }

  if (!user) {
    return (
      <PublicSharedTripsView
        sharedTrips={sharedTrips}
        isSigningIn={isSigningIn}
        error={error}
        isFirebaseConfigured={isFirebaseConfigured}
        onSignInWithGoogle={signInWithGoogle}
      />
    );
  }

  return (
    <Suspense
      fallback={
        <div className="loading-screen">
          <p>読み込み中…</p>
        </div>
      }
    >
      <AuthenticatedApp user={user} sharedTrips={sharedTrips} onSignOut={signOut} />
    </Suspense>
  );
}
