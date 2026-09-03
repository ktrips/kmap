import { useMemo, useState } from "react";
import { TripDetail } from "./TripDetail";
import { TripList } from "./TripList";
import { fromSharedTrip, type UnifiedTrip } from "../types/unifiedTrip";
import type { SharedTrip } from "../types/sharedTrip";

interface Props {
  sharedTrips: SharedTrip[];
  isSigningIn: boolean;
  error: string | null;
  isFirebaseConfigured: boolean;
  onSignInWithGoogle: () => void;
}

/**
 * サインインしていない訪問者向けに、「みんなの時空旅」（公開済みの歩いたルート・写真）を
 * 誰でも地図で見られる公開ページ。あわせて、iOSアプリのGPS記録機能や
 * Googleサインインでできることを紹介し、サインインへ誘導する。
 */
export function PublicSharedTripsView({
  sharedTrips,
  isSigningIn,
  error,
  isFirebaseConfigured,
  onSignInWithGoogle,
}: Props) {
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);

  const trips = useMemo<UnifiedTrip[]>(
    () => sharedTrips.map(fromSharedTrip).sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime()),
    [sharedTrips],
  );
  const selectedTrip = trips.find((trip) => trip.id === selectedTripId) ?? null;

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="app-header-title">
          <img src="/app-icon.png" alt="Komap" className="app-header-icon" />
          <p className="brand-eyebrow">Komap 古地図巡り</p>
        </div>
        {isFirebaseConfigured && (
          <button className="google-button google-button-compact" onClick={onSignInWithGoogle} disabled={isSigningIn}>
            {isSigningIn ? "サインイン中..." : "Googleでサインイン"}
          </button>
        )}
      </header>

      <div className="public-intro">
        <h1>みんなの時空旅</h1>
        <p>
          みんなが公開している「時空旅」の記録（歩いたルート・投稿写真）を
          地図で見ることができます。気になる時空旅を左のリストから選んで楽しんで下さい。
        </p>
        <div className="public-intro-points">
          <p>
            <strong>📱 iOSアプリなら、</strong>
            実際に歩きながらGPSで自分だけの時空旅を記録できます。古地図を重ねて、昔の街を歩いているような散策が楽しめます。
          </p>
          <p>
            <strong>🔑 Googleでサインインすると、</strong>
            自分が歩いた時空旅・集めた御朱印・投稿した写真がクラウドに保存され、このWebページからいつでも見返せるようになります。
          </p>
        </div>
        {error && <p className="error-text">{error}</p>}
      </div>

      <div className="app-body">
        <aside className="app-sidebar">
          <TripList trips={trips} selectedId={selectedTripId} onSelect={(trip) => setSelectedTripId(trip.id)} />
        </aside>
        <main className="app-main">
          <TripDetail trip={selectedTrip} />
        </main>
      </div>
    </div>
  );
}
