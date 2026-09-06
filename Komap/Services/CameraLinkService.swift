import Foundation
import UIKit

/// 連携カメラ（例: M5StackやESP32-CAMなどが自宅Wi-Fi上で動かす簡易カメラサーバー）から
/// 写真を取得するクライアント。
///
/// 連携カメラ側は、GETリクエストに対してJPEG画像をそのまま返すHTTPサーバーとして
/// あらかじめ動かしておく必要がある。ホスト名だけ（例: "m5web.local"）を設定した場合は
/// `http://<ホスト>/capture` にGETリクエストを送る（ESP32-CAM系でよく使われる
/// `/capture`エンドポイントの構成）。パスまで含めた完全なURLを設定した場合はそれをそのまま使う。
///
/// 連携プリンターのAPI（`/api/print/photo/url`）と同様に、画像バイナリではなく
/// `{"url": "http://.../snapshot.jpg"}`のようなJSONで画像のURLだけを返すタイプの
/// カメラにも対応するため、直接デコードできなかった場合はJSON中の`url`／`photoUrl`／
/// `imageUrl`キーを探し、見つかればそのURLを改めて取得する。
struct CameraLinkService {
    enum CameraLinkError: LocalizedError {
        case notConfigured
        case invalidURL
        case invalidResponse(status: Int, contentType: String?, bodyPreview: String?)
        case notAnImage(contentType: String?, bodyPreview: String?)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "連携カメラのURLが設定されていません。「設定」画面で入力してください。"
            case .invalidURL:
                return "連携カメラのURLが正しくありません。"
            case .invalidResponse(let status, let contentType, let bodyPreview):
                return "連携カメラからの応答が読み取れませんでした（HTTPステータス \(status)"
                    + Self.detailSuffix(contentType: contentType, bodyPreview: bodyPreview)
                    + "）。同じWi-Fiに接続されているか、URLが正しいか確認してください。"
            case .notAnImage(let contentType, let bodyPreview):
                return "連携カメラから画像を取得できませんでした"
                    + Self.detailSuffix(contentType: contentType, bodyPreview: bodyPreview)
                    + "。"
            }
        }

        private static func detailSuffix(contentType: String?, bodyPreview: String?) -> String {
            var parts: [String] = []
            if let contentType { parts.append("Content-Type: \(contentType)") }
            if let bodyPreview, !bodyPreview.isEmpty { parts.append("応答内容: \(bodyPreview)") }
            guard !parts.isEmpty else { return "" }
            return "（" + parts.joined(separator: " / ") + "）"
        }
    }

    /// 設定済みの連携カメラURLへGETリクエストを送り、返ってきた画像を返す。
    func fetchLatestPhoto() async throws -> UIImage {
        guard let host = AppSettings.cameraLinkHost else { throw CameraLinkError.notConfigured }
        guard let url = DeviceLinkURL.resolve(from: host, defaultPath: "/capture") else {
            throw CameraLinkError.invalidURL
        }
        return try await fetchImage(at: url, allowJSONRedirect: true)
    }

    private func fetchImage(at url: URL, allowJSONRedirect: Bool) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type")
        guard let httpResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw CameraLinkError.invalidResponse(
                status: httpResponse?.statusCode ?? -1,
                contentType: contentType,
                bodyPreview: Self.textPreview(of: data)
            )
        }

        if let image = UIImage(data: data) {
            return image
        }

        // 画像バイナリとして読めなかった場合、JSONで画像のURLだけを渡すタイプの
        // カメラかもしれないので、代表的なキー名で画像URLを探して一度だけ追いかける。
        if allowJSONRedirect, let imageURL = Self.extractImageURL(from: data) {
            return try await fetchImage(at: imageURL, allowJSONRedirect: false)
        }

        throw CameraLinkError.notAnImage(contentType: contentType, bodyPreview: Self.textPreview(of: data))
    }

    /// JSON応答から、画像を指していそうなURLを探す（`url`／`photoUrl`／`imageUrl`のいずれか）。
    private static func extractImageURL(from data: Data) -> URL? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        for key in ["url", "photoUrl", "photo_url", "imageUrl", "image_url"] {
            if let urlString = object[key] as? String, let url = URL(string: urlString) {
                return url
            }
        }
        return nil
    }

    /// エラーメッセージに含める、応答内容の短いプレビュー（UTF-8として解釈できた場合のみ）。
    private static func textPreview(of data: Data, maxLength: Int = 120) -> String? {
        guard let text = String(data: data.prefix(maxLength), encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > maxLength ? String(trimmed.prefix(maxLength)) + "…" : trimmed
    }
}
