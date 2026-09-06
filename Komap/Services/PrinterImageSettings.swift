import Foundation

/// 連携プリンターへ転送する画像の大きさ（＝データ量）のプリセット。
enum PrinterImageSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    /// 長辺をこのピクセル数までに縮小してから転送する。
    var maxDimension: CGFloat {
        switch self {
        case .small: return 640
        case .medium: return 1024
        case .large: return 1600
        }
    }

    var title: String {
        switch self {
        case .small: return "小（640px・データ量小）"
        case .medium: return "中（1024px）"
        case .large: return "大（1600px・高画質）"
        }
    }
}

/// 連携プリンターへ転送する画像のJPEG圧縮率のプリセット。
enum PrinterImageQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var jpegQuality: CGFloat {
        switch self {
        case .low: return 0.4
        case .medium: return 0.72
        case .high: return 0.92
        }
    }

    var title: String {
        switch self {
        case .low: return "低（データ量小）"
        case .medium: return "標準"
        case .high: return "高（データ量大）"
        }
    }
}

/// 連携プリンターへ転送する画像ファイルのフォーマット。
enum PrinterImageFormat: String, CaseIterable, Identifiable {
    case jpg
    case png

    var id: String { rawValue }

    /// URL経由で転送する場合の拡張子・Content-Typeにそのまま使う。
    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        }
    }

    var mimeType: String {
        switch self {
        case .jpg: return "image/jpeg"
        case .png: return "image/png"
        }
    }

    var title: String {
        switch self {
        case .jpg: return "JPEG（.jpg）"
        case .png: return "PNG（.png・可逆圧縮）"
        }
    }
}
