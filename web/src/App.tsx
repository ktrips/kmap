import { useState } from "react";
import { Header } from "./components/Header";
import { MapView } from "./components/MapView";
import { PlaceDetail } from "./components/PlaceDetail";
import { PlaceList } from "./components/PlaceList";
import { SignInScreen } from "./components/SignInScreen";
import { isFirebaseConfigured } from "./lib/firebase";
import { useAuth } from "./lib/useAuth";
import { usePlaces } from "./lib/usePlaces";
import type { SavedPlace } from "./types/place";

export default function App() {
  const {
    user,
    isInitializing,
    isSigningIn,
    error,
    signInWithApple,
    signInWithGoogle,
    signOut,
  } = useAuth();
  const { places } = usePlaces(user?.uid ?? null);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const selectedPlace = places.find((place) => place.id === selectedId) ?? null;

  const handleSelect = (place: SavedPlace) => {
    setSelectedId(place.id);
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
        onSignInWithApple={signInWithApple}
        onSignInWithGoogle={signInWithGoogle}
      />
    );
  }

  return (
    <div className="app-shell">
      <Header user={user} placeCount={places.length} onSignOut={signOut} />
      <div className="app-body">
        <aside className="app-sidebar">
          <PlaceList places={places} selectedId={selectedId} onSelect={handleSelect} />
        </aside>
        <main className="app-main">
          <MapView places={places} selectedId={selectedId} onSelect={handleSelect} />
          <PlaceDetail place={selectedPlace} />
        </main>
      </div>
    </div>
  );
}
