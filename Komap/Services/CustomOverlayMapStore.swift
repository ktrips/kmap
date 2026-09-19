import CoreLocation
import Foundation
import UIKit

/// ユーザーが「古地図を検索」で見つけて追加した古地図を、端末内にJSONで保存・読み込みする。
///
/// 同梱の`OldMapCatalog`と違いビルド時に固定できないため、`Application Support`配下に
/// 位置合わせ情報を保存し、画像本体は`StampPhotoStore`に保存してファイル名だけを持つ。
enum CustomOverlayMapStore {
    fileprivate struct Record: Codable {
        let id: String
        let title: String
        let era: String
        let summary: String
        let imageFileName: String
        let southWestLat: Double
        let southWestLng: Double
        let northEastLat: Double
        let northEastLng: Double
        /// 画像が見つからずAIが生成したチェックポイント。古い保存データには無いため省略可。
        var checkpoints: [CheckpointRecord]?
    }

    fileprivate struct CheckpointRecord: Codable {
        let name: String
        let summary: String
        let latitude: Double
        let longitude: Double
    }

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomOverlayMaps.json")
    }

    /// ディスクからの読み込み・JSONデコードを毎回行わずに済むよう、一度読んだら
    /// メモリ上に保持しておく。`add`で更新した時だけ作り直す。
    private static var cachedRecords: [Record]?
    /// `records()`から作った`HistoricalOverlayMap`・`HistoricSite`の一覧。`all()`/`sites()`は
    /// 地図の表示・御朱印の照会などから頻繁に呼ばれるため、呼ぶたびに作り直さず、
    /// `add`で内容が変わった時だけ破棄する。
    private static var cachedMaps: [HistoricalOverlayMap]?
    private static var cachedSites: [HistoricSite]?

    /// 保存済みの古地図一覧を読み込む。
    static func all() -> [HistoricalOverlayMap] {
        if let cachedMaps { return cachedMaps }
        let maps = records().map { $0.overlayMap }
        cachedMaps = maps
        return maps
    }

    /// 検索結果を古地図として保存し、追加された`HistoricalOverlayMap`を返す。
    @discardableResult
    static func add(
        title: String,
        era: String,
        summary: String,
        image: UIImage,
        southWest: CLLocationCoordinate2D,
        northEast: CLLocationCoordinate2D,
        checkpoints: [GeneratedCheckpoint] = []
    ) -> HistoricalOverlayMap? {
        guard let imageFileName = StampPhotoStore.save(image) else { return nil }

        let record = Record(
            id: UUID().uuidString,
            title: title,
            era: era,
            summary: summary,
            imageFileName: imageFileName,
            southWestLat: southWest.latitude,
            southWestLng: southWest.longitude,
            northEastLat: northEast.latitude,
            northEastLng: northEast.longitude,
            checkpoints: checkpoints.isEmpty ? nil : checkpoints.map {
                CheckpointRecord(
                    name: $0.name, summary: $0.summary,
                    latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude
                )
            }
        )

        var current = records()
        current.append(record)
        guard let data = try? JSONEncoder().encode(current) else { return nil }
        try? data.write(to: fileURL)
        cachedRecords = current
        cachedMaps = nil
        cachedSites = nil
        OldMapCatalog.invalidateAllIncludingCustomCache()

        return record.overlayMap
    }

    /// 追加した古地図に属する、生成されたチェックポイントの一覧。
    static func sites() -> [HistoricSite] {
        if let cachedSites { return cachedSites }
        let sites = makeSites()
        cachedSites = sites
        return sites
    }

    private static func makeSites() -> [HistoricSite] {
        records().flatMap { record in
            (record.checkpoints ?? []).enumerated().map { index, checkpoint in
                HistoricSite(
                    id: "\(record.id)-cp\(index + 1)",
                    overlayMapID: record.id,
                    name: checkpoint.name,
                    summary: checkpoint.summary,
                    coordinate: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
                )
            }
        }
    }

    private static func records() -> [Record] {
        if let cachedRecords {
            return cachedRecords
        }
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([Record].self, from: data)
        else {
            cachedRecords = []
            return []
        }
        cachedRecords = records
        return records
    }
}

fileprivate extension CustomOverlayMapStore.Record {
    var overlayMap: HistoricalOverlayMap {
        HistoricalOverlayMap(
            id: id,
            title: title,
            era: era,
            summary: summary,
            imageFileName: imageFileName,
            southWest: CLLocationCoordinate2D(latitude: southWestLat, longitude: southWestLng),
            northEast: CLLocationCoordinate2D(latitude: northEastLat, longitude: northEastLng)
        )
    }
}
