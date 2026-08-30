import Foundation
import WatchConnectivity

/// Apple Watch用アプリからの「スタート／一時停止／再開／終了／古地図の選択」コマンドを受け取り、
/// 現在のウォーキング記録状態・選べる古地図の一覧をWatch側へ送り返す。
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    enum Command: Equatable {
        case start, pause, resume, stop
        case selectMap(id: String)
    }

    /// Watchから届いた最新のコマンド。呼び出し側（`MapScreen`）が`onChange`で監視して処理する。
    @Published private(set) var lastCommand: Command?

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    /// 現在の記録状態・選択中の古地図をWatchへ反映する。Watch側アプリが起動していなくても、
    /// 次回起動時に最新の状態が届くよう`updateApplicationContext`を使う。
    func updateState(
        isRecording: Bool,
        isPaused: Bool,
        availableMaps: [HistoricalOverlayMap],
        selectedMapID: String?
    ) {
        guard let session, session.activationState == .activated else { return }
        try? session.updateApplicationContext([
            "isRecording": isRecording,
            "isPaused": isPaused,
            "mapIDs": availableMaps.map(\.id),
            "mapTitles": availableMaps.map(\.title),
            "selectedMapID": selectedMapID as Any,
        ])
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let rawCommand = message["command"] as? String, let command = Self.parseCommand(rawCommand, message: message) else {
            replyHandler(["ok": false])
            return
        }
        Task { @MainActor in
            self.lastCommand = command
        }
        replyHandler(["ok": true])
    }

    private nonisolated static func parseCommand(_ rawCommand: String, message: [String: Any]) -> Command? {
        switch rawCommand {
        case "start": return .start
        case "pause": return .pause
        case "resume": return .resume
        case "stop": return .stop
        case "selectMap":
            guard let mapID = message["mapID"] as? String else { return nil }
            return .selectMap(id: mapID)
        default:
            return nil
        }
    }
}
