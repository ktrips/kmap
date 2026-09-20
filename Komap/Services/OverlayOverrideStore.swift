import CoreLocation
import Foundation
import UIKit

/// アプリに同梱している古地図（`OldMapCatalog`）への、管理者による変更を端末内に保存する。
///
/// 同梱の古地図はビルド時に固定されているため、名前・画像の差し替えと、ポイントの追加・
/// 非表示だけを「上書き」として`Application Support`配下のJSONに持ち、表示する時に
/// 元の内容へ重ねて反映する（元のデータ自体は変えないので、いつでも元に戻せる）。
enum OverlayOverrideStore {
    struct CheckpointRecord: Codable {
        let id: String
        let name: String
        let summary: String
        let latitude: Double
        let longitude: Double
    }

    struct Record: Codable {
        let id: String
        var title: String?
        /// 差し替えた画像（`StampPhotoStore`のファイル名）。
        var imageFileName: String?
        /// 管理者が追加したポイント。
        var extraCheckpoints: [CheckpointRecord]?
        /// 同梱のポイントのうち、管理者が削除（非表示に）したもののID。
        var hiddenSiteIDs: [String]?
    }

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OverlayOverrides.json")
    }

    private static var cached: [String: Record]?

    private static func records() -> [String: Record] {
        if let cached { return cached }
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([Record].self, from: data)
        else {
            cached = [:]
            return [:]
        }
        let map = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        cached = map
        return map
    }

    private static func save(_ map: [String: Record]) {
        cached = map
        if let data = try? JSONEncoder().encode(Array(map.values)) {
            try? data.write(to: fileURL)
        }
        OldMapCatalog.invalidateAllIncludingCustomCache()
        HistoricSiteCatalog.invalidateCache()
    }

    private static func update(_ id: String, _ change: (inout Record) -> Void) {
        var map = records()
        var record = map[id] ?? Record(id: id)
        change(&record)
        map[id] = record
        save(map)
    }

    // MARK: - 反映

    /// 同梱の古地図に、保存済みの上書き（名前・画像）を重ねたものを返す。
    static func apply(to overlay: HistoricalOverlayMap) -> HistoricalOverlayMap {
        guard let record = records()[overlay.id], record.title != nil || record.imageFileName != nil else { return overlay }
        return HistoricalOverlayMap(
            id: overlay.id,
            title: record.title ?? overlay.title,
            era: overlay.era,
            summary: overlay.summary,
            imageAssetName: overlay.imageAssetName,
            imageFileName: record.imageFileName ?? overlay.imageFileName,
            southWest: overlay.southWest,
            northEast: overlay.northEast,
            bearing: overlay.bearing
        )
    }

    /// 管理者が追加したポイント（全古地図分）。
    static func allExtraSites() -> [HistoricSite] {
        records().values.flatMap { record in
            (record.extraCheckpoints ?? []).map {
                HistoricSite(
                    id: $0.id, overlayMapID: record.id, name: $0.name, summary: $0.summary,
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                )
            }
        }
    }

    /// 非表示にした同梱ポイントのID（全古地図分）。
    static func allHiddenSiteIDs() -> Set<String> {
        Set(records().values.flatMap { $0.hiddenSiteIDs ?? [] })
    }

    /// この古地図に、何らかの上書きがあるか。
    static func hasOverride(id: String) -> Bool {
        guard let record = records()[id] else { return false }
        return record.title != nil || record.imageFileName != nil
            || !(record.extraCheckpoints ?? []).isEmpty || !(record.hiddenSiteIDs ?? []).isEmpty
    }

    // MARK: - 編集

    static func setTitle(id: String, _ title: String) {
        update(id) { $0.title = title }
    }

    static func replaceImage(id: String, with image: UIImage) {
        guard let newFileName = StampPhotoStore.save(CustomOverlayMapStore.squareImage(image)) else { return }
        update(id) { record in
            if let old = record.imageFileName { StampPhotoStore.delete(old) }
            record.imageFileName = newFileName
        }
    }

    static func addCheckpoint(
        toOverlayID overlayID: String, name: String, summary: String, coordinate: CLLocationCoordinate2D
    ) {
        update(overlayID) { record in
            let checkpoint = CheckpointRecord(
                id: "\(overlayID)-x-\(UUID().uuidString)", name: name, summary: summary,
                latitude: coordinate.latitude, longitude: coordinate.longitude
            )
            record.extraCheckpoints = (record.extraCheckpoints ?? []) + [checkpoint]
        }
    }

    /// ポイントを削除する。管理者が追加したものは取り除き、同梱のものは非表示にする。
    static func removeCheckpoint(overlayID: String, siteID: String) {
        update(overlayID) { record in
            if record.extraCheckpoints?.contains(where: { $0.id == siteID }) == true {
                record.extraCheckpoints?.removeAll { $0.id == siteID }
            } else {
                record.hiddenSiteIDs = (record.hiddenSiteIDs ?? []) + [siteID]
            }
        }
    }

    /// この古地図への変更をすべて取り消し、同梱の元の内容に戻す。
    static func reset(id: String) {
        var map = records()
        if let old = map[id]?.imageFileName { StampPhotoStore.delete(old) }
        map[id] = nil
        save(map)
    }
}
