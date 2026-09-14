import CoreLocation
import Foundation

/// 「スタート」で記録中の徒歩ルートを、クラッシュ・強制終了に備えて端末に一時保存する。
///
/// これまで記録中の軌跡（`LocationManager.walkPath`）はメモリ上にしか無く、
/// 写真撮影・アップロード中にアプリが落ちる（メインスレッドが長時間ブロックされ
/// OSに強制終了される等）と、記録した旅がまるごと失われていた。歩いている間、
/// GPSが更新されるたびにこのストアへ軽く書き出しておき、次回起動時に見つかれば
/// 「続きから再開する／ここまでを保存する／破棄する」を選べるようにする。
enum InProgressWalkDraftStore {
    struct Draft: Codable {
        let sessionID: UUID
        let startedAt: Date
        let overlayMapID: String?
        let overlayOpacity: Double
        let latitudes: [Double]
        let longitudes: [Double]

        var coordinates: [CLLocationCoordinate2D] {
            zip(latitudes, longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
        }
    }

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InProgressWalkDraft.json")
    }

    /// 記録中、GPSが更新されるたびに呼んで良い軽い書き込み。ディスクI/Oをメインスレッドで
    /// ブロックしないよう、バックグラウンドで書き出す。
    static func save(
        sessionID: UUID,
        startedAt: Date,
        overlayMapID: String?,
        overlayOpacity: Double,
        coordinates: [CLLocationCoordinate2D]
    ) {
        let draft = Draft(
            sessionID: sessionID,
            startedAt: startedAt,
            overlayMapID: overlayMapID,
            overlayOpacity: overlayOpacity,
            latitudes: coordinates.map(\.latitude),
            longitudes: coordinates.map(\.longitude)
        )
        let url = fileURL
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(draft) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    /// 前回の記録が正常に終わらず残っていれば読み込む。
    static func load() -> Draft? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Draft.self, from: data)
    }

    /// 記録が正常に保存・破棄された時に呼び、一時保存を消す。
    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
