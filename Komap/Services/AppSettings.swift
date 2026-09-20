import Foundation

/// Keychainに保存するほどではない、この端末だけのアプリ設定
/// （写真の加工スタイル・連携カメラ／連携プリンターのURLなど）。`UserDefaults`に保存する。
enum AppSettings {
    private static let photoFilterStyleKey = "photoFilterStyle"
    private static let currentLocationIconStyleKey = "currentLocationIconStyle"
    private static let autoPauseWhenStationaryKey = "autoPauseWhenStationary"
    private static let stationaryAutoPauseMinutesKey = "stationaryAutoPauseMinutes"
    private static let allowAddingNewMapContentKey = "allowAddingNewMapContent"
    private static let aiProviderKey = "aiProvider"
    private static let defaultOverlayMapIDKey = "defaultOverlayMapID"
    private static let cameraLinkHostKey = "cameraLinkHost"
    private static let printerLinkHostKey = "printerLinkHost"
    private static let printerSyncStampsKey = "printerSyncStamps"
    private static let printerSyncPhotoPostsKey = "printerSyncPhotoPosts"
    private static let printerImageSizeKey = "printerImageSize"
    private static let printerImageQualityKey = "printerImageQuality"
    private static let printerIsGrayscaleKey = "printerIsGrayscale"
    private static let printerImageFormatKey = "printerImageFormat"
    private static let printerTransferModeKey = "printerTransferMode"

    /// 撮影・追加した写真に適用する加工スタイル。
    static var photoFilterStyle: PhotoFilterStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: photoFilterStyleKey) else { return .none }
            return PhotoFilterStyle(rawValue: raw) ?? .none
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: photoFilterStyleKey) }
    }

    /// 歩いている時、地図上に表示する現在地マークの見た目。
    static var currentLocationIconStyle: CurrentLocationIconStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: currentLocationIconStyleKey) else { return .blueDot }
            return CurrentLocationIconStyle(rawValue: raw) ?? .blueDot
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: currentLocationIconStyleKey) }
    }

    /// 記録中、動きがない状態がしばらく続いたら自動で一時停止するか。Apple Watchなどで
    /// 気づかず記録が回りっぱなしになるのを防ぐための機能。未設定時は`true`（有効）。
    static var autoPauseWhenStationary: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoPauseWhenStationaryKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoPauseWhenStationaryKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoPauseWhenStationaryKey) }
    }

    /// 「動きがない時に自動で一時停止」までの時間（分）。1・5・10・20分から選べる。
    /// 未設定時は5分。
    static var stationaryAutoPauseMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: stationaryAutoPauseMinutesKey)
            return stored == 0 ? 5 : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: stationaryAutoPauseMinutesKey) }
    }

    /// 「管理者設定」の「新しい地図を追加」。AI・Web検索を使ってコストが発生する
    /// 「新しい古地図を登録」機能と、地図タップでAIが物語を生成する「新しいポイントを追加」
    /// 機能の両方を、この設定が`true`の間だけ使えるようにする（意図しないAPI利用を防ぐ
    /// ため、既定は`false`＝追加不可）。
    static var allowAddingNewMapContent: Bool {
        get { UserDefaults.standard.bool(forKey: allowAddingNewMapContentKey) }
        set { UserDefaults.standard.set(newValue, forKey: allowAddingNewMapContentKey) }
    }

    /// 「設定」の「AI設定」で選ぶ、物語生成に使うデフォルトのAIプロバイダー。未設定時はOpenAI。
    static var aiProvider: AIProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: aiProviderKey) else { return .openAI }
            return AIProvider(rawValue: raw) ?? .openAI
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: aiProviderKey) }
    }

    /// 「最初に表示する古地図」の選択肢のうち、古地図そのものではないもの。
    /// `defaultOverlayMapID`にはこの値か、古地図のIDが入る。
    static let defaultOverlayCurrentLocationToken = "current-location"
    static let defaultOverlayAllToken = "all-overlays"

    /// アプリ起動時・記録開始時などにデフォルトで選ばれる古地図のID（または上の特別な値）。
    /// 未設定なら`nil`で、「現在地」（現在地を含む古地図を選ぶ）として扱う。
    /// 現在地を含む古地図が無い時などの代わりには、`OldMapCatalog.defaultOverlay`が
    /// 同梱の「江戸城周辺」にフォールバックする。
    static var defaultOverlayMapID: String? {
        get { nonEmpty(UserDefaults.standard.string(forKey: defaultOverlayMapIDKey)) }
        set { UserDefaults.standard.set(newValue, forKey: defaultOverlayMapIDKey) }
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

    /// 連携プリンターへ転送する画像の大きさ（データ量）。
    static var printerImageSize: PrinterImageSize {
        get {
            guard let raw = UserDefaults.standard.string(forKey: printerImageSizeKey) else { return .large }
            return PrinterImageSize(rawValue: raw) ?? .large
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: printerImageSizeKey) }
    }

    /// 連携プリンターへ転送する画像のJPEG圧縮率。
    static var printerImageQuality: PrinterImageQuality {
        get {
            guard let raw = UserDefaults.standard.string(forKey: printerImageQualityKey) else { return .medium }
            return PrinterImageQuality(rawValue: raw) ?? .medium
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: printerImageQualityKey) }
    }

    /// 連携プリンターへ転送する画像を白黒に変換するか。
    static var printerIsGrayscale: Bool {
        get { UserDefaults.standard.bool(forKey: printerIsGrayscaleKey) }
        set { UserDefaults.standard.set(newValue, forKey: printerIsGrayscaleKey) }
    }

    /// 連携プリンターへ転送する画像ファイルのフォーマット（JPEG／PNG）。
    static var printerImageFormat: PrinterImageFormat {
        get {
            guard let raw = UserDefaults.standard.string(forKey: printerImageFormatKey) else { return .jpg }
            return PrinterImageFormat(rawValue: raw) ?? .jpg
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: printerImageFormatKey) }
    }

    /// 連携プリンターへの転送方式（直接送信／URLを渡す）。
    static var printerTransferMode: PrinterTransferMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: printerTransferModeKey) else { return .direct }
            return PrinterTransferMode(rawValue: raw) ?? .direct
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: printerTransferModeKey) }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
