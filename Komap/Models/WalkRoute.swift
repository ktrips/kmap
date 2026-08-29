import CoreLocation
import Foundation
import SwiftData

/// 「スタート」ボタンで記録した徒歩ルート。
///
/// 歩いた軌跡を地図上にポリラインで描き直せるよう、緯度・経度を
/// 順序を保った配列として保持する。
@Model
final class WalkRoute {
    @Attribute(.unique) var id: UUID
    var latitudes: [Double]
    var longitudes: [Double]
    var startedAt: Date

    init(
        id: UUID = UUID(),
        coordinates: [CLLocationCoordinate2D],
        startedAt: Date = Date()
    ) {
        self.id = id
        self.latitudes = coordinates.map(\.latitude)
        self.longitudes = coordinates.map(\.longitude)
        self.startedAt = startedAt
    }

    var coordinates: [CLLocationCoordinate2D] {
        zip(latitudes, longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
    }
}
