import type { SavedPlace } from "../types/place";

interface Props {
  places: SavedPlace[];
  selectedId: string | null;
  onSelect: (place: SavedPlace) => void;
}

const dateFormatter = new Intl.DateTimeFormat("ja-JP", {
  dateStyle: "medium",
  timeStyle: "short",
});

export function PlaceList({ places, selectedId, onSelect }: Props) {
  if (places.length === 0) {
    return (
      <div className="place-list-empty">
        <p>まだ記録がありません。</p>
        <p className="muted">iOSアプリのマップで地点を保存すると、ここに表示されます。</p>
      </div>
    );
  }

  return (
    <ul className="place-list">
      {places.map((place) => (
        <li key={place.id}>
          <button
            className={`place-list-item ${place.id === selectedId ? "is-selected" : ""}`}
            onClick={() => onSelect(place)}
          >
            <span className="place-title">{place.title}</span>
            <span className="place-era">{place.era}</span>
            <span className="place-story-preview">{place.storyText}</span>
            <span className="place-date">{dateFormatter.format(place.createdAt)}</span>
          </button>
        </li>
      ))}
    </ul>
  );
}
