import CoreLocation
import Foundation
import WatchConnectivity

/// Watch単体のGPSで記録を終えた時に届く、まるごとの軌跡データ。
struct WatchTrackedRoute {
    let sessionID: String
    let coordinates: [CLLocationCoordinate2D]
    let startedAt: Date
    let endedAt: Date
    let stepCount: Int?
}

/// Apple Watch用アプリからの「スタート／一時停止／再開／終了／古地図の選択」コマンドや、
/// Watch単体のGPSで記録した軌跡を受け取り、現在のウォーキング記録状態・選べる
/// 古地図の一覧をWatch側へ送り返す。
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    enum Command: Equatable {
        case start, pause, resume, stop
        /// Watchの保存確認シートで「破棄」が選ばれた（iPhone連動モード）。
        case discard
        case selectMap(id: String)
        /// Watch自身のGPSで記録が始まった／一時停止／再開したという通知（GPSはWatch側のまま）。
        case watchTrackingStarted(sessionID: String)
        case watchTrackingPaused
        case watchTrackingResumed
        /// Watch単体の記録が終わり、軌跡がまるごと届いた。
        case watchTrackingFinished(WatchTrackedRoute)
        /// Watch単体の記録が、Watchの保存確認シートで「破棄」されて終わった。
        case watchTrackingDiscarded
        /// Watch単体のGPSで記録中、現在地が更新された（御朱印チェックポイントの判定に使う）。
        case watchLocationUpdate(CLLocationCoordinate2D)
        /// Watch単体のGPSで記録中の累積軌跡（`updateApplicationContext`経由）。
        /// iPhoneがロック中・バックグラウンドなどで`watchLocationUpdate`が届かなかった間も、
        /// 後で操作可能になった時にこれで軌跡に追いつけるようにする。内容は常に最新の
        /// 累積軌跡全体に置き換わる。
        case watchTrackingSnapshot(sessionID: String, coordinates: [CLLocationCoordinate2D])

        static func == (lhs: Command, rhs: Command) -> Bool {
            switch (lhs, rhs) {
            case (.start, .start), (.pause, .pause), (.resume, .resume), (.stop, .stop), (.discard, .discard),
                (.watchTrackingPaused, .watchTrackingPaused), (.watchTrackingResumed, .watchTrackingResumed),
                (.watchTrackingDiscarded, .watchTrackingDiscarded):
                return true
            case let (.selectMap(a), .selectMap(b)):
                return a == b
            case let (.watchTrackingStarted(a), .watchTrackingStarted(b)):
                return a == b
            case let (.watchTrackingFinished(a), .watchTrackingFinished(b)):
                return a.sessionID == b.sessionID
            case let (.watchLocationUpdate(a), .watchLocationUpdate(b)):
                return a.latitude == b.latitude && a.longitude == b.longitude
            case let (.watchTrackingSnapshot(idA, coordsA), .watchTrackingSnapshot(idB, coordsB)):
                return idA == idB && coordsA.count == coordsB.count
            default:
                return false
            }
        }
    }

    /// Watchから届いた最新のコマンド。呼び出し側（`MapScreen`）が`onChange`で監視して処理する。
    @Published private(set) var lastCommand: Command?
    /// セッションの有効化が完了したかどうか。`updateState`は有効化前だと送れないため、
    /// 呼び出し側はこの変化を見て初回の状態を送り直す。
    @Published private(set) var isActivated = false

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

    /// 御朱印を新しく獲得した時、Watch側にも通知してその場で確認・チェックインできるようにする。
    /// Apple Watchで計測中かどうかに関わらず、獲得のたびに知らせる。
    func notifyStampCollected(siteName: String, siteSummary: String) {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "command": "stampCollected",
            "siteName": siteName,
            "siteSummary": siteSummary,
        ]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak session] _ in
                session?.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// 写真を投稿してポイントを獲得した時、Watch側にも知らせる。
    func notifyPhotoPosted(points: Int) {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = ["command": "photoPosted", "points": points]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak session] _ in
                session?.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.isActivated = true
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Watch側から送られてくる、記録中の累積軌跡のスナップショットを受け取る
    /// （`watchLocationUpdate`が届かなかった間の埋め合わせ用）。
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let sessionID = applicationContext["trackingSessionID"] as? String,
              let latitudes = applicationContext["trackingLatitudes"] as? [Double],
              let longitudes = applicationContext["trackingLongitudes"] as? [Double],
              latitudes.count == longitudes.count
        else {
            return
        }
        let coordinates = zip(latitudes, longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
        Task { @MainActor in
            self.lastCommand = .watchTrackingSnapshot(sessionID: sessionID, coordinates: coordinates)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = Self.parseCommand(from: message) else {
            replyHandler(["ok": false])
            return
        }
        Task { @MainActor in
            self.lastCommand = command
        }
        replyHandler(["ok": true])
    }

    /// Watch側が到達不能な時に使う`transferUserInfo`経由のコマンドも、
    /// `sendMessage`と同じように処理する。
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let command = Self.parseCommand(from: userInfo) else { return }
        Task { @MainActor in
            self.lastCommand = command
        }
    }

    private nonisolated static func parseCommand(from message: [String: Any]) -> Command? {
        guard let rawCommand = message["command"] as? String else { return nil }
        switch rawCommand {
        case "start": return .start
        case "pause": return .pause
        case "resume": return .resume
        case "stop": return .stop
        case "discard": return .discard
        case "selectMap":
            guard let mapID = message["mapID"] as? String else { return nil }
            return .selectMap(id: mapID)
        case "watchTrackingStarted":
            guard let sessionID = message["sessionID"] as? String else { return nil }
            return .watchTrackingStarted(sessionID: sessionID)
        case "watchTrackingPaused":
            return .watchTrackingPaused
        case "watchTrackingResumed":
            return .watchTrackingResumed
        case "watchLocationUpdate":
            guard let lat = message["lat"] as? Double, let lon = message["lon"] as? Double else { return nil }
            return .watchLocationUpdate(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        case "watchTrackingFinished":
            guard let sessionID = message["sessionID"] as? String,
                  let latitudes = message["latitudes"] as? [Double],
                  let longitudes = message["longitudes"] as? [Double],
                  latitudes.count == longitudes.count,
                  let startedAtInterval = message["startedAt"] as? Double,
                  let endedAtInterval = message["endedAt"] as? Double
            else {
                return nil
            }
            let coordinates = zip(latitudes, longitudes).map {
                CLLocationCoordinate2D(latitude: $0, longitude: $1)
            }
            return .watchTrackingFinished(WatchTrackedRoute(
                sessionID: sessionID,
                coordinates: coordinates,
                startedAt: Date(timeIntervalSince1970: startedAtInterval),
                endedAt: Date(timeIntervalSince1970: endedAtInterval),
                stepCount: message["stepCount"] as? Int
            ))
        case "watchTrackingDiscarded":
            return .watchTrackingDiscarded
        default:
            return nil
        }
    }
}
