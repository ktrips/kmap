import ImageIO
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

    /// 一覧・サムネイル用の縮小画像のキャッシュ（`thumbnail(_:)`）。
    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()

    /// 一覧の小さなサムネイル用に、ファイルから直接縮小して読み込む。
    /// 1600px級の写真を丸ごとデコードして小さく表示するのは無駄が大きいため、
    /// ImageIOで必要なサイズ（長辺`maxDimension`px）だけをデコードし、結果はキャッシュする。
    static func thumbnail(_ filename: String, maxDimension: CGFloat = 320) -> UIImage? {
        let key = "\(filename)#\(Int(maxDimension))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        let url = directoryURL.appendingPathComponent(filename)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    private static let migrationKey = "stampPhotosResizedV1"

    /// 以前のバージョンでは、縮小した写真が端末の画面スケール分（3倍機なら最大4800px）の
    /// 巨大な画像として保存されていた。保存済みの大きな写真を、一度だけ長辺1600pxに
    /// 縮小し直して上書きする（読み込み・表示・メモリが軽くなる）。バックグラウンドで実行する。
    static func migrateOversizedPhotosIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension.lowercased() == "jpg" {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                  let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
                  max(width, height) > maxDimension * 1.05,
                  let image = UIImage(contentsOfFile: url.path),
                  let data = compress(image)
            else { continue }
            try? data.write(to: url)
            cache.removeObject(forKey: url.lastPathComponent as NSString)
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

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
