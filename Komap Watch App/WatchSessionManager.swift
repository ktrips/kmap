import Foundation
import WatchConnectivity

/// Watch側の一覧・ピッカーに表示する古地図の選択肢。
struct WatchMapOption: Identifiable, Equatable {
    let id: String
    let title: String
}

/// iPhone側の「Komap」アプリへ、スタート／一時停止／再開／終了／古地図の選択の
/// コマンドを送り、現在の記録状態と選べる古地図の一覧を受け取ってWatch側の画面に反映する。
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

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    /// 「スタート」を押した瞬間に反映されるよう、送信前に画面上の状態も更新しておく。
    /// 実際の状態はiPhone側から折り返される`applicationContext`で確定する。
    func start() {
        state = .recording
        send(["command": "start"])
    }

    func pause() {
        state = .paused
        send(["command": "pause"])
    }

    func resume() {
        state = .recording
        send(["command": "resume"])
    }

    func stop() {
        state = .idle
        send(["command": "stop"])
    }

    func selectMap(_ id: String) {
        selectedMapID = id
        send(["command": "selectMap", "mapID": id])
    }

    /// 到達可能なら即時性の高い`sendMessage`、そうでなければ`transferUserInfo`で
    /// キューに積み、iPhoneが応答できるようになり次第届くようにする。
    private func send(_ payload: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
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

    private func applyContext(_ context: [String: Any]) {
        let isRecording = context["isRecording"] as? Bool ?? false
        let isPaused = context["isPaused"] as? Bool ?? false
        if !isRecording {
            state = .idle
        } else if isPaused {
            state = .paused
        } else {
            state = .recording
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
