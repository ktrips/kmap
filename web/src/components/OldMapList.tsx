import { useMemo } from "react";
import type { OldMapEntry } from "../lib/oldMapCatalog";
import { sitesForOverlay, useHistoricSiteCatalogVersion } from "../lib/historicSiteCatalog";
import { oldMapRegion, REGION_LABEL, REGION_ORDER, VISIBLE_OLD_MAPS } from "../lib/tripRegion";

interface Props {
  selectedId: string | null;
  onSelect: (map: OldMapEntry) => void;
  /** 個人が作って公開した古地図（`useSharedOverlayMaps`）。一覧の最後に「みんなの古地図」として並べる。 */
  sharedMaps?: OldMapEntry[];
}

/** 一覧の古地図の数（同梱の古地図＋個人が公開した古地図）。タブの「古地図（◯枚）」に使う。 */
export function oldMapCount(sharedMaps: OldMapEntry[]): number {
  return VISIBLE_OLD_MAPS.length + sharedMaps.length;
}

/**
 * 古地図の一覧。リージョンごと（Europe → America → Japan → Asia）に分けて並べる
 * （iOSアプリの「みんなの古地図」と同じ順番）。個人が作って公開した古地図は、その後に
 * 「みんなの古地図」としてまとめる。サインインしていなくても見られる。
 */
export function OldMapList({ selectedId, onSelect, sharedMaps = [] }: Props) {
  // 管理者が追加したチェックポイントを読み込んだら、件数を描き直す。
  useHistoricSiteCatalogVersion();
  const groups = useMemo(() => {
    return REGION_ORDER.map((region) => ({
      key: region,
      title: REGION_LABEL[region],
      maps: VISIBLE_OLD_MAPS.filter((map) => oldMapRegion(map) === region),
    })).filter((group) => group.maps.length > 0);
  }, []);
  const allGroups =
    sharedMaps.length > 0 ? [...groups, { key: "shared", title: "みんなの古地図", maps: sharedMaps }] : groups;

  return (
    <div className="trip-list">
      {allGroups.map(({ key, title, maps }) => (
        <section key={key} className="trip-region">
          <h3 className="trip-region-title">
            {title}（{maps.length}枚）
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
                      {[
                        map.era,
                        `チェックポイント${(map.checkpoints ?? sitesForOverlay(map.id)).length}か所`,
                        map.ownerDisplayName,
                      ]
                        .filter(Boolean)
                        .join(" ・ ")}
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
