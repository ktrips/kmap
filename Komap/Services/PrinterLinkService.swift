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
/// 「設定」画面にはプリンターのホスト名／IP（例: "m5web.local"）だけを入力する。
/// パスはこのアプリ側で以下の固定APIとして組み立てる。
/// 1. 直接送信（`multipart/form-data`でのPOST）:
///    `POST http://<ホスト>/api/print/photo` に、フィールド名`photo`として
///    画像ファイル本体を`-F "photo=@image.jpg"`と同じ形で送る。
/// 2. URLで渡す（GET）:
///    画像を一度Firebase Storageへアップロードし、
///    `GET http://<ホスト>/api/print/photo/url?url=<画像のURL>` を呼ぶ
///    （プリンター側が渡された`url`を自分で取得しにいくタイプ）。
///
/// どちらの方式を使うかは「設定」画面の「転送方式」で選ぶ（既定は方式1）。
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
              let base = Self.hostBase(from: host)
        else { throw PrintError.notConfigured }

        let format = AppSettings.printerImageFormat
        let prepared = Self.prepareForPrint(image)
        guard let data = Self.encodedData(prepared, format: format) else { throw PrintError.encodingFailed }

        switch AppSettings.printerTransferMode {
        case .direct:
            try await sendViaMultipartPOST(data: data, format: format, base: base)
        case .hostedURL:
            try await sendViaHostedURL(data: data, format: format, base: base, existingURL: cloudURL)
        }
    }

    /// 方式1: `POST <base>/api/print/photo` へ、フィールド名`photo`の
    /// `multipart/form-data`として画像ファイル本体を送る
    /// （`-F "photo=@image.jpg"`と同じ形）。
    private func sendViaMultipartPOST(data: Data, format: PrinterImageFormat, base: String) async throws {
        guard let url = URL(string: base + "/api/print/photo") else { throw PrintError.encodingFailed }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")
        // URLSessionはボディ付きPOSTに自動で`Expect: 100-continue`を付けることがあるが、
        // M5Stack/ESP32系のごく簡易なHTTPサーバーはこれに正しく応答できず、
        // サーバー側が接続を切ってしまい`networkConnectionLost`の原因になることが多い。
        // 「Expect」ヘッダーを（空でも）自分で明示しておくと、URLSessionは自動付与を
        // 行わなくなるため、これを付けて回避する。
        request.setValue("", forHTTPHeaderField: "Expect")
        request.httpBody = Self.multipartBody(data: data, format: format, fieldName: "photo", boundary: boundary)
        // サーマルプリンターなどは、実際に印刷し終えるまで応答を返さない
        // （同期処理の）実装になっていることが多く、印刷自体に数十秒かかることもあるため、
        // 通常のAPI通信より長めのタイムアウトを取る。
        request.timeoutInterval = 60
        try await Self.perform(request)
    }

    /// `multipart/form-data`のリクエストボディを組み立てる。
    private static func multipartBody(data: Data, format: PrinterImageFormat, fieldName: String, boundary: String) -> Data {
        var body = Data()
        let filename = "photo.\(format.fileExtension)"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(format.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    /// 方式2: 画像を一度Firebase Storageへアップロードし、
    /// `GET <base>/api/print/photo/url?url=<画像のURL>` を呼ぶ
    /// （プリンター自身が渡された`url`を取得しにいく想定）。
    /// `existingURL`が渡されていれば、既にアップロード済みとしてそれをそのまま使う。
    /// サインインしていない・Firebase未設定でアップロードもできない場合は失敗を投げる。
    private func sendViaHostedURL(data: Data, format: PrinterImageFormat, base: String, existingURL: URL?) async throws {
        let resolvedURL: URL?
        if let existingURL {
            resolvedURL = existingURL
        } else {
            resolvedURL = await uploadForHostedPrint(data: data, format: format)
        }
        guard let hostedURL = resolvedURL else { throw PrintError.uploadFailed }
        guard let encodedImageURL = hostedURL.absoluteString.addingPercentEncoding(withAllowedCharacters: Self.urlValueAllowedCharacters),
              let finalURL = URL(string: base + "/api/print/photo/url?url=" + encodedImageURL)
        else { throw PrintError.encodingFailed }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("close", forHTTPHeaderField: "Connection")
        // 方式1と同様、プリンター側が画像の取得＋印刷を終えるまで応答しない
        // 実装を想定し、長めのタイムアウトを取る。
        request.timeoutInterval = 60
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

    /// 設定欄の入力から、スキーム＋ホスト＋ポートだけを取り出す（パス・クエリは
    /// すべて捨てる）。API仕様の変更前に保存された古い値（例:
    /// "http://m5web.local/api/print?photo="）が端末に残っていても、パス部分は
    /// 無視して確実にホストだけを使うようにするため、単純な文字列結合ではなく
    /// `URLComponents`で一度分解してから組み立て直す。
    private static func hostBase(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = (trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://"))
            ? trimmed
            : "http://\(trimmed)"
        guard let components = URLComponents(string: withScheme), let host = components.host, !host.isEmpty else { return nil }

        var base = "\(components.scheme ?? "http")://\(host)"
        if let port = components.port {
            base += ":\(port)"
        }
        return base
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
