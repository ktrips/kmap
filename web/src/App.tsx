import { useState } from "react";
import { Header } from "./components/Header";
import { MapView } from "./components/MapView";
import { PlaceDetail } from "./components/PlaceDetail";
import { PlaceList } from "./components/PlaceList";
import { SignInScreen } from "./components/SignInScreen";
import { TripDetail } from "./components/TripDetail";
import { TripList } from "./components/TripList";
import { isFirebaseConfigured } from "./lib/firebase";
import { useAuth } from "./lib/useAuth";
import { usePlaces } from "./lib/usePlaces";
import { useWalkRoutes } from "./lib/useWalkRoutes";
import type { SavedPlace } from "./types/place";
import type { WalkTrip } from "./types/walkRoute";

type SidebarTab = "places" | "trips";

export default function App() {
  const { user, isInitializing, isSigningIn, error, signInWithGoogle, signOut } = useAuth();
  const { places } = usePlaces(user?.uid ?? null);
  const { trips } = useWalkRoutes(user?.uid ?? null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);
  const [tab, setTab] = useState<SidebarTab>("trips");

  const selectedPlace = places.find((place) => place.id === selectedId) ?? null;
  const selectedTrip = trips.find((trip) => trip.id === selectedTripId) ?? null;

  const handleSelect = (place: SavedPlace) => {
    setSelectedId(place.id);
  };

  const handleSelectTrip = (trip: WalkTrip) => {
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
          </div>
          {tab === "places" ? (
            <PlaceList places={places} selectedId={selectedId} onSelect={handleSelect} />
          ) : (
            <TripList trips={trips} selectedId={selectedTripId} onSelect={handleSelectTrip} />
          )}
        </aside>
        <main className="app-main">
          {tab === "places" ? (
            <>
              <MapView places={places} selectedId={selectedId} onSelect={handleSelect} />
              <PlaceDetail place={selectedPlace} />
            </>
          ) : (
            <TripDetail trip={selectedTrip} />
          )}
        </main>
      </div>
    </div>
  );
}
