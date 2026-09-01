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
    func upload(_ image: UIImage, path: String) async throws -> URL {
        guard let storage else { throw StorageServiceError.firebaseNotConfigured }
        guard let data = Self.compressedJPEGData(image) else { throw StorageServiceError.compressionFailed }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let ref = storage.reference().child(path)
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }

    /// アップロード済みの画像を削除する（写真の差し替え・削除、共有解除時に使う）。
    func delete(path: String) async {
        guard let storage else { return }
        try? await storage.reference().child(path).delete()
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
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
