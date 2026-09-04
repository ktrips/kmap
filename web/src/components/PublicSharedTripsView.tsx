import { useMemo, useState } from "react";
import { TripDetail } from "./TripDetail";
import { TripList } from "./TripList";
import { usePresence } from "../lib/usePresence";
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
  // 時空旅を選ぶと、一覧と案内文（サインインの案内など）を収納して
  // 地図・写真の表示スペースを広げる。「一覧」ボタンで再び開く。
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);

  const trips = useMemo<UnifiedTrip[]>(
    () => sharedTrips.map(fromSharedTrip).sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime()),
    [sharedTrips],
  );
  const selectedTrip = trips.find((trip) => trip.id === selectedTripId) ?? null;
  const activeVisitorCount = usePresence();

  const handleSelectTrip = (trip: UnifiedTrip) => {
    setSelectedTripId(trip.id);
    setIsSidebarOpen(false);
  };

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="app-header-title">
          <img src="/app-icon.png" alt="Komap" className="app-header-icon" />
          <p className="brand-eyebrow">Komap 古地図巡り</p>
        </div>
      </header>

      {isSidebarOpen && (
        <div className="public-intro">
          <h1>みんなで時空を旅しよう</h1>
          {activeVisitorCount !== null && activeVisitorCount > 0 && (
            <p className="public-intro-presence">🕐 今{activeVisitorCount}人が時空旅中</p>
          )}
          <p>みんなが公開している「時空旅」の記録（歩いたルート・投稿写真）を地図で見ることができます。</p>
          {isFirebaseConfigured && (
            <div className="public-intro-cta">
              <button
                className="google-button google-button-large google-button-accent"
                onClick={onSignInWithGoogle}
                disabled={isSigningIn}
              >
                {isSigningIn ? (
                  "サインイン中..."
                ) : (
                  <span className="google-button-content">
                    <span className="google-button-title">Googleでサインイン</span>
                    <span className="google-button-bullet">・みんなの時空旅が写真入りで見れる</span>
                    <span className="google-button-bullet">・iOSアプリで自分で時空旅を作成</span>
                  </span>
                )}
              </button>
            </div>
          )}
          {error && <p className="error-text">{error}</p>}
        </div>
      )}

      <div className="app-body">
        {isSidebarOpen && (
          <aside className="app-sidebar">
            <TripList trips={trips} selectedId={selectedTripId} onSelect={handleSelectTrip} />
            <a
              className="sidebar-footer-link"
              href="https://github.com/ktrips/kmap#readme"
              target="_blank"
              rel="noreferrer"
            >
              📖 Komapの使い方
            </a>
          </aside>
        )}
        <main className="app-main">
          {!isSidebarOpen && (
            <div className="detail-header-bar">
              <button
                type="button"
                className="sidebar-menu-button"
                onClick={() => setIsSidebarOpen(true)}
                aria-label="一覧を表示"
              >
                <span aria-hidden="true">☰</span> 一覧
              </button>
              <span className="detail-header-label">時空旅の記録</span>
            </div>
          )}
          <TripDetail trip={selectedTrip} currentUser={null} onRequestSignIn={onSignInWithGoogle} />
        </main>
      </div>
    </div>
  );
}
