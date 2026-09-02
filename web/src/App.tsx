import { useMemo, useState } from "react";
import { Header } from "./components/Header";
import { MapView } from "./components/MapView";
import { PlaceDetail } from "./components/PlaceDetail";
import { PlaceList } from "./components/PlaceList";
import { PublicSharedTripsView } from "./components/PublicSharedTripsView";
import { TripDetail } from "./components/TripDetail";
import { TripList } from "./components/TripList";
import { isFirebaseConfigured } from "./lib/firebase";
import { useAuth } from "./lib/useAuth";
import { usePhotoPosts } from "./lib/usePhotoPosts";
import { usePlaces } from "./lib/usePlaces";
import { useSharedTrips } from "./lib/useSharedTrips";
import { useStamps } from "./lib/useStamps";
import { useWalkRoutes } from "./lib/useWalkRoutes";
import { fromSharedTrip, fromWalkTrip, type UnifiedTrip } from "./types/unifiedTrip";
import type { SavedPlace } from "./types/place";

type SidebarTab = "places" | "trips";

export default function App() {
  const { user, isInitializing, isSigningIn, error, signInWithGoogle, signOut } = useAuth();
  const { places } = usePlaces(user?.uid ?? null);
  const { trips: ownTrips } = useWalkRoutes(user?.uid ?? null);
  const { trips: sharedTrips } = useSharedTrips();
  const { stamps } = useStamps(user?.uid ?? null);
  const { photoPosts } = usePhotoPosts(user?.uid ?? null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);
  const [tab, setTab] = useState<SidebarTab>("trips");

  // 自分の時空旅を優先し、同じidが「みんなの時空旅」側にも重複していれば除く
  // （自分が公開した時空旅は、自分のリストにだけ実際の御朱印数・写真つきで出す）。
  const unifiedTrips = useMemo<UnifiedTrip[]>(() => {
    const own = ownTrips.map((trip) => fromWalkTrip(trip, stamps, photoPosts));
    const ownIDs = new Set(own.map((trip) => trip.id));
    const shared = sharedTrips.filter((trip) => !ownIDs.has(trip.id)).map(fromSharedTrip);
    return [...own, ...shared].sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime());
  }, [ownTrips, sharedTrips, stamps, photoPosts]);

  const selectedPlace = places.find((place) => place.id === selectedId) ?? null;
  const selectedTrip = unifiedTrips.find((trip) => trip.id === selectedTripId) ?? null;

  const handleSelect = (place: SavedPlace) => {
    setSelectedId(place.id);
  };

  const handleSelectTrip = (trip: UnifiedTrip) => {
    setSelectedTripId(trip.id);
  };

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
    <div className="app-shell">
      <Header user={user} placeCount={places.length} onSignOut={signOut} />
      <div className="app-body">
        <aside className="app-sidebar">
          <div className="sidebar-tabs">
            <button
              className={`sidebar-tab ${tab === "places" ? "is-active" : ""}`}
              onClick={() => setTab("places")}
            >
              保存した物語
            </button>
            <button
              className={`sidebar-tab ${tab === "trips" ? "is-active" : ""}`}
              onClick={() => setTab("trips")}
            >
              時空旅
            </button>
          </div>
          {tab === "places" && <PlaceList places={places} selectedId={selectedId} onSelect={handleSelect} />}
          {tab === "trips" && (
            <TripList trips={unifiedTrips} selectedId={selectedTripId} onSelect={handleSelectTrip} />
          )}
        </aside>
        <main className="app-main">
          {tab === "places" && (
            <>
              <MapView places={places} selectedId={selectedId} onSelect={handleSelect} />
              <PlaceDetail place={selectedPlace} />
            </>
          )}
          {tab === "trips" && <TripDetail trip={selectedTrip} />}
        </main>
      </div>
    </div>
  );
}
