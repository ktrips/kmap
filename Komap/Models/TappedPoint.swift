import CoreLocation
import Foundation

/// マップ上でタップ（または「現在地」ボタン）によって選択された地点。
/// `.sheet(item:)` で使うために `Identifiable` にしている。
struct TappedPoint: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: TappedPoint, rhs: TappedPoint) -> Bool {
        lhs.id == rhs.id
    }
}
