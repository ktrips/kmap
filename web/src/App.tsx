import { useState } from "react";
import { Header } from "./components/Header";
import { MapView } from "./components/MapView";
import { PlaceDetail } from "./components/PlaceDetail";
import { PlaceList } from "./components/PlaceList";
import { SharedTripDetail } from "./components/SharedTripDetail";
import { SharedTripList } from "./components/SharedTripList";
import { SignInScreen } from "./components/SignInScreen";
import { TripDetail } from "./components/TripDetail";
import { TripList } from "./components/TripList";
import { isFirebaseConfigured } from "./lib/firebase";
import { useAuth } from "./lib/useAuth";
import { usePlaces } from "./lib/usePlaces";
import { useSharedTrips } from "./lib/useSharedTrips";
import { useWalkRoutes } from "./lib/useWalkRoutes";
import type { SavedPlace } from "./types/place";
import type { SharedTrip } from "./types/sharedTrip";
import type { WalkTrip } from "./types/walkRoute";

type SidebarTab = "places" | "trips" | "shared";

export default function App() {
  const { user, isInitializing, isSigningIn, error, signInWithGoogle, signOut } = useAuth();
  const { places } = usePlaces(user?.uid ?? null);
  const { trips } = useWalkRoutes(user?.uid ?? null);
  const { trips: sharedTrips } = useSharedTrips(Boolean(user));
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);
  const [selectedSharedTripId, setSelectedSharedTripId] = useState<string | null>(null);
  const [tab, setTab] = useState<SidebarTab>("trips");

  const selectedPlace = places.find((place) => place.id === selectedId) ?? null;
  const selectedTrip = trips.find((trip) => trip.id === selectedTripId) ?? null;
  const selectedSharedTrip = sharedTrips.find((trip) => trip.id === selectedSharedTripId) ?? null;

  const handleSelect = (place: SavedPlace) => {
    setSelectedId(place.id);
  };

  const handleSelectTrip = (trip: WalkTrip) => {
    setSelectedTripId(trip.id);
  };

  const handleSelectSharedTrip = (trip: SharedTrip) => {
    setSelectedSharedTripId(trip.id);
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
      <SignInScreen
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
              My Trips
            </button>
            <button
              className={`sidebar-tab ${tab === "shared" ? "is-active" : ""}`}
              onClick={() => setTab("shared")}
            >
              みんなの時空旅
            </button>
          </div>
          {tab === "places" && <PlaceList places={places} selectedId={selectedId} onSelect={handleSelect} />}
          {tab === "trips" && <TripList trips={trips} selectedId={selectedTripId} onSelect={handleSelectTrip} />}
          {tab === "shared" && (
            <SharedTripList trips={sharedTrips} selectedId={selectedSharedTripId} onSelect={handleSelectSharedTrip} />
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
          {tab === "shared" && <SharedTripDetail trip={selectedSharedTrip} />}
        </main>
      </div>
    </div>
  );
}
