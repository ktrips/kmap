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
    @Published var overlayOpacity: Double = MapSessionState.defaultOverlayOpacity
    @Published var cameraMoveRequest: CameraMoveRequest?
    @Published var selectedTab: AppTab = .map
    /// 「全ての古地図を表示」が選ばれているかどうか。右上のハンバーガーメニュー内の
    /// 「古地図選択」と、マップ下部の`OverlayControlPanel`の両方から操作する。
    @Published var isShowingAllOverlays: Bool = false
    /// 「新しい古地図を登録」の検索シートを表示するかどうか。
    @Published var isShowingOldMapSearch: Bool = false

    private static let defaultOverlayOpacityKey = "defaultOverlayOpacity"
    /// セットアップ画面で変更していない場合の、古地図濃度の初期値。
    private static let fallbackDefaultOverlayOpacity: Double = 0.6

    /// 起動時・「セットアップ」で変更していない限り古地図濃度に使う値。
    /// セットアップ画面の設定を保存・反映するために`UserDefaults`に永続化する。
    static var defaultOverlayOpacity: Double {
        get {
            let stored = UserDefaults.standard.object(forKey: defaultOverlayOpacityKey) as? Double
            return stored ?? fallbackDefaultOverlayOpacity
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultOverlayOpacityKey)
        }
    }

    /// 「セットアップ」画面から呼ぶ。次回以降の起動時に使うデフォルト濃度として保存しつつ、
    /// 今表示中の濃度にもすぐ反映する。
    func updateDefaultOverlayOpacity(_ value: Double) {
        Self.defaultOverlayOpacity = value
        overlayOpacity = value
    }

    func moveCamera(to coordinate: CLLocationCoordinate2D) {
        cameraMoveRequest = CameraMoveRequest(coordinate)
    }

    /// 「My TimeTrip」の記録から、その時の古地図・不透明度・位置を復元してマップタブへ移動する。
    func resume(overlayMapID: String?, overlayOpacity: Double, cameraTarget: CLLocationCoordinate2D?) {
        isShowingAllOverlays = false
        selectedOverlay = OldMapCatalog.resolve(id: overlayMapID)
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
