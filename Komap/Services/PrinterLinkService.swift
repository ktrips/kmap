import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

/// 連携プリンター（例: M5Stackなどが自宅Wi-Fi上で動かす簡易プリントサーバー）へ、
/// 御朱印・投稿写真を自動転送するクライアント。
///
/// 連携プリンター側は、JPEG画像をリクエストボディでそのまま受け取り印刷する
/// HTTPサーバーとして動かしておく必要がある。ホスト名だけ（例: "m5print.local"）を
/// 設定した場合は `http://<ホスト>/print` へ`POST`する。パスまで含めた完全なURLを
/// 設定した場合はそれをそのまま使う。
///
/// 転送前に、「設定」画面で選んだ大きさ・白黒・画質を画像に適用する
/// （プリンターの通信量・印刷向けの見た目に合わせて、クラウド保存用の圧縮とは別に調整できるようにするため）。
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
              let url = DeviceLinkURL.resolve(from: host, defaultPath: "/print")
        else { return }

        let prepared = Self.prepareForPrint(image)
        guard let data = prepared.jpegData(compressionQuality: AppSettings.printerImageQuality.jpegQuality) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 10
        // 印刷できてもできなくても、ここでの失敗はユーザー操作をブロックしない
        // (ベストエフォート。プリンターの電源が入っていない等はよくあるため)。
        _ = try? await URLSession.shared.data(for: request)
    }

    /// 「設定」画面で選んだ大きさまで縮小し、白黒が有効なら彩度を落とす。
    private static func prepareForPrint(_ image: UIImage) -> UIImage {
        var output = resized(image, maxDimension: AppSettings.printerImageSize.maxDimension)
        if AppSettings.printerIsGrayscale, let grayscaled = grayscale(output) {
            output = grayscaled
        }
        return output
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// `CIContext`はGPUコンテキストの初期化コストが大きいため、呼び出しのたびに作り直さず使い回す。
    private static let context = CIContext()

    private static func grayscale(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.saturation = 0
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: ciImage.extent)
        else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
