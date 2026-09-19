import CoreLocation
import CoreMotion
import Foundation
import HealthKit

/// Watch単体でウォーキングのGPS軌跡を記録するトラッカー。
///
/// `HKWorkoutSession`を使ってワークアウトとして扱うことで、Watch画面が
/// 暗くなったりアプリがバックグラウンドに回っても、iPhone側のアプリを
/// 起動していなくてもGPSの取得を継続できるようにする。
@MainActor
final class WatchWorkoutLocationTracker: NSObject, ObservableObject {
    @Published private(set) var path: [CLLocationCoordinate2D] = []
    @Published private(set) var isTracking = false
    /// 現在地が更新される度に呼ばれる。iPhoneへ転送し、御朱印チェックポイントの判定に使う。
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    /// 動きがない時間が続き、自動的に記録を一時停止した時に呼ばれる。
    var onAutoPausedForInactivity: (() -> Void)?
    /// 記録開始からの最長時間を超え、自動的に記録を終了すべき時に呼ばれる
    /// （iPhoneを開いていないまま気づかずGPSが回りっぱなしになる不具合への保険）。
    var onMaxDurationExceeded: (() -> Void)?
    /// 動きがない時に自動で一時停止する機能を使うかどうか。iPhone側の「設定」を
    /// `WatchSessionManager`経由で反映する。
    var isAutoPauseForInactivityEnabled = true
    /// この時間、`movementResetThresholdMeters`以上の移動が無ければ自動的に一時停止する。
    /// iPhone側の「設定」で選んだ分数を`WatchSessionManager`経由で反映する。
    var stationaryAutoPauseInterval: TimeInterval = 5 * 60

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var pedometer: CMPedometerBridge?
    /// iPhoneなどで気づかず記録が回りっぱなしになる不具合への保険として、動いているか
    /// どうかによらずこの時間を超えたら自動的に記録を終了する。
    private static let maximumRecordingDuration: TimeInterval = 8 * 3600
    /// GPSのわずかなブレを「移動した」と誤検知しないための最小移動距離（メートル）。
    private static let movementResetThresholdMeters: CLLocationDistance = 15
    private var lastMovementAt: Date?
    private var lastMovementCoordinate: CLLocationCoordinate2D?
    /// 自動一時停止中は`true`。動きが戻れば自動的に`false`へ戻して記録を再開する。
    private var isAutoPaused = false
    /// ユーザーが手動で一時停止した間は`true`。この間は動きがない時間の判定自体を
    /// 止め、手動の一時停止を自動一時停止と誤認して上書きしないようにする。
    private var isManuallyPaused = false
    /// 最長時間超過は1回だけ通知する。
    private var hasNotifiedMaxDuration = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        // バックグラウンドでの位置情報継続は`HKWorkoutSession`（ワークアウト実行中の
        // バックグラウンド実行モード）が担うため、ここでは`allowsBackgroundLocationUpdates`を
        // 設定しない。Info.plistに対応する背景モードの宣言がない状態でこれを`true`にすると、
        // アプリ起動時に例外で落ちる（今回の「起動しない」不具合の原因）。
    }

    /// 記録を開始する。開始日時と、これまでの軌跡をクリアして返す。
    func start() {
        guard !isTracking else { return }
        path = []
        startDate = Date()
        isTracking = true
        lastMovementAt = Date()
        lastMovementCoordinate = nil
        isAutoPaused = false
        isManuallyPaused = false
        hasNotifiedMaxDuration = false
        pedometer = CMPedometerBridge()
        pedometer?.start()

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        startWorkoutSession()
    }

    func pause() {
        isManuallyPaused = true
        workoutSession?.pause()
    }

    func resume() {
        isManuallyPaused = false
        isAutoPaused = false
        lastMovementAt = Date()
        workoutSession?.resume()
    }

    /// 記録を終え、蓄積した軌跡・開始終了日時・歩数を返す。
    func stop() async -> (path: [CLLocationCoordinate2D], startedAt: Date, endedAt: Date, stepCount: Int?) {
        let endedAt = Date()
        let finishedPath = path
        let started = startDate ?? endedAt
        let stepCount = await pedometer?.finish()

        locationManager.stopUpdatingLocation()
        endWorkoutSession()
        isTracking = false
        startDate = nil
        pedometer = nil

        return (finishedPath, started, endedAt, stepCount)
    }

    private func startWorkoutSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor

        let typesToShare: Set = [HKObjectType.workoutType()]
        healthStore.requestAuthorization(toShare: typesToShare, read: []) { [weak self] granted, _ in
            guard granted else { return }
            Task { @MainActor in
                self?.beginWorkoutSession(configuration: configuration)
            }
        }
    }

    private func beginWorkoutSession(configuration: HKWorkoutConfiguration) {
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            session.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { _, _ in }
            workoutSession = session
            workoutBuilder = builder
        } catch {
            // ワークアウトセッションを開始できなくても、フォアグラウンドの間は
            // 位置情報の記録自体は続けられるようにする。
        }
    }

    private func endWorkoutSession() {
        guard let workoutSession, let workoutBuilder else { return }
        workoutSession.end()
        workoutBuilder.endCollection(withEnd: Date()) { [weak workoutBuilder] _, _ in
            workoutBuilder?.finishWorkout { _, _ in }
        }
        self.workoutSession = nil
        self.workoutBuilder = nil
    }
}

extension WatchWorkoutLocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.handleLocationUpdate(coordinate)
        }
    }

    /// GPS更新1回分を、最長記録時間・動きがない時の自動一時停止／自動再開に反映する。
    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        guard isTracking else { return }

        if !hasNotifiedMaxDuration, let startDate,
           Date().timeIntervalSince(startDate) >= Self.maximumRecordingDuration {
            hasNotifiedMaxDuration = true
            onMaxDurationExceeded?()
            return
        }

        // 手動で一時停止中は、動きがない時間の判定自体を止め、手動の一時停止を
        // 自動一時停止と誤認して上書きしないようにする（記録の扱いはこれまで通り）。
        guard !isManuallyPaused else {
            path.append(coordinate)
            onLocationUpdate?(coordinate)
            return
        }

        let hasMovedSignificantly: Bool = {
            guard let lastMovementCoordinate else { return true }
            let from = CLLocation(latitude: lastMovementCoordinate.latitude, longitude: lastMovementCoordinate.longitude)
            let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return from.distance(from: to) >= Self.movementResetThresholdMeters
        }()

        if isAutoPaused {
            guard isAutoPauseForInactivityEnabled, hasMovedSignificantly else { return }
            isAutoPaused = false
            lastMovementAt = Date()
            lastMovementCoordinate = coordinate
            path.append(coordinate)
            onLocationUpdate?(coordinate)
            return
        }

        path.append(coordinate)
        onLocationUpdate?(coordinate)

        if hasMovedSignificantly {
            lastMovementAt = Date()
            lastMovementCoordinate = coordinate
        } else if isAutoPauseForInactivityEnabled,
                  let lastMovementAt,
                  Date().timeIntervalSince(lastMovementAt) >= stationaryAutoPauseInterval {
            isAutoPaused = true
            workoutSession?.pause()
            onAutoPausedForInactivity?()
        }
    }
}

extension WatchWorkoutLocationTracker: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

/// Watch単体での歩数計測。`CMPedometer`はwatchOSでも利用できる。
private final class CMPedometerBridge {
    private let pedometer = CMPedometer()
    private var startDate: Date?

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        startDate = Date()
    }

    func finish() async -> Int? {
        guard let startDate else { return nil }
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: startDate, to: Date()) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue)
            }
        }
    }
}
