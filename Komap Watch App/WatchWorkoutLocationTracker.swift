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

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var pedometer: CMPedometerBridge?

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
        pedometer = CMPedometerBridge()
        pedometer?.start()

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        startWorkoutSession()
    }

    func pause() {
        workoutSession?.pause()
    }

    func resume() {
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
            guard self.isTracking else { return }
            self.path.append(coordinate)
            self.onLocationUpdate?(coordinate)
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
