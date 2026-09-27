import { sitesForOverlay } from "../lib/historicSiteCatalog";
import type { OldMapEntry } from "../lib/oldMapCatalog";
import { oldMapRegion, REGION_LABEL } from "../lib/tripRegion";
import { TripMapView } from "./TripMapView";

interface Props {
  map: OldMapEntry | null;
}

/** 古地図1枚の詳細。今の地図に重ねた表示・古地図の画像・チェックポイントの一覧を見せる。 */
export function OldMapDetail({ map }: Props) {
  if (!map || !map.southWest || !map.northEast) {
    return (
      <div className="trip-detail place-detail-empty">
        <p>リストから、古地図を選んでください。</p>
      </div>
    );
  }
  const checkpoints = sitesForOverlay(map.id);
  const center = {
    lat: (map.southWest.lat + map.northEast.lat) / 2,
    lng: (map.southWest.lng + map.northEast.lng) / 2,
  };

  return (
    <div className="trip-detail">
      <div className="trip-header-info">
        <div className="trip-title-row">
          <h2>{map.title}</h2>
        </div>
        <p className="trip-meta-row">
          <span>🌍 {REGION_LABEL[oldMapRegion(map)]}</span>
          <span>🕰 {map.era}</span>
          <span>📍 チェックポイント{checkpoints.length}か所</span>
        </p>
      </div>

      {/* 今の地図に古地図を重ねて表示（チェックポイントも） */}
      <TripMapView
        key={map.id}
        latitudes={[center.lat]}
        longitudes={[center.lng]}
        oldMap={map}
        checkpoints={checkpoints}
      />

      <div className="trip-journal-gallery">
        <p className="trip-journal-gallery-title">チェックポイント</p>
        <ol className="old-map-checkpoints">
          {checkpoints.map((site) => (
            <li key={site.id}>{site.name}</li>
          ))}
        </ol>
      </div>

      <div className="trip-journal-gallery">
        <p className="trip-journal-gallery-title">古地図</p>
        <img className="old-map-full-image" src={map.imageUrl} alt={map.title} loading="lazy" />
        <p className="muted old-map-note">
          iOSアプリ「Komap」で、この古地図を今の地図に重ねて歩き、チェックポイントで御朱印を集められます。
        </p>
      </div>
    </div>
  );
}
