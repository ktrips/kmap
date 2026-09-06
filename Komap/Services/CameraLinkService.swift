import Foundation
import UIKit

/// 連携カメラ（例: M5StackやESP32-CAMなどが自宅Wi-Fi上で動かす簡易カメラサーバー）から
/// 写真を取得するクライアント。
///
/// 連携カメラ側は、GETリクエストに対してJPEG画像をそのまま返すHTTPサーバーとして
/// あらかじめ動かしておく必要がある。ホスト名だけ（例: "m5web.local"）を設定した場合は
/// `http://<ホスト>/capture` にGETリクエストを送る（ESP32-CAM系でよく使われる
/// `/capture`エンドポイントの構成）。パスまで含めた完全なURLを設定した場合はそれをそのまま使う。
struct CameraLinkService {
    enum CameraLinkError: LocalizedError {
        case notConfigured
        case invalidURL
        case invalidResponse
        case notAnImage

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "連携カメラのURLが設定されていません。「設定」画面で入力してください。"
            case .invalidURL:
                return "連携カメラのURLが正しくありません。"
            case .invalidResponse:
                return "連携カメラからの応答が読み取れませんでした。同じWi-Fiに接続されているか確認してください。"
            case .notAnImage:
                return "連携カメラから画像を取得できませんでした。"
            }
        }
    }

    /// 設定済みの連携カメラURLへGETリクエストを送り、返ってきた画像を返す。
    func fetchLatestPhoto() async throws -> UIImage {
        guard let host = AppSettings.cameraLinkHost else { throw CameraLinkError.notConfigured }
        guard let url = DeviceLinkURL.resolve(from: host, defaultPath: "/capture") else {
            throw CameraLinkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw CameraLinkError.invalidResponse
        }
        guard let image = UIImage(data: data) else { throw CameraLinkError.notAnImage }
        return image
    }
}
