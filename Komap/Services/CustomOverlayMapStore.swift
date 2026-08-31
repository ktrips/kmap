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
    }

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomOverlayMaps.json")
    }

    /// 保存済みの古地図一覧を読み込む。
    static func all() -> [HistoricalOverlayMap] {
        records().map { $0.overlayMap }
    }

    /// 検索結果を古地図として保存し、追加された`HistoricalOverlayMap`を返す。
    @discardableResult
    static func add(
        title: String,
        era: String,
        summary: String,
        image: UIImage,
        southWest: CLLocationCoordinate2D,
        northEast: CLLocationCoordinate2D
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
            northEastLng: northEast.longitude
        )

        var current = records()
        current.append(record)
        guard let data = try? JSONEncoder().encode(current) else { return nil }
        try? data.write(to: fileURL)

        return record.overlayMap
    }

    private static func records() -> [Record] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }
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
