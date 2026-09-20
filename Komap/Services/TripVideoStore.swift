import Foundation

/// 作った旅の動画（MP4）を、時空旅ごとに端末へ保存しておく。
/// 一時フォルダのままだと消えてしまうため、`Application Support`配下に置き、
/// 次に開いた時も作り直さず再生・共有できるようにする。
enum TripVideoStore {
    private static var directoryURL: URL {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TripVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func fileURL(for routeID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(routeID.uuidString).mp4")
    }

    /// 保存済みの動画があればそのURL。
    static func existingURL(for routeID: UUID) -> URL? {
        let url = fileURL(for: routeID)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 一時ファイルの動画を保存先へ移し（同じ時空旅の古い動画は置き換え）、保存先のURLを返す。
    static func save(_ temporaryURL: URL, for routeID: UUID) -> URL {
        let destination = fileURL(for: routeID)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return destination
        } catch {
            return temporaryURL
        }
    }

    static func delete(for routeID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: routeID))
    }
}
