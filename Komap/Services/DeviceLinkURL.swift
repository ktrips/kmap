import Foundation

/// 連携カメラ・連携プリンターのURL入力を解決する共通ヘルパー。
///
/// 設定画面ではホスト名／IPだけ（例: "m5web.local"）を入力する想定だが、
/// パスやポートを含む完全なURL（例: "http://192.168.1.20:8080/capture"）を
/// そのまま入力してもよい。
enum DeviceLinkURL {
    /// - Parameters:
    ///   - input: 設定画面で入力された文字列。
    ///   - defaultPath: ホスト名だけが入力された場合に補うパス（例: "/capture"）。
    static func resolve(from input: String, defaultPath: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "http://\(trimmed)\(defaultPath)")
    }
}
