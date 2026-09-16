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
    /// 進行方向（true northから時計回りの度数、0..<360）。GPSが有効な進行方向を
    /// 算出できていない間（静止中・信号が弱い時など）は`nil`。地図上の現在地マークに
    /// 添える小さな矢印（進んでいる方向）の表示に使う。
    @Published private(set) var currentCourse: CLLocationDirection?
    /// 現在地が更新されるたびに増える値。`CLLocationCoordinate2D`は`Equatable`ではないため、
    /// `.onChange`で現在地の更新（＝カメラ追従のタイミング）を検知するためのカウンタとして使う。
    @Published private(set) var locationUpdateTick = 0
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    /// 「スタート」ボタンでの記録中かどうか。
    @Published private(set) var isRecordingWalk = false
    /// 記録中に「一時停止」されているかどうか。記録中のみ意味を持つ。
    @Published private(set) var isWalkPaused = false
    /// 記録中に蓄積されている歩行ルート（表示・保存用）。
    @Published private(set) var walkPath: [CLLocationCoordinate2D] = []
    /// 動きがない時間が`stationaryAutoPauseInterval`を超え、自動的に一時停止した瞬間だけ
    /// `true`になる（UIで確認を出す合図）。`acknowledgeAutoPauseNotice()`で戻す。
    @Published private(set) var didAutoPauseForInactivity = false
    /// 記録開始から`maximumRecordingDuration`を超え、自動的に終了すべきタイミングで
    /// `true`になる（実際の保存・終了はMapScreen側が`stopWalkRecording`で行う）。
    @Published private(set) var didExceedMaximumDuration = false

    /// Apple Watchなどで気づかず記録が回りっぱなしになる不具合への保険として、
    /// 動いているかどうかによらずこの時間を超えたら自動的に記録を終了する。
    static let maximumRecordingDuration: TimeInterval = 8 * 3600
    /// この時間、`movementResetThresholdMeters`以上の移動が無ければ自動的に一時停止する
    /// （信号待ち・カフェで一休み等ではなく、その場に留まったまま気づかず記録し続ける
    /// ことを防ぐため）。「設定」の「動きがない時に自動で一時停止」がオフの間は働かない。
    private static let stationaryAutoPauseInterval: TimeInterval = 20 * 60
    /// GPSのわずかなブレを「移動した」と誤検知しないための最小移動距離（メートル）。
    private static let movementResetThresholdMeters: CLLocationDistance = 15

    /// 動きがない時に自動で一時停止する機能を使うかどうか。「設定」から切り替える
    /// （`MapScreen`が`AppSettings.autoPauseWhenStationary`を反映する）。
    var isAutoPauseForInactivityEnabled = true

    private var recordingStartedAt: Date?
    /// 最後に大きく（`movementResetThresholdMeters`以上）移動した時刻・座標。
    private var lastMovementAt: Date?
    private var lastMovementCoordinate: CLLocationCoordinate2D?
    /// 今の一時停止が、動きがないことによる自動一時停止かどうか。手動の一時停止では
    /// `false`のままにし、動きが戻っても自動再開の対象にしない。
    private var isPausedAutomatically = false

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // 記録していない間（地図を眺めているだけ、現在地ボタンを使うだけ等）は、
        // GPSチップを常に最高精度で回し続けるとバッテリー消費が大きいため、
        // 徒歩ルート記録中だけ`kCLLocationAccuracyBest`へ上げる
        // （`startRecordingWalk`/`stopRecordingWalk`参照）。
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // 徒歩ルート記録で細かすぎる点を拾いすぎないよう、5m未満の移動は無視する。
        manager.distanceFilter = 5
        // `.fitness`は屋内運動（トレッドミル等）向けの間引きが働き、屋外歩行中でも
        // GPS更新が実際に長時間止まってしまうことがあった（歩行中に古地図の「めくれ」
        // 演出・貼り直し健全化がGPS更新頼みのため、更新が止まると古地図が消えたまま
        // 戻らなくなる不具合の原因になっていた）。バッテリー節約よりも記録の途切れなさを
        // 優先し、既定の`.other`のままにしておく。
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
        isWalkPaused = false
        resetInactivityAndDurationTracking(startedAt: Date())
        // 徒歩の軌跡描画には`kCLLocationAccuracyBest`ほどの精度は不要なため、
        // 一段階落とした`kCLLocationAccuracyNearestTenMeters`でバッテリー消費を抑える。
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        enableBackgroundUpdates()
        manager.startUpdatingLocation()
    }

    /// クラッシュ・強制終了から復帰した際、一時保存しておいた軌跡（`coordinates`）に
    /// 続けて記録を再開する。`startRecordingWalk`と違い、軌跡を空にせず引き継ぐ。
    /// `startedAt`（元の記録開始日時）を引き継ぐことで、最長記録時間の判定も
    /// 再開前からの経過時間で正しく行われるようにする。
    func resumeRecordingWalk(from coordinates: [CLLocationCoordinate2D], startedAt: Date = Date()) {
        walkPath = coordinates
        isRecordingWalk = true
        isWalkPaused = false
        resetInactivityAndDurationTracking(startedAt: startedAt)
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        enableBackgroundUpdates()
        manager.startUpdatingLocation()
    }

    private func resetInactivityAndDurationTracking(startedAt: Date) {
        recordingStartedAt = startedAt
        lastMovementAt = Date()
        lastMovementCoordinate = currentLocation
        isPausedAutomatically = false
        didAutoPauseForInactivity = false
        didExceedMaximumDuration = false
    }

    /// 自動一時停止の確認を見せ終えたら呼ぶ（次の自動一時停止でまた合図できるようにする）。
    func acknowledgeAutoPauseNotice() {
        didAutoPauseForInactivity = false
    }

    /// 記録中は、画面をロックしたりアプリがバックグラウンドに回っても位置情報の
    /// 取得を続けられるようにする。「常に許可」でなければ実際には継続しないため、
    /// まだ「使用中のみ許可」の場合はここでアップグレードを促す
    /// （Appleのガイドラインに沿い、必要になった瞬間だけ聞く）。
    private func enableBackgroundUpdates() {
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
        manager.allowsBackgroundLocationUpdates = true
        // 徒歩の記録中に立ち止まっても（写真撮影・信号待ち等）iOSが自動で
        // 位置情報取得を止めてしまわないよう、記録中はオフにする。
        manager.pausesLocationUpdatesAutomatically = false
    }

    /// 記録していない間はバックグラウンド更新を止め、余計なバッテリー消費を防ぐ。
    private func disableBackgroundUpdates() {
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }

    /// 記録を一時停止する。位置情報の取得自体は続けるが、軌跡への追記を止める。
    func pauseRecordingWalk() {
        guard isRecordingWalk else { return }
        isWalkPaused = true
        isPausedAutomatically = false
    }

    /// 一時停止していた記録を再開する。
    func resumeRecordingWalk() {
        guard isRecordingWalk else { return }
        isWalkPaused = false
        isPausedAutomatically = false
        lastMovementAt = Date()
        lastMovementCoordinate = currentLocation
    }

    /// 記録を終了し、それまでに蓄積した軌跡を返す。
    @discardableResult
    func stopRecordingWalk() -> [CLLocationCoordinate2D] {
        isRecordingWalk = false
        isWalkPaused = false
        isPausedAutomatically = false
        recordingStartedAt = nil
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        disableBackgroundUpdates()
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
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        // `course`は進行方向を算出できていない時（静止中・GPS信号が弱い時など）は
        // 負の値になるため、その間は矢印を出さないよう`nil`にしておく。
        let course = location.course >= 0 ? location.course : nil
        Task { @MainActor in
            self.currentLocation = coordinate
            self.currentCourse = course
            self.locationUpdateTick += 1
            self.handleRecordingUpdate(at: coordinate)
        }
    }

    /// 記録中のGPS更新1回分を、最長記録時間・動きがない時の自動一時停止／自動再開に
    /// 反映する。Apple Watchなどでバックグラウンドのまま気づかず記録し続ける不具合への
    /// 保険（`maximumRecordingDuration`）と、その場に留まったまま無駄に記録し続けるのを
    /// 防ぐ仕組み（`stationaryAutoPauseInterval`）を両方ここでチェックする。
    private func handleRecordingUpdate(at coordinate: CLLocationCoordinate2D) {
        guard isRecordingWalk else { return }

        if let recordingStartedAt, Date().timeIntervalSince(recordingStartedAt) >= Self.maximumRecordingDuration {
            didExceedMaximumDuration = true
            return
        }

        let hasMovedSignificantly: Bool = {
            guard let lastMovementCoordinate else { return true }
            let from = CLLocation(latitude: lastMovementCoordinate.latitude, longitude: lastMovementCoordinate.longitude)
            let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return from.distance(from: to) >= Self.movementResetThresholdMeters
        }()

        if isWalkPaused {
            // 自動一時停止中だけ、動きが戻れば自動的に記録を再開する（手動の一時停止はそのまま）。
            guard isPausedAutomatically, isAutoPauseForInactivityEnabled, hasMovedSignificantly else { return }
            isWalkPaused = false
            isPausedAutomatically = false
            lastMovementAt = Date()
            lastMovementCoordinate = coordinate
            walkPath.append(coordinate)
            return
        }

        walkPath.append(coordinate)

        if hasMovedSignificantly {
            lastMovementAt = Date()
            lastMovementCoordinate = coordinate
        } else if isAutoPauseForInactivityEnabled,
                  let lastMovementAt,
                  Date().timeIntervalSince(lastMovementAt) >= Self.stationaryAutoPauseInterval {
            isWalkPaused = true
            isPausedAutomatically = true
            didAutoPauseForInactivity = true
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 取得失敗時は静かに無視する（ユーザーはマップを手動操作できる）。
    }
}
