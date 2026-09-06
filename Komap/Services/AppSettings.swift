import Foundation

/// Keychainに保存するほどではない、この端末だけのアプリ設定
/// （写真の加工スタイル・連携カメラ／連携プリンターのURLなど）。`UserDefaults`に保存する。
enum AppSettings {
    private static let photoFilterStyleKey = "photoFilterStyle"
    private static let cameraLinkHostKey = "cameraLinkHost"
    private static let printerLinkHostKey = "printerLinkHost"
    private static let printerSyncStampsKey = "printerSyncStamps"
    private static let printerSyncPhotoPostsKey = "printerSyncPhotoPosts"

    /// 撮影・追加した写真に適用する加工スタイル。
    static var photoFilterStyle: PhotoFilterStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: photoFilterStyleKey) else { return .none }
            return PhotoFilterStyle(rawValue: raw) ?? .none
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: photoFilterStyleKey) }
    }

    /// 連携カメラのホスト名／IP、または完全なURL（例: "m5cam.local"）。未設定なら`nil`。
    static var cameraLinkHost: String? {
        get { nonEmpty(UserDefaults.standard.string(forKey: cameraLinkHostKey)) }
        set { UserDefaults.standard.set(newValue, forKey: cameraLinkHostKey) }
    }

    /// 連携プリンターのホスト名／IP、または完全なURL（例: "m5print.local"）。未設定なら`nil`。
    static var printerLinkHost: String? {
        get { nonEmpty(UserDefaults.standard.string(forKey: printerLinkHostKey)) }
        set { UserDefaults.standard.set(newValue, forKey: printerLinkHostKey) }
    }

    /// 御朱印の写真を、追加・変更するたびに連携プリンターへも転送するか。
    static var printerSyncStamps: Bool {
        get { UserDefaults.standard.bool(forKey: printerSyncStampsKey) }
        set { UserDefaults.standard.set(newValue, forKey: printerSyncStampsKey) }
    }

    /// ウォーキング中の投稿写真を、投稿するたびに連携プリンターへも転送するか。
    static var printerSyncPhotoPosts: Bool {
        get { UserDefaults.standard.bool(forKey: printerSyncPhotoPostsKey) }
        set { UserDefaults.standard.set(newValue, forKey: printerSyncPhotoPostsKey) }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
