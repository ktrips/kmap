import Foundation

/// 「設定」の「AI設定」で選べる、物語生成に使うAIプロバイダー。
enum AIProvider: String, CaseIterable, Identifiable {
    case openAI
    case google
    case anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .google: return "Google"
        case .anthropic: return "Anthropic"
        }
    }

    /// 「〇〇のAPIキーを設定してください」のような案内文で使う、APIキーの呼び名。
    var apiKeyLabel: String { "\(title) APIキー" }
}

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

    /// 「AI設定」で入力する、物語生成用のGoogle APIキー（Gemini等）。
    static var googleAIAPIKey: String? {
        nonEmpty(KeychainStore.shared.get(forKey: SecretKey.googleAIApiKey))
    }

    static func saveGoogleAIAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.shared.remove(forKey: SecretKey.googleAIApiKey)
        } else {
            KeychainStore.shared.set(trimmed, forKey: SecretKey.googleAIApiKey)
        }
    }

    /// 「AI設定」で入力する、物語生成用のAnthropic APIキー。
    static var anthropicAPIKey: String? {
        nonEmpty(KeychainStore.shared.get(forKey: SecretKey.anthropicApiKey))
    }

    static func saveAnthropicAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.shared.remove(forKey: SecretKey.anthropicApiKey)
        } else {
            KeychainStore.shared.set(trimmed, forKey: SecretKey.anthropicApiKey)
        }
    }

    /// 「古地図を検索」機能に必要なAPIキー（OpenAI）が揃っているか。画像検索は国立国会図書館とWikimedia Commons（キー不要）を使う。
    static var isOldMapSearchConfigured: Bool {
        openAIAPIKey != nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
