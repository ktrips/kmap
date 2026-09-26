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
    /// 一時停止（手動・自動とも）のまま`maximumPausedDuration`を超えた時に呼ばれる。
    /// 止め忘れたままワークアウトとGPSが回り続け、Watchの電池を減らすのを防ぐ。
    var onPausedTooLong: (() -> Void)?
    /// 自分で終了していないのに、ワークアウトが終わった・失敗した時に呼ばれる
    /// （コントロールセンターからの終了、システムによる終了など）。GPSは止めてから呼ぶ。
    var onWorkoutEndedUnexpectedly: (() -> Void)?
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
    /// 一時停止のままこの時間が過ぎたら、止め忘れとみなして記録を終える。
    private static let maximumPausedDuration: TimeInterval = 60 * 60
    /// GPSの更新が来ない（静止していて`distanceFilter`に届かない）間も、最長時間・
    /// 動きがない時間・一時停止の長さを判定できるよう、この間隔で見回る。
    private static let watchdogInterval: TimeInterval = 30
    private var watchdogTimer: Timer?
    /// 一時停止（手動・自動）に入った時刻。再開したら`nil`に戻す。
    private var pausedAt: Date?
    /// 自分で`stop()`した時は`true`。ワークアウトの終了通知を「予期しない終了」と区別する。
    private var isStopping = false
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
        applyRecordingAccuracy()
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
        pausedAt = nil
        isStopping = false
        pedometer = CMPedometerBridge()
        pedometer?.start()

        applyRecordingAccuracy()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        startWorkoutSession()
        startWatchdog()
    }

    /// 手動の一時停止。記録しない間はGPSを完全に止め、電池を使わないようにする。
    func pause() {
        guard isTracking else { return }
        isManuallyPaused = true
        isAutoPaused = false
        pausedAt = pausedAt ?? Date()
        locationManager.stopUpdatingLocation()
        workoutSession?.pause()
    }

    func resume() {
        guard isTracking else { return }
        isManuallyPaused = false
        isAutoPaused = false
        pausedAt = nil
        lastMovementAt = Date()
        lastMovementCoordinate = nil
        applyRecordingAccuracy()
        locationManager.startUpdatingLocation()
        workoutSession?.resume()
    }

    /// 記録を終え、蓄積した軌跡・開始終了日時・歩数を返す。
    func stop() async -> (path: [CLLocationCoordinate2D], startedAt: Date, endedAt: Date, stepCount: Int?) {
        let endedAt = Date()
        let finishedPath = path
        let started = startDate ?? endedAt
        // GPS・ワークアウト・見回りは、歩数の問い合わせを待たずにすぐ止める。
        isStopping = true
        isTracking = false
        stopWatchdog()
        locationManager.stopUpdatingLocation()
        endWorkoutSession()
        pausedAt = nil

        let stepCount = await pedometer?.finish()
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
        // HealthKitの許可を待つ間に記録が終わっていたら、ワークアウトを始めない
        // （始めてしまうと誰も終了しないワークアウトが残り、電池を減らし続ける）。
        guard isTracking, workoutSession == nil else { return }
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            session.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { _, _ in }
            workoutSession = session
            workoutBuilder = builder
            if isManuallyPaused || isAutoPaused {
                session.pause()
            }
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

    /// 記録中の精度。軌跡をきれいに描くため、最も高い精度で5mごとに更新する。
    private func applyRecordingAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    /// 自動一時停止中の精度。動き出したかどうか（`movementResetThresholdMeters`以上の移動）
    /// だけ分かればよいので、精度と更新頻度を落としてGPSの電池消費を抑える。
    private func applyAutoPausedAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = Self.movementResetThresholdMeters
    }

    private func startWatchdog() {
        stopWatchdog()
        let timer = Timer(timeInterval: Self.watchdogInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkWatchdog() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    /// GPSの更新が来なくても、時間だけで決まる終了・一時停止をここで判定する。
    private func checkWatchdog() {
        guard isTracking else { return }
        let now = Date()

        if !hasNotifiedMaxDuration, let startDate,
           now.timeIntervalSince(startDate) >= Self.maximumRecordingDuration {
            hasNotifiedMaxDuration = true
            onMaxDurationExceeded?()
            return
        }

        if let pausedAt, now.timeIntervalSince(pausedAt) >= Self.maximumPausedDuration {
            self.pausedAt = nil
            onPausedTooLong?()
            return
        }

        if !isManuallyPaused, !isAutoPaused, isAutoPauseForInactivityEnabled,
           let lastMovementAt, now.timeIntervalSince(lastMovementAt) >= stationaryAutoPauseInterval {
            enterAutoPause()
        }
    }

    private func enterAutoPause() {
        isAutoPaused = true
        pausedAt = pausedAt ?? Date()
        applyAutoPausedAccuracy()
        workoutSession?.pause()
        onAutoPausedForInactivity?()
    }

    /// ワークアウトが自分の`stop()`以外で終わった時、GPSと見回りを止めて呼び出し側に知らせる。
    private func handleWorkoutEndedUnexpectedly() {
        guard isTracking, !isStopping else { return }
        stopWatchdog()
        locationManager.stopUpdatingLocation()
        workoutSession = nil
        workoutBuilder = nil
        onWorkoutEndedUnexpectedly?()
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
        // 手動で一時停止中はGPSを止めているが、止める直前に届いた更新は捨てる。
        guard isTracking, !isManuallyPaused else { return }

        let hasMovedSignificantly: Bool = {
            guard let lastMovementCoordinate else { return true }
            let from = CLLocation(latitude: lastMovementCoordinate.latitude, longitude: lastMovementCoordinate.longitude)
            let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return from.distance(from: to) >= Self.movementResetThresholdMeters
        }()

        if isAutoPaused {
            guard isAutoPauseForInactivityEnabled, hasMovedSignificantly else { return }
            isAutoPaused = false
            pausedAt = nil
            applyRecordingAccuracy()
            workoutSession?.resume()
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
            enterAutoPause()
        }
    }
}

extension WatchWorkoutLocationTracker: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended || toState == .stopped else { return }
        Task { @MainActor in
            guard self.workoutSession === workoutSession else { return }
            self.handleWorkoutEndedUnexpectedly()
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.workoutSession === workoutSession else { return }
            self.handleWorkoutEndedUnexpectedly()
        }
    }
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
