import Foundation
import Security

/// APIキーなどの機密情報をKeychainに保存するための薄いラッパー。
///
/// UserDefaultsではなくKeychainを使うことで、OpenAIのAPIキーを
/// デバイス上でより安全に保持する。
struct KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.komap.Komap.secrets"

    func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        var query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    func get(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func remove(forKey key: String) {
        let query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

enum SecretKey {
    static let openAIApiKey = "openAIApiKey"
}
