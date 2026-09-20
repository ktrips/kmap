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
        var title: String
        let era: String
        let summary: String
        var imageFileName: String
        let southWestLat: Double
        let southWestLng: Double
        let northEastLat: Double
        let northEastLng: Double
        /// 画像が見つからずAIが生成したチェックポイント。古い保存データには無いため省略可。
        var checkpoints: [CheckpointRecord]?
        /// 公開範囲。`true`なら公開、`nil`・`false`なら自分だけ（古い保存データには無い）。
        var isPublic: Bool?
    }

    fileprivate struct CheckpointRecord: Codable {
        /// チェックポイントのID。削除しても他のIDがずれないよう固定で持つ。
        /// 古い保存データには無いため省略可（その場合は`legacyID`で並び順から決まる）。
        var id: String?
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

    /// `GMSGroundOverlay`は1024×1024px以外の画像だと描画されないことがある
    /// （`HistoricalOverlayMap.imageAssetName`の注意書き参照）ため、保存前に1024×1024の
    /// 正方形へ描き直す。オーバーレイは元々位置合わせの範囲いっぱいに引き伸ばして
    /// 貼られるので、見た目は変わらない。大きな画像の読み込み・デコードも軽くなる。
    static func squareImage(_ image: UIImage) -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
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
        guard let imageFileName = StampPhotoStore.save(squareImage(image)) else { return nil }

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
        guard save(current) else { return nil }

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
                    id: checkpoint.id ?? legacySiteID(overlayID: record.id, index: index),
                    overlayMapID: record.id,
                    name: checkpoint.name,
                    summary: checkpoint.summary,
                    coordinate: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
                )
            }
        }
    }

    private static func legacySiteID(overlayID: String, index: Int) -> String {
        "\(overlayID)-cp\(index + 1)"
    }

    // MARK: - 編集（ポイントの追加・削除、古地図の削除）

    /// 追加した古地図にポイントを1つ加え、その`HistoricSite`を返す。
    @discardableResult
    static func addCheckpoint(
        toOverlayID overlayID: String,
        name: String,
        summary: String,
        coordinate: CLLocationCoordinate2D
    ) -> HistoricSite? {
        var current = migratedRecords()
        guard let index = current.firstIndex(where: { $0.id == overlayID }) else { return nil }
        let checkpoint = CheckpointRecord(
            id: "\(overlayID)-cp-\(UUID().uuidString)",
            name: name, summary: summary,
            latitude: coordinate.latitude, longitude: coordinate.longitude
        )
        current[index].checkpoints = (current[index].checkpoints ?? []) + [checkpoint]
        guard save(current) else { return nil }
        return HistoricSite(
            id: checkpoint.id!, overlayMapID: overlayID, name: name, summary: summary, coordinate: coordinate
        )
    }

    /// 追加した古地図の名前を変える。
    static func rename(id: String, to title: String) {
        var current = records()
        guard let index = current.firstIndex(where: { $0.id == id }) else { return }
        current[index].title = title
        save(current)
    }

    /// 追加した古地図の公開範囲を切り替える。
    static func setPublic(id: String, _ isPublic: Bool) {
        var current = records()
        guard let index = current.firstIndex(where: { $0.id == id }) else { return }
        current[index].isPublic = isPublic
        save(current)
    }

    static func isPublic(id: String) -> Bool {
        records().first { $0.id == id }?.isPublic ?? false
    }

    /// 追加した古地図の画像を差し替える（古い画像ファイルは、新しいものが保存できてから削除する）。
    /// 画像ファイル名が変わるので、表示側のキャッシュも自然に作り直される。
    static func replaceImage(id: String, with image: UIImage) {
        var current = records()
        guard let index = current.firstIndex(where: { $0.id == id }),
              let newFileName = StampPhotoStore.save(squareImage(image))
        else { return }
        StampPhotoStore.delete(current[index].imageFileName)
        current[index].imageFileName = newFileName
        save(current)
    }

    /// 追加した古地図のポイントを1つ削除する。
    static func deleteCheckpoint(siteID: String) {
        var current = migratedRecords()
        for index in current.indices {
            current[index].checkpoints?.removeAll { $0.id == siteID }
        }
        save(current)
    }

    /// 追加した古地図を、ポイントと画像ファイルごと削除する。
    static func deleteOverlay(id: String) {
        var current = records()
        guard let removed = current.first(where: { $0.id == id }) else { return }
        current.removeAll { $0.id == id }
        StampPhotoStore.delete(removed.imageFileName)
        save(current)
    }

    /// ID未設定の古いポイントに、現在の並び順から決まるIDを固定で付けた一覧。
    /// 削除で並びが変わってもIDがずれないよう、変更を加える前に必ず通す。
    private static func migratedRecords() -> [Record] {
        var current = records()
        for recordIndex in current.indices {
            guard var checkpoints = current[recordIndex].checkpoints else { continue }
            for index in checkpoints.indices where checkpoints[index].id == nil {
                checkpoints[index].id = legacySiteID(overlayID: current[recordIndex].id, index: index)
            }
            current[recordIndex].checkpoints = checkpoints
        }
        return current
    }

    @discardableResult
    private static func save(_ current: [Record]) -> Bool {
        guard let data = try? JSONEncoder().encode(current) else { return false }
        try? data.write(to: fileURL)
        cachedRecords = current
        cachedMaps = nil
        cachedSites = nil
        OldMapCatalog.invalidateAllIncludingCustomCache()
        HistoricSiteCatalog.invalidateCache()
        return true
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
