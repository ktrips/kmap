import Foundation

/// UUID（36文字）を、URLに載せる短い表現（Base64URL、22文字）へ変換する。
/// UUIDの16バイトをそのままBase64URLエンコードするだけの可逆変換のため、
/// サーバー側の対応表（短縮IDからUUIDを引く仕組み）を必要としない。
/// Web側（`web/src/lib/tripShortId.ts`）にも同じ変換ロジックを実装している。
extension UUID {
    var shortID: String {
        withUnsafeBytes(of: uuid) { rawBuffer in
            Data(rawBuffer).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        }
    }
}
