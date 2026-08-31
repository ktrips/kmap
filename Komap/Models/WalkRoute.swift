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
    /// 記録を終えた日時。歩いた時間の算出に使う。
    /// この項目を追加する前に保存された記録には値が無いため`nil`もあり得る。
    var endedAt: Date?
    /// 記録中の歩数（`CMPedometer`で計測）。取得できなかった場合は`nil`。
    var stepCount: Int?
    /// 記録開始時に選んでいた古地図（`HistoricalOverlayMap.id`）。未選択なら nil。
    var overlayMapID: String?
    /// 記録開始時の古地図の不透明度（0...1）。
    var overlayOpacity: Double
    /// ユーザーが後から付けられる、この時間旅の名前。未設定なら`nil`。
    var title: String?

    init(
        id: UUID = UUID(),
        coordinates: [CLLocationCoordinate2D],
        startedAt: Date = Date(),
        endedAt: Date? = Date(),
        stepCount: Int? = nil,
        overlayMapID: String? = nil,
        overlayOpacity: Double = 0.55,
        title: String? = nil
    ) {
        self.id = id
        self.latitudes = coordinates.map(\.latitude)
        self.longitudes = coordinates.map(\.longitude)
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.stepCount = stepCount
        self.overlayMapID = overlayMapID
        self.overlayOpacity = overlayOpacity
        self.title = title
    }

    /// 歩いた時間（秒）。`endedAt`が無い（この項目を追加する前の）記録では`nil`。
    var durationSeconds: TimeInterval? {
        guard let endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(startedAt))
    }

    var coordinates: [CLLocationCoordinate2D] {
        zip(latitudes, longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
    }

    var overlayMap: HistoricalOverlayMap? {
        overlayMapID.flatMap { id in OldMapCatalog.allIncludingCustom.first { $0.id == id } }
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
