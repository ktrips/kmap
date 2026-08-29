import CoreLocation
import Foundation

/// 現在地の取得と権限リクエストを担当する。
///
/// `GMSMapView` の `isMyLocationEnabled` は現在地の「青い点」表示だけを行うため、
/// アプリ側で現在地座標そのものが必要な場面（現在地の物語を見る、カメラを
/// 現在地に移動する等）のためにこのクラスを用意している。
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    /// 「スタート」ボタンでの記録中かどうか。
    @Published private(set) var isRecordingWalk = false
    /// 記録中に蓄積されている歩行ルート（表示・保存用）。
    @Published private(set) var walkPath: [CLLocationCoordinate2D] = []

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // 徒歩ルート記録で細かすぎる点を拾いすぎないよう、5m未満の移動は無視する。
        manager.distanceFilter = 5
    }

    func requestPermissionIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    /// 徒歩ルートの記録を開始する。現在地が分かっていればその点から軌跡を始める。
    func startRecordingWalk() {
        walkPath = currentLocation.map { [$0] } ?? []
        isRecordingWalk = true
        manager.startUpdatingLocation()
    }

    /// 記録を終了し、それまでに蓄積した軌跡を返す。
    @discardableResult
    func stopRecordingWalk() -> [CLLocationCoordinate2D] {
        isRecordingWalk = false
        let path = walkPath
        walkPath = []
        return path
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.currentLocation = coordinate
            if self.isRecordingWalk {
                self.walkPath.append(coordinate)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 取得失敗時は静かに無視する（ユーザーはマップを手動操作できる）。
    }
}
