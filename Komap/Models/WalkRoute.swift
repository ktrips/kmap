import CoreLocation
import Foundation
import SwiftData

/// 「スタート」ボタンで記録した徒歩ルート。
///
/// 歩いた軌跡を地図上にポリラインで描き直せるよう、緯度・経度を
/// 順序を保った配列として保持する。記録開始時に選んでいた古地図と
/// その不透明度も保持し、「わたしの時間旅行」から同じ表示で再開できるようにする。
@Model
final class WalkRoute {
    @Attribute(.unique) var id: UUID
    var latitudes: [Double]
    var longitudes: [Double]
    var startedAt: Date
    /// 記録開始時に選んでいた古地図（`HistoricalOverlayMap.id`）。未選択なら nil。
    var overlayMapID: String?
    /// 記録開始時の古地図の不透明度（0...1）。
    var overlayOpacity: Double

    init(
        id: UUID = UUID(),
        coordinates: [CLLocationCoordinate2D],
        startedAt: Date = Date(),
        overlayMapID: String? = nil,
        overlayOpacity: Double = 0.55
    ) {
        self.id = id
        self.latitudes = coordinates.map(\.latitude)
        self.longitudes = coordinates.map(\.longitude)
        self.startedAt = startedAt
        self.overlayMapID = overlayMapID
        self.overlayOpacity = overlayOpacity
    }

    var coordinates: [CLLocationCoordinate2D] {
        zip(latitudes, longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
    }

    var overlayMap: HistoricalOverlayMap? {
        overlayMapID.flatMap { id in OldMapCatalog.all.first { $0.id == id } }
    }

    /// 記録した軌跡のおおよその総距離（メートル）。
    var totalDistanceMeters: CLLocationDistance {
        let points = coordinates
        guard points.count >= 2 else { return 0 }
        var total: CLLocationDistance = 0
        for i in 1..<points.count {
            let a = CLLocation(latitude: points[i - 1].latitude, longitude: points[i - 1].longitude)
            let b = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            total += a.distance(from: b)
        }
        return total
    }
}
