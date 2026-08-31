import Foundation

/// 「古地図を検索」シートの、直近の検索キーワードと結果を保持する。
///
/// シートを閉じて開き直しただけでAI・Web検索へ再度問い合わせに行かずに済むよう、
/// アプリ起動中はこのキャッシュを見てから検索するかどうかを判断する。
/// （実際に古地図として追加した後は`CustomOverlayMapStore`に永続化されるため、
/// このキャッシュは「まだ追加していない検索結果」を一時的に覚えておく役割）
@MainActor
final class OldMapSearchCache: ObservableObject {
    static let shared = OldMapSearchCache()

    @Published var query: String = ""
    @Published var result: OldMapSearchResult?

    private init() {}

    func clear() {
        query = ""
        result = nil
    }
}
