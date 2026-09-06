import Foundation
import UIKit

/// 連携プリンター（例: M5Stackなどが自宅Wi-Fi上で動かす簡易プリントサーバー）へ、
/// 御朱印・投稿写真を自動転送するクライアント。
///
/// 連携プリンター側は、JPEG画像をリクエストボディでそのまま受け取り印刷する
/// HTTPサーバーとして動かしておく必要がある。ホスト名だけ（例: "m5print.local"）を
/// 設定した場合は `http://<ホスト>/print` へ`POST`する。パスまで含めた完全なURLを
/// 設定した場合はそれをそのまま使う。
struct PrinterLinkService {
    /// 御朱印の写真を、「設定」画面の連携設定に応じて連携プリンターへ転送する。
    /// 未設定・転送オフの場合は何もしない。
    func printStampPhotoIfEnabled(_ image: UIImage) async {
        guard AppSettings.printerSyncStamps else { return }
        await send(image)
    }

    /// 投稿写真を、「設定」画面の連携設定に応じて連携プリンターへ転送する。
    /// 未設定・転送オフの場合は何もしない。
    func printPhotoPostIfEnabled(_ image: UIImage) async {
        guard AppSettings.printerSyncPhotoPosts else { return }
        await send(image)
    }

    private func send(_ image: UIImage) async {
        guard let host = AppSettings.printerLinkHost,
              let url = DeviceLinkURL.resolve(from: host, defaultPath: "/print"),
              let data = PhotoStorageService.compressedJPEGData(image)
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 10
        // 印刷できてもできなくても、ここでの失敗はユーザー操作をブロックしない
        // (ベストエフォート。プリンターの電源が入っていない等はよくあるため)。
        _ = try? await URLSession.shared.data(for: request)
    }
}
