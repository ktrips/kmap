import { useMemo, useState } from "react";
import type { User } from "firebase/auth";
import { AdminFunnelReport } from "./components/AdminFunnelReport";
import { Header } from "./components/Header";
import { MapView } from "./components/MapView";
import { PlaceDetail } from "./components/PlaceDetail";
import { PlaceList } from "./components/PlaceList";
import { TripDetail } from "./components/TripDetail";
import { TripList } from "./components/TripList";
import { usePhotoPosts } from "./lib/usePhotoPosts";
import { usePlaces } from "./lib/usePlaces";
import { useSelectedTripId } from "./lib/useSelectedTripId";
import { useStamps } from "./lib/useStamps";
import { useWalkRoutes } from "./lib/useWalkRoutes";
import type { SharedTrip } from "./types/sharedTrip";
import { fromSharedTrip, fromWalkTrip, type UnifiedTrip } from "./types/unifiedTrip";
import type { SavedPlace } from "./types/place";

type SidebarTab = "places" | "trips" | "admin";

/** 管理者レポートタブを表示してよいメールアドレス（Cloud Function側でも同じ値を検証する）。 */
const ADMIN_EMAIL = "kenichiyoshida13@gmail.com";

interface Props {
  user: User;
  sharedTrips: SharedTrip[];
  onSignOut: () => void;
}

/**
 * サインイン済みのユーザー専用の画面（保存した物語・自分の時空旅）。
 * `usePlaces`/`useWalkRoutes`/`useStamps`/`usePhotoPosts`はサインインしていないと
 * 使わないため、この画面ごとApp.tsxから遅延読み込み（`React.lazy`）している
 * （未サインインの訪問者が最初に読み込むコード量を減らすため）。
 */
export default function AuthenticatedApp({ user, sharedTrips, onSignOut }: Props) {
  const { places } = usePlaces(user.uid);
  const { trips: ownTrips } = useWalkRoutes(user.uid);
  const { stamps } = useStamps(user.uid);
  const { photoPosts } = usePhotoPosts(user.uid);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTripId, setSelectedTripId] = useSelectedTripId();
  const [tab, setTab] = useState<SidebarTab>("trips");
  const isAdmin = user.email === ADMIN_EMAIL;
  // 旅の詳細を表示すると左のメニュー（一覧）は収納し、画面を広く使えるようにする。
  // メニューボタンを押すか、タブを切り替えると再び開く。
  // URL（`?trip=`）付きで開いた場合は、最初から詳細を表示した状態にする。
  const [isSidebarOpen, setIsSidebarOpen] = useState(selectedTripId === null);

  // 「時空旅」タブは、自分の記録と他ユーザーが公開した時空旅（sharedTrips）の
  // 両方を並べる。自分の記録のうち公開中のものは、同じidが`sharedTrips`にも
  // 存在するため、重複して2件表示されないよう自分のID分は`sharedTrips`側から
  // 除外してから合流させる。共有されている（＝自分の公開中の記録、または
  // 他ユーザーの記録）ことは、一覧側で🌐アイコンとして示す。
  const sharedTripIDs = useMemo(() => new Set(sharedTrips.map((trip) => trip.id)), [sharedTrips]);
  const unifiedTrips = useMemo<UnifiedTrip[]>(() => {
    const ownUnified = ownTrips.map((trip) =>
      fromWalkTrip(trip, stamps, photoPosts, sharedTripIDs.has(trip.id)),
    );
    const ownIDs = new Set(ownUnified.map((trip) => trip.id));
    const othersShared = sharedTrips.filter((trip) => !ownIDs.has(trip.id)).map(fromSharedTrip);
    return [...ownUnified, ...othersShared].sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime());
  }, [ownTrips, sharedTrips, sharedTripIDs, stamps, photoPosts]);

  const selectedPlace = places.find((place) => place.id === selectedId) ?? null;
  const selectedTrip = unifiedTrips.find((trip) => trip.id === selectedTripId) ?? null;

  const handleSelect = (place: SavedPlace) => {
    setSelectedId(place.id);
  };

  const handleSelectTrip = (trip: UnifiedTrip) => {
    setSelectedTripId(trip.id);
    setIsSidebarOpen(false);
  };

  const handleTabChange = (nextTab: SidebarTab) => {
    setTab(nextTab);
    setIsSidebarOpen(true);
  };

  return (
    <div className="app-shell">
      <Header user={user} tripCount={ownTrips.length} onSignOut={onSignOut} />
      <div className="app-body">
        {isSidebarOpen && (
          <aside className="app-sidebar">
            <div className="sidebar-tabs">
              <button
                className={`sidebar-tab ${tab === "places" ? "is-active" : ""}`}
                onClick={() => handleTabChange("places")}
              >
                保存した物語
              </button>
              <button
                className={`sidebar-tab ${tab === "trips" ? "is-active" : ""}`}
                onClick={() => handleTabChange("trips")}
              >
                時空旅
              </button>
              {isAdmin && (
                <button
                  className={`sidebar-tab ${tab === "admin" ? "is-active" : ""}`}
                  onClick={() => handleTabChange("admin")}
                >
                  管理者レポート
                </button>
              )}
            </div>
            {tab === "places" && <PlaceList places={places} selectedId={selectedId} onSelect={handleSelect} />}
            {tab === "trips" && (
              <TripList trips={unifiedTrips} selectedId={selectedTripId} onSelect={handleSelectTrip} />
            )}
            {tab === "admin" && (
              <p className="admin-report-sidebar-hint">
                Web経由のユーザーが今どの利用フェーズにいるかをまとめたレポートです。
              </p>
            )}
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
              {tab === "trips" && <span className="detail-header-label">時空旅の記録</span>}
              {tab === "admin" && <span className="detail-header-label">管理者レポート</span>}
            </div>
          )}
          {tab === "places" && (
            <>
              <MapView places={places} selectedId={selectedId} onSelect={handleSelect} />
              <PlaceDetail place={selectedPlace} />
            </>
          )}
          {tab === "trips" && (
            <TripDetail trip={selectedTrip} currentUser={{ uid: user.uid, displayName: user.displayName }} />
          )}
          {tab === "admin" && isAdmin && <AdminFunnelReport />}
        </main>
      </div>
    </div>
  );
}
