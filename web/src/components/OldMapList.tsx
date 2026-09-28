import { useMemo } from "react";
import type { OldMapEntry } from "../lib/oldMapCatalog";
import { sitesForOverlay } from "../lib/historicSiteCatalog";
import { oldMapRegion, REGION_LABEL, REGION_ORDER, VISIBLE_OLD_MAPS } from "../lib/tripRegion";

interface Props {
  selectedId: string | null;
  onSelect: (map: OldMapEntry) => void;
}

/**
 * 古地図の一覧。リージョンごと（Europe → America → Japan → Asia）に分けて並べる
 * （iOSアプリの「みんなの古地図」と同じ順番）。サインインしていなくても見られる。
 */
export function OldMapList({ selectedId, onSelect }: Props) {
  const groups = useMemo(() => {
    return REGION_ORDER.map((region) => ({
      region,
      maps: VISIBLE_OLD_MAPS.filter((map) => oldMapRegion(map) === region),
    })).filter((group) => group.maps.length > 0);
  }, []);

  return (
    <div className="trip-list">
      {groups.map(({ region, maps }) => (
        <section key={region} className="trip-region">
          <h3 className="trip-region-title">
            {REGION_LABEL[region]}（{maps.length}枚）
          </h3>
          <ul className="place-list">
            {maps.map((map) => (
              <li key={map.id}>
                <button
                  className={`place-list-item trip-list-item ${map.id === selectedId ? "is-selected" : ""}`}
                  onClick={() => onSelect(map)}
                >
                  <span className="trip-row-thumbnail">
                    <img src={map.imageUrl} alt="" loading="lazy" />
                  </span>
                  <span className="trip-row-content">
                    <span className="trip-row-title">
                      <span className="trip-row-title-text">{map.title}</span>
                    </span>
                    <span className="trip-row-meta">
                      {map.era} ・ チェックポイント{sitesForOverlay(map.id).length}か所
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}
