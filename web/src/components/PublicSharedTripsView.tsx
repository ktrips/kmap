import { useEffect, useMemo, useState } from "react";
import { TripDetail } from "./TripDetail";
import { TripList } from "./TripList";
import { HowToUseModal } from "./HowToUseModal";
import { KindleBookModal } from "./KindleBookModal";
import { useIsMobile } from "../lib/useIsMobile";
import { usePresence } from "../lib/usePresence";
import { useSelectedTripId } from "../lib/useSelectedTripId";
import { useSharedTripById } from "../lib/useSharedTripById";
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
  const [selectedTripId, setSelectedTripId] = useSelectedTripId();
  const isMobile = useIsMobile();
  // スマホ幅では、時空旅を選ぶと一覧と案内文（サインインの案内など）を収納して
  // 地図・写真の表示スペースを広げる（「一覧」ボタンで再び開く。URL（`?t=`）付きで
  // 開いた場合は、最初から詳細を表示した状態にする）。モバイルでない
  // （PC・タブレット幅の）場合は、旅を選んでも左の一覧はそのまま表示したままにする。
  const [isSidebarOpen, setIsSidebarOpen] = useState(isMobile ? selectedTripId === null : true);

  // モバイル幅からPC・タブレット幅へリサイズ（画面回転含む）された時も、
  // 一覧が収納されたままにならないよう、常に表示された状態に戻す。
  useEffect(() => {
    if (!isMobile) {
      setIsSidebarOpen(true);
    }
  }, [isMobile]);
  const [isHowToOpen, setIsHowToOpen] = useState(false);
  const [isKindleOpen, setIsKindleOpen] = useState(false);

  const trips = useMemo<UnifiedTrip[]>(
    () => sharedTrips.map(fromSharedTrip).sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime()),
    [sharedTrips],
  );
  const isSelectedTripInList = selectedTripId !== null && trips.some((trip) => trip.id === selectedTripId);
  // 一覧（直近50件）に無い旅を共有リンクで直接開いた時のための、個別取得フォールバック。
  const fallbackSharedTrip = useSharedTripById(selectedTripId, isSelectedTripInList);
  const selectedTrip =
    trips.find((trip) => trip.id === selectedTripId) ??
    (fallbackSharedTrip ? fromSharedTrip(fallbackSharedTrip) : null);
  const activeVisitorCount = usePresence();
  // ヘッダーの「ログイン」ボタンを出す条件。モバイルでは従来通り一覧を閉じている時
  // （＝詳細を全画面表示している時）。モバイルでない時は一覧を閉じることが無くなった
  // ため、代わりに「旅を選んでいる時」に出す。
  const showLoginHeaderButton = isMobile ? !isSidebarOpen : selectedTrip !== null;

  const handleSelectTrip = (trip: UnifiedTrip) => {
    setSelectedTripId(trip.id);
    // モバイル幅の時だけ、詳細を広く見せるために一覧を収納する。
    // それ以外（PC・タブレット幅）では一覧を表示したままにする。
    if (isMobile) {
      setIsSidebarOpen(false);
    }
  };

  // 左上のアイコンを押した時、選んでいた時空旅を解除してホーム（一覧＋案内のみの
  // 状態）に戻す。モバイル・PCどちらでも同じ挙動にする。
  const handleGoHome = () => {
    setSelectedTripId(null);
    setIsSidebarOpen(true);
  };

  // 見出し・Googleサインインの案内。モバイルではこれまで通りヘッダーの下（一覧の上）に
  // 表示するが、モバイルでない時はヘッダー直下には出さず、代わりに右側の表示ペインの
  // 「リストから、時空旅を選んでください。」の上（＝何も選んでいない時だけ）に表示する。
  const introContent = (
    <div className="public-intro">
      <div className="public-intro-headline">
        <h1>そうだ、時空旅しよう</h1>
      </div>
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
                <span className="google-button-bullet">・みんなの時空旅(古地図・御朱印)を見れる！</span>
                <span className="google-button-bullet">・iOSアプリダウンロードで自分で旅を作れる！</span>
              </span>
            )}
          </button>
        </div>
      )}
      {error && <p className="error-text">{error}</p>}
    </div>
  );

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="app-header-title">
          <button
            type="button"
            className="app-header-icon-button"
            onClick={handleGoHome}
            aria-label="ホームに戻る"
          >
            <img src="/app-icon.png" alt="Komap" className="app-header-icon" />
          </button>
          <p className="brand-eyebrow">Komap 古地図巡り</p>
          {isSidebarOpen && activeVisitorCount !== null && activeVisitorCount > 0 && (
            <p className="public-intro-presence">🕐 今{activeVisitorCount}人が時空旅中</p>
          )}
          {!isSidebarOpen && (
            <button
              type="button"
              className="sidebar-menu-button"
              onClick={() => setIsSidebarOpen(true)}
              aria-label="一覧を表示"
            >
              <span aria-hidden="true">☰</span> 一覧
            </button>
          )}
        </div>
        {showLoginHeaderButton ? (
          <button
            type="button"
            className="login-header-button"
            onClick={onSignInWithGoogle}
            disabled={isSigningIn}
          >
            {isSigningIn ? "サインイン中..." : "ログイン"}
          </button>
        ) : (
          <button type="button" className="howto-header-button" onClick={() => setIsHowToOpen(true)}>
            📖 使い方
          </button>
        )}
      </header>

      {isMobile && isSidebarOpen && introContent}

      {isHowToOpen && (
        <HowToUseModal onClose={() => setIsHowToOpen(false)} onSignInWithGoogle={onSignInWithGoogle} />
      )}
      {isKindleOpen && <KindleBookModal onClose={() => setIsKindleOpen(false)} />}

      <div className="app-body">
        {isSidebarOpen && (
          <aside className="app-sidebar">
            <p className="trip-list-heading">みんなの時空旅 ({trips.length}件の公開旅日記)</p>
            <TripList trips={trips} selectedId={selectedTripId} onSelect={handleSelectTrip} />
            <button type="button" className="sidebar-footer-button" onClick={() => setIsKindleOpen(true)}>
              📚 Komapの作り方 Kindle（一部無料）
            </button>
            <a
              href="https://link.amazon/B006awnVi"
              target="_blank"
              rel="noopener noreferrer"
              className="sidebar-footer-link"
            >
              📖 この続きはKindle本で
            </a>
          </aside>
        )}
        <main className="app-main">
          {!isMobile && !selectedTrip && introContent}
          <TripDetail trip={selectedTrip} currentUser={null} onRequestSignIn={onSignInWithGoogle} />
        </main>
      </div>
    </div>
  );
}
