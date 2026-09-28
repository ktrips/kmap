import { MERGED_INTO, OLD_MAP_DATA } from "./generated/catalogData";
import type { HistoricSiteEntry } from "./historicSiteCatalog";

/**
 * iOS側の `Komap/Models/HistoricalOverlayMap.swift` と対になる古地図カタログ。
 * Web側では地点・時間旅に紐づく古地図の「タイトル・時代」をラベル表示するほか、
 * 時空旅の地図（`TripMapView`）に古地図の画像を重ねて表示するために使う。
 */
export interface OldMapEntry {
  id: string;
  title: string;
  era: string;
  /** 古地図の紹介文。 */
  summary?: string;
  /** `web/public/old-maps/` 内の画像パス。統合済みで画像を持たない古い古地図IDはundefined。 */
  imageUrl?: string;
  southWest?: { lat: number; lng: number };
  northEast?: { lat: number; lng: number };
  /**
   * 画像の「上」が指す方角（真北から時計回りの度数）。0以外は現状`goshiki-fudo-meiji`のみ。
   * Google Maps JavaScript APIの`GroundOverlay`は回転をサポートしないため、Web版では
   * この値があっても画像は回転させずに表示する（iOS版とは見た目が異なる点に注意）。
   */
  bearing?: number;
  /** 個人が作って公開した古地図（`sharedOverlayMaps`）の作者名。同梱の古地図はundefined。 */
  ownerDisplayName?: string | null;
  /** 個人が作って公開した古地図のチェックポイント。同梱の古地図は`sitesForOverlay`で引く。 */
  checkpoints?: HistoricSiteEntry[];
}

// 古地図の一覧は catalog/old_maps.json から生成した generated/catalogData.ts にある
// （iOSと同じデータ。追加・変更する時は JSON を編集し、node scripts/generate-catalog.mjs を実行する）。
export const OLD_MAP_CATALOG: OldMapEntry[] = OLD_MAP_DATA;

/**
 * 統合済みで現在は選べない古い古地図IDを、統合先の古地図IDへ読み替える表。
 * 過去の時空旅・保存した地点は統合前のIDのまま記録されているため、
 * `findOldMap`で解決する際にここを通して統合先の古地図（タイトル・画像とも）に
 * 差し替える（iOS側の`HistoricalOverlayMap.swift`の統合履歴と対応）。
 */

// 一覧の各行から呼ばれるため、毎回全件を順に探さないよう索引を一度だけ作る。
const OLD_MAP_BY_ID = new Map(OLD_MAP_CATALOG.map((entry) => [entry.id, entry]));

export function findOldMap(id: string | null): OldMapEntry | undefined {
  if (!id) return undefined;
  const resolvedId = MERGED_INTO[id] ?? id;
  return OLD_MAP_BY_ID.get(resolvedId);
}
