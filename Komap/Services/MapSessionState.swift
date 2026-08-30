import CoreLocation
import Foundation

/// カメラ移動の1回のリクエスト。同じ座標への再移動でも`id`が異なれば
/// 「新しい移動要求」として扱えるようにするためのラッパー。
struct CameraMoveRequest: Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D

    init(_ coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.coordinate = coordinate
    }

    static func == (lhs: CameraMoveRequest, rhs: CameraMoveRequest) -> Bool {
        lhs.id == rhs.id
    }
}

/// マップ画面（古地図の選択・不透明度・カメラ位置）とタブ選択を、
/// 「My TimeTrip」など他タブと共有するための状態。
///
/// 「My TimeTrip」から過去のウォーキングを「再スタート」した時、
/// その時に使っていた古地図・不透明度を復元してマップタブへ切り替えるために使う。
@MainActor
final class MapSessionState: ObservableObject {
    @Published var selectedOverlay: HistoricalOverlayMap? = OldMapCatalog.edoCastle
    @Published var overlayOpacity: Double = 0.55
    @Published var cameraMoveRequest: CameraMoveRequest?
    @Published var selectedTab: AppTab = .map

    func moveCamera(to coordinate: CLLocationCoordinate2D) {
        cameraMoveRequest = CameraMoveRequest(coordinate)
    }

    /// 「My TimeTrip」の記録から、その時の古地図・不透明度・位置を復元してマップタブへ移動する。
    func resume(overlayMapID: String?, overlayOpacity: Double, cameraTarget: CLLocationCoordinate2D?) {
        selectedOverlay = overlayMapID.flatMap { id in OldMapCatalog.all.first { $0.id == id } }
        self.overlayOpacity = overlayOpacity
        if let cameraTarget {
            moveCamera(to: cameraTarget)
        }
        selectedTab = .map
    }
}

enum AppTab: Hashable {
    case map
    case myTimeTrip
    case settings
}
