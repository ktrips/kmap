import UIKit

/// 御朱印チェックインに添える写真を、端末のApplication Supportディレクトリへ
/// JPEGとして保存・読み込みする。
///
/// SwiftDataのレコードには画像そのものではなくファイル名だけを持たせることで、
/// データベースを肥大化させずに済む。保存前にスマートフォンの画面で十分きれいに
/// 見える範囲までリサイズ・圧縮し、ファイルサイズを抑える。
enum StampPhotoStore {
    /// この長辺を超える画像は縮小する（Retinaディスプレイでも十分な解像度）。
    private static let maxDimension: CGFloat = 1600
    private static let jpegQuality: CGFloat = 0.7

    private static var directoryURL: URL {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StampPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// `load(_:)`はSwiftUIの再描画のたびに呼ばれうるため、毎回ディスクから読み直して
    /// JPEGをデコードし直すと重い。直近に読んだ分だけメモリ上に持っておく。
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        return cache
    }()

    /// 画像を縮小・圧縮して保存し、保存先のファイル名を返す（失敗時は`nil`）。
    static func save(_ image: UIImage) -> String? {
        guard let data = compress(image) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directoryURL.appendingPathComponent(filename))
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String) -> UIImage? {
        let key = filename as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let data = try? Data(contentsOf: directoryURL.appendingPathComponent(filename)),
              let image = UIImage(data: data)
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// 差し替え時などに古いファイルを削除する。
    static func delete(_ filename: String) {
        cache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent(filename))
    }

    private static func compress(_ image: UIImage) -> Data? {
        resized(image, maxDimension: maxDimension).jpegData(compressionQuality: jpegQuality)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longerSide = max(image.size.width, image.size.height)
        guard longerSide > maxDimension else { return image }

        let scale = maxDimension / longerSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
