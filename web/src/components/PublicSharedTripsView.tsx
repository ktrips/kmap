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
      </header>

      <div className="public-intro">
        <h1>みんなの時空旅</h1>
        <p>
          みんなが公開している「時空旅」の記録（歩いたルート・投稿写真）を
          地図で見ることができます。気になる時空旅を左のリストから選んで楽しんで下さい。
        </p>
        {isFirebaseConfigured && (
          <div className="public-intro-cta">
            <button className="google-button google-button-large" onClick={onSignInWithGoogle} disabled={isSigningIn}>
              {isSigningIn ? "サインイン中..." : "Googleでサインイン"}
            </button>
            <p className="public-intro-cta-note">
              サインインすると、Webで写真が見えることや、iOSアプリをインストールして時空旅を楽しめます。
            </p>
          </div>
        )}
        {error && <p className="error-text">{error}</p>}
      </div>

      <div className="app-body">
        <aside className="app-sidebar">
          <TripList trips={trips} selectedId={selectedTripId} onSelect={(trip) => setSelectedTripId(trip.id)} />
          <a
            className="sidebar-footer-link"
            href="https://github.com/ktrips/kmap#readme"
            target="_blank"
            rel="noreferrer"
          >
            📖 Komapの使い方
          </a>
        </aside>
        <main className="app-main">
          <TripDetail trip={selectedTrip} />
        </main>
      </div>
    </div>
  );
}
