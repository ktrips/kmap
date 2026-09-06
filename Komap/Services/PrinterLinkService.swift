import CoreImage
import CoreImage.CIFilterBuiltins
import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import Foundation
import UIKit

/// 連携プリンター（例: M5Stackなどが自宅Wi-Fi上で動かす簡易プリントサーバー）へ、
/// 御朱印・投稿写真を自動転送するクライアント。
///
/// 連携プリンターのURL設定には、2通りの方式に対応する。
/// 1. パスまでのURL（例: "m5print.local" や "http://m5print.local/print"）:
///    画像データそのものをリクエストボディに入れて`POST`する（プリンター側がボディを
///    直接受け取って印刷するタイプ）。
/// 2. クエリに`photo=`を含むURL（例: "http://m5web.local/api/print?photo="）:
///    画像を一度Firebase Storageへアップロードし、その公開URLを`photo=`の後ろに
///    続けて`GET`する（プリンター側が渡されたURLを自分で取得しにいくタイプ）。
///
/// どちらの方式でも、転送前に「設定」画面で選んだ大きさ・白黒・画質・ファイル形式
/// （JPEG／PNG）を画像に適用する（プリンターの通信量・印刷向けの見た目に合わせて、
/// クラウド保存用の圧縮とは別に調整できるようにするため）。
struct PrinterLinkService {
    enum PrintError: LocalizedError {
        case notConfigured
        case encodingFailed
        case uploadFailed
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "連携プリンターのURLが設定されていません。"
            case .encodingFailed: return "画像の変換に失敗しました。"
            case .uploadFailed: return "写真のアップロードに失敗しました（サインインが必要な場合があります）。"
            case .requestFailed(let reason):
                return "連携プリンターへの送信に失敗しました（\(reason)）。電源・Wi-Fi接続・設定したURLをご確認ください。"
            }
        }
    }

    /// 御朱印の写真を、「設定」画面の連携設定に応じて連携プリンターへ転送する。
    /// 未設定・転送オフの場合は何もしない（撮影・変更のたびに自動で行う分の転送）。
    func printStampPhotoIfEnabled(_ image: UIImage) async {
        guard AppSettings.printerSyncStamps else { return }
        _ = try? await send(image, cloudURL: nil)
    }

    /// 投稿写真を、「設定」画面の連携設定に応じて連携プリンターへ転送する。
    /// 未設定・転送オフの場合は何もしない（投稿のたびに自動で行う分の転送）。
    func printPhotoPostIfEnabled(_ image: UIImage) async {
        guard AppSettings.printerSyncPhotoPosts else { return }
        _ = try? await send(image, cloudURL: nil)
    }

    /// 御朱印一覧・投稿写真プレビューの「連携プリント」ボタンから、その場で1枚だけ
    /// 転送する。自動転送のON/OFF設定（`printerSyncStamps`等）とは関係なく、常に試みる。
    /// - Parameter cloudURL: 既にFirebase Storageへアップロード済みならその公開URL。
    ///   渡しておくと、`photo=`方式のときに転送専用の再アップロードを省略できる。
    func printOnDemand(_ image: UIImage, cloudURL: URL?) async throws {
        try await send(image, cloudURL: cloudURL)
    }

    private func send(_ image: UIImage, cloudURL: URL?) async throws {
        guard let host = AppSettings.printerLinkHost,
              let url = DeviceLinkURL.resolve(from: host, defaultPath: "/print")
        else { throw PrintError.notConfigured }

        let format = AppSettings.printerImageFormat
        let prepared = Self.prepareForPrint(image)
        guard let data = Self.encodedData(prepared, format: format) else { throw PrintError.encodingFailed }

        if let queryPrefix = Self.photoQueryPrefix(in: url.absoluteString) {
            try await sendViaHostedURL(data: data, format: format, queryPrefix: queryPrefix, existingURL: cloudURL)
        } else {
            try await sendViaRequestBody(data: data, format: format, to: url)
        }
    }

    /// 方式1: 画像データをそのままリクエストボディに入れて`POST`する。
    private func sendViaRequestBody(data: Data, format: PrinterImageFormat, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(format.mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.httpBody = data
        request.timeoutInterval = 10
        try await Self.perform(request)
    }

    /// 方式2: 画像を一度Firebase Storageへアップロードし、公開URLを`photo=`の後ろに
    /// 続けたURLへ`GET`する（プリンター自身がそのURLを取得しにいく想定）。
    /// `existingURL`が渡されていれば、既にアップロード済みとしてそれをそのまま使う。
    /// サインインしていない・Firebase未設定でアップロードもできない場合は失敗を投げる。
    private func sendViaHostedURL(data: Data, format: PrinterImageFormat, queryPrefix: String, existingURL: URL?) async throws {
        let resolvedURL: URL?
        if let existingURL {
            resolvedURL = existingURL
        } else {
            resolvedURL = await uploadForHostedPrint(data: data, format: format)
        }
        guard let hostedURL = resolvedURL else { throw PrintError.uploadFailed }
        guard let encodedImageURL = hostedURL.absoluteString.addingPercentEncoding(withAllowedCharacters: Self.urlValueAllowedCharacters),
              let finalURL = URL(string: queryPrefix + encodedImageURL)
        else { throw PrintError.encodingFailed }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 15
        try await Self.perform(request)
    }

    /// 実際にリクエストを送り、通信エラーやプリンター側からの異常応答（2xx以外）を
    /// `requestFailed`にまとめて詰め直す。原因（DNS解決失敗・接続拒否・HTTPステータス等）を
    /// そのままメッセージに含めることで、「送信に失敗しました」とだけ出るのを避け、
    /// ユーザー自身が設定を見直せるようにする。
    ///
    /// - Important: M5Stackなどのごく簡易なHTTPサーバーは、iOS側が接続を使い回そうとする
    ///   （keep-alive）と応答を返す前に接続を切ってしまうことがあり、`URLError
    ///   .networkConnectionLost`（「The network connection was lost」）になりやすい。
    ///   `Connection: close`を付けて使い回しをやめさせた上で、それでも起きた場合は
    ///   一度だけ短い間隔を空けて自動的に再試行する（この種の切断は再試行すると
    ///   ほぼ成功することが多い、iOS側のよく知られた挙動）。
    private static func perform(_ request: URLRequest, isRetry: Bool = false) async throws {
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw PrintError.requestFailed("HTTPステータス \(http.statusCode)")
            }
        } catch let error as PrintError {
            throw error
        } catch let error as URLError where error.code == .networkConnectionLost && !isRetry {
            try? await Task.sleep(nanoseconds: 400_000_000)
            try await perform(request, isRetry: true)
        } catch {
            throw PrintError.requestFailed(error.localizedDescription)
        }
    }

    /// `users/{uid}/printerTransfers/` 配下へ一時的にアップロードし、ダウンロードURLを返す。
    /// 御朱印・投稿写真本体のクラウド保存（`SyncService`）とは別に、連携プリンターへ
    /// 渡すためだけの独立したアップロードとして扱う。
    private func uploadForHostedPrint(data: Data, format: PrinterImageFormat) async -> URL? {
        guard FirebaseApp.app() != nil, let uid = Auth.auth().currentUser?.uid else { return nil }

        let metadata = StorageMetadata()
        metadata.contentType = format.mimeType
        let ref = Storage.storage().reference()
            .child("users/\(uid)/printerTransfers/\(UUID().uuidString).\(format.fileExtension)")
        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            return try await ref.downloadURL()
        } catch {
            return nil
        }
    }

    /// 設定されたURLの文字列に`photo=`が含まれていれば、そこまで（`photo=`を含む）を
    /// 返す。含まれていなければ`nil`（＝方式1のリクエストボディ転送）。
    private static func photoQueryPrefix(in absoluteURLString: String) -> String? {
        guard let range = absoluteURLString.range(of: "photo=", options: .caseInsensitive) else { return nil }
        return String(absoluteURLString[..<range.upperBound])
    }

    /// URLの値としてクエリに埋め込むため、RFC3986の非予約文字以外はすべて
    /// パーセントエンコードする（`/`や`?`、Firebase StorageのURLに含まれる
    /// `&`・`=`まで含めて確実にエスケープしないと、外側のクエリと混ざってしまうため）。
    private static let urlValueAllowedCharacters: CharacterSet = {
        CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    }()

    private static func encodedData(_ image: UIImage, format: PrinterImageFormat) -> Data? {
        switch format {
        case .jpg:
            return image.jpegData(compressionQuality: AppSettings.printerImageQuality.jpegQuality)
        case .png:
            return image.pngData()
        }
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
