import CoreLocation
import Foundation
import WatchConnectivity

/// Watch側の一覧・ピッカーに表示する古地図の選択肢。
struct WatchMapOption: Identifiable, Equatable {
    let id: String
    let title: String
}

/// iPhone側の「Komap」アプリとの連携をまとめる。2つのモードがある。
///
/// - Watch単体モード: Watchの「スタート」で自分自身のGPS（`WatchWorkoutLocationTracker`）
///   を使って記録する。iPhone側アプリが起動していなくても記録・保存できるよう、
///   終了時に軌跡をまるごと`transferUserInfo`でiPhoneへ送る。
/// - iPhone連動モード: iPhone側で「スタート」された記録を、従来通りコマンド送信で
///   一時停止・再開・終了だけ遠隔操作する（GPSはiPhone側のまま）。
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    enum RecordingState {
        case idle, recording, paused
    }

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var availableMaps: [WatchMapOption] = []
    @Published private(set) var selectedMapID: String?
    /// iPhoneとすぐに通信できる状態かどうか。`false`の間もコマンドはキューされて後で届く。
    @Published private(set) var isReachable = false
    /// 今の記録がWatch自身のGPSによるものかどうか（`false`ならiPhone側の記録を遠隔操作している）。
    @Published private(set) var isSelfTracking = false

    private let session: WCSession?
    /// 「スタート」を押すまでHealthKit・位置情報まわりの初期化を行わないよう、
    /// 実際に記録を始める時になって初めて作る（アプリ起動を軽く保つため）。
    private var tracker: WatchWorkoutLocationTracker?
    private var activeSessionID: UUID?

    override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    /// Watch自身のGPSで記録を開始する。
    func start() {
        guard state == .idle else { return }
        let sessionID = UUID()
        activeSessionID = sessionID
        isSelfTracking = true
        state = .recording
        let tracker = tracker ?? WatchWorkoutLocationTracker()
        self.tracker = tracker
        tracker.start()
        send(["command": "watchTrackingStarted", "sessionID": sessionID.uuidString])
    }

    func pause() {
        guard state == .recording else { return }
        state = .paused
        if isSelfTracking {
            tracker?.pause()
            send(["command": "watchTrackingPaused"])
        } else {
            send(["command": "pause"])
        }
    }

    func resume() {
        guard state == .paused else { return }
        state = .recording
        if isSelfTracking {
            tracker?.resume()
            send(["command": "watchTrackingResumed"])
        } else {
            send(["command": "resume"])
        }
    }

    func stop() {
        guard state != .idle else { return }
        if isSelfTracking, let tracker {
            let sessionID = activeSessionID
            state = .idle
            isSelfTracking = false
            activeSessionID = nil
            Task {
                let result = await tracker.stop()
                guard result.path.count >= 2 else { return }
                send([
                    "command": "watchTrackingFinished",
                    "sessionID": sessionID?.uuidString ?? UUID().uuidString,
                    "latitudes": result.path.map(\.latitude),
                    "longitudes": result.path.map(\.longitude),
                    "startedAt": result.startedAt.timeIntervalSince1970,
                    "endedAt": result.endedAt.timeIntervalSince1970,
                    "stepCount": result.stepCount as Any,
                ], reliable: true)
            }
        } else {
            state = .idle
            isSelfTracking = false
            send(["command": "stop"])
        }
    }

    func selectMap(_ id: String) {
        selectedMapID = id
        send(["command": "selectMap", "mapID": id])
    }

    /// 到達可能なら即時性の高い`sendMessage`、そうでなければ`transferUserInfo`で
    /// キューに積み、iPhoneが応答できるようになり次第届くようにする。
    /// `reliable`が`true`の記録データは、届いたか分からない`sendMessage`に頼らず
    /// 必ずキュー経由（`transferUserInfo`）で送る。
    private func send(_ payload: [String: Any], reliable: Bool = false) {
        guard let session, session.activationState == .activated else { return }
        if reliable {
            session.transferUserInfo(payload)
            return
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                Task { @MainActor in
                    self?.session?.transferUserInfo(payload)
                }
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// iPhone側から届く状態。Watch自身が記録中の間は、iPhone側の「記録していない」
    /// という情報で上書きしてしまわないよう、記録の状態だけは無視する。
    private func applyContext(_ context: [String: Any]) {
        if !isSelfTracking {
            let isRecording = context["isRecording"] as? Bool ?? false
            let isPaused = context["isPaused"] as? Bool ?? false
            if !isRecording {
                state = .idle
            } else if isPaused {
                state = .paused
            } else {
                state = .recording
            }
        }

        let mapIDs = context["mapIDs"] as? [String] ?? []
        let mapTitles = context["mapTitles"] as? [String] ?? []
        availableMaps = zip(mapIDs, mapTitles).map { WatchMapOption(id: $0, title: $1) }
        selectedMapID = context["selectedMapID"] as? String
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            self.applyContext(context)
            self.isReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.applyContext(applicationContext)
        }
    }
}
