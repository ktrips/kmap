import CoreLocation
import Foundation

/// 地図上にチェックポイントとして強調表示する史跡1件分の情報。
///
/// - Important: 座標はこのサンプルアプリ用のおおよその位置です。
///   正確な参拝・観光情報については各史跡の公式情報をご確認ください。
struct HistoricSite: Identifiable, Hashable {
    let id: String
    /// この史跡が属する古地図（`HistoricalOverlayMap.id`）。
    /// 地図タブでは、選択中の古地図と同じIDを持つ史跡だけをチェックポイントとして表示する。
    let overlayMapID: String
    let name: String
    /// 御朱印帳カードに添える一言（時代・由来など）
    let summary: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: HistoricSite, rhs: HistoricSite) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// アプリに同梱している史跡チェックポイントのカタログ。
///
/// 古地図1枚につき5箇所程度、その地図のテーマに沿ったチェックポイントを用意している。
enum HistoricSiteCatalog {
    // 同梱のチェックポイント（`all`）は、`catalog/historic_sites.json`から生成した
    // `Generated/HistoricSiteCatalogData.swift`にある。追加・変更する時はJSONを編集し、
    // `node scripts/generate-catalog.mjs`を実行する。

    /// 同梱のチェックポイントのID・古地図IDによる索引。`site(withID:)`や
    /// `sites(forOverlayID:)`は地図・御朱印一覧・同期などから何度も呼ばれるため、
    /// 毎回全件を走査せず、一度だけ作った索引を引く。
    private static let bundledByID: [String: HistoricSite] = Dictionary(
        all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    /// 表示するチェックポイント全件（同梱 − 管理者が削除したもの + 管理者が追加したもの +
    /// ユーザーが追加した古地図のもの）と、古地図IDごとの索引。呼ぶたびに作り直さないよう
    /// キャッシュし、いずれかのストアが変わった時（`invalidateCache`）だけ破棄する。
    private static var cachedAll: [HistoricSite]?
    private static var cachedByOverlayID: [String: [HistoricSite]]?
    private static var cachedByID: [String: HistoricSite]?
    private static var visibleCache: (region: MapRegion, sites: [HistoricSite])?

    static func invalidateCache() {
        cachedAll = nil
        cachedByOverlayID = nil
        cachedByID = nil
        visibleCache = nil
    }

    /// 同梱のチェックポイント + 管理者による変更 + ユーザーが追加した古地図のチェックポイント。
    static var allIncludingCustom: [HistoricSite] {
        if let cachedAll { return cachedAll }
        // 管理者による追加・非表示は、クラウドで全員に配るもの（`AdminCheckpointCloud`）と、
        // 以前の端末内だけの保存（`OverlayOverrideStore`。管理者がサインインするとクラウドへ移す）の両方を反映する。
        let hidden = OverlayOverrideStore.allHiddenSiteIDs().union(AdminCheckpointCloud.hiddenSiteIDs())
        let bundled = hidden.isEmpty ? all : all.filter { !hidden.contains($0.id) }
        let combined = bundled + AdminCheckpointCloud.extraSites() + OverlayOverrideStore.allExtraSites()
            + CustomOverlayMapStore.sites()
        cachedAll = combined
        cachedByOverlayID = Dictionary(grouping: combined, by: \.overlayMapID)
        cachedByID = Dictionary(combined.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return combined
    }

    /// `allIncludingCustom`から、「設定」で選んでいるリージョンの外にある古地図の
    /// チェックポイントを除いたもの。全地図表示・御朱印一覧に使う。
    static var visibleIncludingCustom: [HistoricSite] {
        let region = AppSettings.mapRegion
        if let visibleCache, visibleCache.region == region {
            return visibleCache.sites
        }
        let visible = allIncludingCustom.filter { !OldMapCatalog.isHiddenBySettings(overlayID: $0.overlayMapID) }
        visibleCache = (region, visible)
        return visible
    }

    /// 同梱のポイントかどうか（削除の仕方が、追加したポイントと異なる）。
    static func isBundledSite(_ id: String) -> Bool {
        bundledByID[id] != nil
    }

    /// 削除（非表示）した同梱ポイントも含めて探す（獲得済みの御朱印から辿れるようにするため）。
    static func site(withID id: String) -> HistoricSite? {
        if let site = bundledByID[id] { return site }
        _ = allIncludingCustom
        return cachedByID?[id]
    }

    /// 指定した古地図に属するチェックポイントだけを返す。
    /// `overlayMapID`が`nil`（古地図を表示していない）場合は空配列を返す。
    static func sites(forOverlayID overlayMapID: String?) -> [HistoricSite] {
        guard let overlayMapID else { return [] }
        _ = allIncludingCustom
        return cachedByOverlayID?[overlayMapID] ?? []
    }
}
