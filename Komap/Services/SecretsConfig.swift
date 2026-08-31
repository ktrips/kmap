import Foundation

/// アプリ内で使うAPIキーの取得口をまとめたもの。
///
/// - Google MapsのAPIキー: `Config/Secrets.xcconfig` → `Info.plist` の
///   `GMSApiKey` から読み込む（ビルド時に固定される）。
/// - OpenAIのAPIキー: 「設定」画面でユーザーが入力した値をKeychainから読む。
///   未設定の場合は `Info.plist` の `OpenAIApiKeyDefault`（xcconfigのデフォルト値）
///   にフォールバックする。
enum SecretsConfig {
    static var googleMapsAPIKey: String? {
        nonEmpty(Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String)
    }

    static var isGoogleMapsAPIKeyConfigured: Bool {
        guard let key = googleMapsAPIKey else { return false }
        return !key.contains("YOUR_GOOGLE_MAPS_API_KEY")
    }

    static var openAIAPIKey: String? {
        if let stored = nonEmpty(KeychainStore.shared.get(forKey: SecretKey.openAIApiKey)) {
            return stored
        }
        return nonEmpty(Bundle.main.object(forInfoDictionaryKey: "OpenAIApiKeyDefault") as? String)
    }

    static func saveOpenAIAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.shared.remove(forKey: SecretKey.openAIApiKey)
        } else {
            KeychainStore.shared.set(trimmed, forKey: SecretKey.openAIApiKey)
        }
    }

    /// 「古地図を検索」機能で使うGoogleカスタム検索のAPIキー。
    static var googleCustomSearchAPIKey: String? {
        if let stored = nonEmpty(KeychainStore.shared.get(forKey: SecretKey.customSearchAPIKey)) {
            return stored
        }
        return nonEmpty(Bundle.main.object(forInfoDictionaryKey: "CustomSearchAPIKeyDefault") as? String)
    }

    static func saveGoogleCustomSearchAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.shared.remove(forKey: SecretKey.customSearchAPIKey)
        } else {
            KeychainStore.shared.set(trimmed, forKey: SecretKey.customSearchAPIKey)
        }
    }

    /// 「古地図を検索」機能で使うGoogleカスタム検索エンジンID（cx）。
    static var googleCustomSearchEngineID: String? {
        if let stored = nonEmpty(KeychainStore.shared.get(forKey: SecretKey.customSearchEngineID)) {
            return stored
        }
        return nonEmpty(Bundle.main.object(forInfoDictionaryKey: "CustomSearchEngineIDDefault") as? String)
    }

    static func saveGoogleCustomSearchEngineID(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.shared.remove(forKey: SecretKey.customSearchEngineID)
        } else {
            KeychainStore.shared.set(trimmed, forKey: SecretKey.customSearchEngineID)
        }
    }

    /// 「古地図を検索」機能に必要なAPIキーがすべて揃っているか。
    static var isOldMapSearchConfigured: Bool {
        openAIAPIKey != nil && googleCustomSearchAPIKey != nil && googleCustomSearchEngineID != nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
