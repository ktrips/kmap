import FirebaseCore
import FirebaseStorage
import UIKit

/// 御朱印・投稿写真の画像本体をFirebase Storageへアップロードし、
/// Webアプリからも見られる（共有した場合は他ユーザーからも見られる）ようにする。
///
/// アップロード前に、スマートフォンできれいに見える範囲まで縮小・圧縮してから送る
/// （元画像のまま送るとサイズが大きく、通信量・保存容量を無駄に消費するため）。
struct PhotoStorageService {
    enum StorageServiceError: LocalizedError {
        case firebaseNotConfigured
        case compressionFailed

        var errorDescription: String? {
            switch self {
            case .firebaseNotConfigured:
                return "Firebaseが設定されていないため、写真のクラウド保存は利用できません。"
            case .compressionFailed:
                return "画像の圧縮に失敗しました。"
            }
        }
    }

    /// スマートフォンの画面で十分きれいに見える上限サイズ・画質。
    private static let maxDimension: CGFloat = 1600
    private static let jpegQuality: CGFloat = 0.72

    private var storage: Storage? {
        guard FirebaseApp.app() != nil else { return nil }
        return Storage.storage()
    }

    /// 画像を圧縮してアップロードし、ダウンロードURLを返す。
    ///
    /// - Important: 呼び出し元（SwiftUIのView）は`@MainActor`のことが多く、この関数の
    ///   最初の`await`より前のコードはそのまま呼び出し元のスレッドで動いてしまう。
    ///   リサイズ・JPEG圧縮は軽くないため、`Task.detached`で明示的にバックグラウンドへ
    ///   逃がしてからアップロードする（メインスレッドを塞いでクラッシュに見える
    ///   強制終了を招かないため）。
    func upload(_ image: UIImage, path: String) async throws -> URL {
        guard let storage else { throw StorageServiceError.firebaseNotConfigured }
        guard let data = await Task.detached(priority: .userInitiated, operation: { Self.compressedJPEGData(image) }).value
        else { throw StorageServiceError.compressionFailed }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let ref = storage.reference().child(path)
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }

    /// 動画ファイル（MP4）をアップロードし、共有できるダウンロードURLを返す。
    func uploadVideo(fileURL: URL, path: String) async throws -> URL {
        guard let storage else { throw StorageServiceError.firebaseNotConfigured }
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        let ref = storage.reference().child(path)
        _ = try await ref.putFileAsync(from: fileURL, metadata: metadata)
        return try await ref.downloadURL()
    }

    /// アップロード済みの画像を削除する（写真の差し替え・削除、共有解除時に使う）。
    func delete(path: String) async {
        guard let storage else { return }
        try? await storage.reference().child(path).delete()
    }

    /// 指定したフォルダ配下の画像をすべて削除する。「みんなの時空旅」への公開を
    /// 取り消した時、コピーしておいた共有写真を残さず消すために使う。
    func deleteFolder(_ path: String) async {
        guard let storage else { return }
        guard let result = try? await storage.reference().child(path).listAll() else { return }
        for item in result.items {
            try? await item.delete()
        }
    }

    /// 自分の画像（`users/{uid}/...`）を、みんなの時空旅で見られる公開パスへコピーする。
    func copyToShared(from sourcePath: String, to destinationPath: String) async throws -> URL {
        guard let storage else { throw StorageServiceError.firebaseNotConfigured }
        let sourceRef = storage.reference().child(sourcePath)
        let data = try await sourceRef.data(maxSize: 15 * 1024 * 1024)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let destRef = storage.reference().child(destinationPath)
        _ = try await destRef.putDataAsync(data, metadata: metadata)
        return try await destRef.downloadURL()
    }

    /// スマートフォンで十分きれいに見える範囲（長辺1600px・JPEG品質72%程度）まで圧縮する。
    static func compressedJPEGData(_ image: UIImage) -> Data? {
        resized(image, maxDimension: maxDimension).jpegData(compressionQuality: jpegQuality)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        // `format.scale`を指定しないと端末の画面スケール（3倍機なら3倍）で描かれ、
        // 1600pxに縮小したつもりが最大4800pxの巨大な画像になってしまう
        // （元より大きくなることもあった）。実ピクセル数で縮小するため1にする。
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
