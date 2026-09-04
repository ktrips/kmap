import CoreLocation
import Foundation
import WatchConnectivity

/// Watch側の一覧・ピッカーに表示する古地図の選択肢。
struct WatchMapOption: Identifiable, Equatable {
    let id: String
    let title: String
}

/// iPhoneから届いた「御朱印を新しく獲得した」という通知。Watch画面でその場チェックインできるようにする。
struct WatchCollectedStampInfo: Identifiable, Equatable {
    let id = UUID()
    let siteName: String
    let siteSummary: String
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
    /// iPhoneから届いた、新しく獲得した御朱印の通知。表示したら`acknowledgeStampCollected()`で消す。
    @Published private(set) var newlyCollectedStamp: WatchCollectedStampInfo?
    /// iPhoneから届いた、写真投稿で獲得したポイント。表示したら`acknowledgePhotoPosted()`で消す。
    @Published private(set) var newlyPostedPhotoPoints: Int?

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
        tracker.onLocationUpdate = { [weak self] coordinate in
            self?.sendLocationUpdate(coordinate)
        }
        tracker.start()
        send(["command": "watchTrackingStarted", "sessionID": sessionID.uuidString])
    }

    /// 新しく獲得した御朱印の通知を確認したら呼ぶ。
    func acknowledgeStampCollected() {
        newlyCollectedStamp = nil
    }

    /// 写真投稿のポイント通知を確認したら呼ぶ。
    func acknowledgePhotoPosted() {
        newlyPostedPhotoPoints = nil
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

    /// 記録を終える。`shouldSave`が`false`の時（保存確認シートで「破棄」を選んだ時）は、
    /// 記録を止めるだけで軌跡は送らず、iPhone側にも保存しないことを伝える。
    func stop(shouldSave: Bool = true) {
        guard state != .idle else { return }
        if isSelfTracking, let tracker {
            let sessionID = activeSessionID
            state = .idle
            isSelfTracking = false
            activeSessionID = nil
            // `sendTrackingSnapshot()`で書いた累積軌跡をそのままにしておくと、
            // 記録終了後にiPhone側アプリを開いた時、有効化時に読み直した古い
            // スナップショットのせいで「まだWatchで記録中」と誤認してしまう
            // （`WatchConnectivityManager.activationDidCompleteWith`参照）。
            // 終了時に空にしておき、次に始まるまでは何も残らないようにする。
            try? session?.updateApplicationContext([:])
            Task {
                let result = await tracker.stop()
                guard shouldSave else {
                    send(["command": "watchTrackingDiscarded"])
                    return
                }
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
            send(["command": shouldSave ? "stop" : "discard"])
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

    /// Watch単体のGPSで得た現在地をiPhoneへ転送し、御朱印チェックポイントの判定に使ってもらう。
    /// 位置更新は頻繁なので、キューに積む`transferUserInfo`は使わず、到達可能な時だけ
    /// ベストエフォートで送る（届かなくても次の更新ですぐ追いつくため問題ない）。
    ///
    /// ただし、iPhoneがロック中・バックグラウンドなどで到達不能な間はこれが一切届かず、
    /// 記録の軌跡がiPhone側にまったく反映されないままになってしまう。そのため、
    /// 到達可能かどうかに関わらず`sendTrackingSnapshot()`で累積軌跡も送っておき、
    /// iPhoneが後で操作可能になった時にすぐ追いつけるようにする。
    private func sendLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        if let session, session.activationState == .activated, session.isReachable {
            session.sendMessage(
                ["command": "watchLocationUpdate", "lat": coordinate.latitude, "lon": coordinate.longitude],
                replyHandler: nil,
                errorHandler: nil
            )
        }
        sendTrackingSnapshot()
    }

    /// 記録中の累積軌跡を、iPhoneが今すぐ受け取れるかどうかに関わらず送っておく。
    /// `updateApplicationContext`は内容が常に最新のものに置き換わるだけなので、
    /// 頻繁に呼んでもキューが溜まる心配がない。
    private func sendTrackingSnapshot() {
        guard let session, session.activationState == .activated,
              let tracker, let sessionID = activeSessionID
        else { return }
        let path = tracker.path
        guard !path.isEmpty else { return }
        try? session.updateApplicationContext([
            "trackingSessionID": sessionID.uuidString,
            "trackingLatitudes": path.map(\.latitude),
            "trackingLongitudes": path.map(\.longitude),
            "trackingUpdatedAt": Date().timeIntervalSince1970,
        ])
    }

    /// iPhoneから届いた「御朱印を新しく獲得した」通知を受け取る。
    private func applyStampCollected(_ message: [String: Any]) {
        guard let siteName = message["siteName"] as? String else { return }
        let siteSummary = message["siteSummary"] as? String ?? ""
        newlyCollectedStamp = WatchCollectedStampInfo(siteName: siteName, siteSummary: siteSummary)
    }

    /// iPhoneから届いた「写真投稿でポイントを獲得した」通知を受け取る。
    private func applyPhotoPosted(_ message: [String: Any]) {
        guard let points = message["points"] as? Int else { return }
        newlyPostedPhotoPoints = points
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

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        switch message["command"] as? String {
        case "stampCollected":
            Task { @MainActor in self.applyStampCollected(message) }
        case "photoPosted":
            Task { @MainActor in self.applyPhotoPosted(message) }
        default:
            break
        }
        replyHandler(["ok": true])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        switch userInfo["command"] as? String {
        case "stampCollected":
            Task { @MainActor in self.applyStampCollected(userInfo) }
        case "photoPosted":
            Task { @MainActor in self.applyPhotoPosted(userInfo) }
        default:
            break
        }
    }
}
