import { useMemo, useState } from "react";
import type { User } from "firebase/auth";
import { AdminFunnelReport } from "./components/AdminFunnelReport";
import { Header } from "./components/Header";
import { MapView } from "./components/MapView";
import { OldMapDetail } from "./components/OldMapDetail";
import { OldMapList } from "./components/OldMapList";
import type { OldMapEntry } from "./lib/oldMapCatalog";
import { PlaceDetail } from "./components/PlaceDetail";
import { PlaceList } from "./components/PlaceList";
import { TripDetail } from "./components/TripDetail";
import { TripList } from "./components/TripList";
import { usePhotoPosts } from "./lib/usePhotoPosts";
import { usePlaces } from "./lib/usePlaces";
import { useStamps } from "./lib/useStamps";
import { useTripBrowser } from "./lib/useTripBrowser";
import { useWalkRoutes } from "./lib/useWalkRoutes";
import type { SharedTrip } from "./types/sharedTrip";
import { fromSharedTrip, fromWalkTrip, groupByWalkRoute, type UnifiedTrip } from "./types/unifiedTrip";
import type { SavedPlace } from "./types/place";

type SidebarTab = "places" | "trips" | "maps" | "admin";

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
  const [tab, setTab] = useState<SidebarTab>("trips");
  const [selectedMap, setSelectedMap] = useState<OldMapEntry | null>(null);
  const isAdmin = user.email === ADMIN_EMAIL;
  // 「時空旅」タブは、自分の記録と他ユーザーが公開した時空旅（sharedTrips）の
  // 両方を並べる。自分の記録のうち公開中のものは、同じidが`sharedTrips`にも
  // 存在するため、重複して2件表示されないよう自分のID分は`sharedTrips`側から
  // 除外してから合流させる。共有されている（＝自分の公開中の記録、または
  // 他ユーザーの記録）ことは、一覧側で🌐アイコンとして示す。
  const sharedTripIDs = useMemo(() => new Set(sharedTrips.map((trip) => trip.id)), [sharedTrips]);
  const unifiedTrips = useMemo<UnifiedTrip[]>(() => {
    const stampsByTrip = groupByWalkRoute(stamps);
    const photoPostsByTrip = groupByWalkRoute(photoPosts);
    const sharedByID = new Map(sharedTrips.map((trip) => [trip.id, trip]));
    const ownUnified = ownTrips.map((trip) => {
      const unified = fromWalkTrip(trip, stampsByTrip.get(trip.id) ?? [], photoPostsByTrip.get(trip.id) ?? [], sharedTripIDs.has(trip.id));
      // 自分の公開中の旅は、公開データにあるいいね・コメントの件数を使う。
      const shared = sharedByID.get(trip.id);
      return shared ? { ...unified, likeCount: shared.likeCount, commentCount: shared.commentCount } : unified;
    });
    const ownIDs = new Set(ownUnified.map((trip) => trip.id));
    const othersShared = sharedTrips.filter((trip) => !ownIDs.has(trip.id)).map(fromSharedTrip);
    return [...ownUnified, ...othersShared].sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime());
  }, [ownTrips, sharedTrips, sharedTripIDs, stamps, photoPosts]);

  const selectedPlace = places.find((place) => place.id === selectedId) ?? null;
  // 一覧の開閉・旅の選択・共有リンクで開いた旅の個別取得は、公開ページと共通（`useTripBrowser`）。
  const { selectedTripId, selectedTrip, isSidebarOpen, openSidebar, selectTrip, goHome, collapseSidebarOnMobile } =
    useTripBrowser(unifiedTrips);

  const handleSelect = (place: SavedPlace) => {
    setSelectedId(place.id);
  };

  const handleTabChange = (nextTab: SidebarTab) => {
    setTab(nextTab);
    openSidebar();
  };

  // 左上のアイコンを押した時、選んでいた時空旅・地点を解除してホーム（一覧のみの
  // 状態）に戻す。モバイル・PCどちらでも同じ挙動にする。
  const handleGoHome = () => {
    goHome();
    setSelectedId(null);
  };

  return (
    <div className="app-shell">
      <Header
        user={user}
        tripCount={ownTrips.length}
        onSignOut={onSignOut}
        showListButton={!isSidebarOpen}
        onShowList={openSidebar}
        onGoHome={handleGoHome}
      />
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
              <button
                className={`sidebar-tab ${tab === "maps" ? "is-active" : ""}`}
                onClick={() => handleTabChange("maps")}
              >
                古地図
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
              <TripList trips={unifiedTrips} selectedId={selectedTripId} onSelect={selectTrip} />
            )}
            {tab === "maps" && (
              <OldMapList
                selectedId={selectedMap?.id ?? null}
                onSelect={(map) => {
                  setSelectedMap(map);
                  collapseSidebarOnMobile();
                }}
              />
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
          {tab === "places" && (
            <>
              <MapView places={places} selectedId={selectedId} onSelect={handleSelect} />
              <PlaceDetail place={selectedPlace} />
            </>
          )}
          {tab === "trips" && (
            <TripDetail trip={selectedTrip} currentUser={{ uid: user.uid, displayName: user.displayName }} />
          )}
          {tab === "maps" && <OldMapDetail map={selectedMap} />}
          {tab === "admin" && isAdmin && <AdminFunnelReport />}
        </main>
      </div>
    </div>
  );
}
