import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// 撮影・追加した写真に適用する簡単な画像加工のスタイル。
/// 「設定」画面で選んだものが、御朱印・投稿写真を追加するたびに自動で適用される。
enum PhotoFilterStyle: String, CaseIterable, Identifiable {
    case none
    case vivid
    case sepia
    case vintage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "なし"
        case .vivid: return "鮮やか"
        case .sepia: return "セピア"
        case .vintage: return "ビンテージ風"
        }
    }

    /// `CIContext`はGPUコンテキストの初期化コストが大きいため、呼び出しのたびに
    /// 作り直さず使い回す。
    private static let context = CIContext()

    /// 設定された加工を画像に適用する。`.none`の場合や加工に失敗した場合は元の画像をそのまま返す。
    func apply(to image: UIImage) -> UIImage {
        guard self != .none, let ciImage = CIImage(image: image) else { return image }

        let output: CIImage?
        switch self {
        case .none:
            output = ciImage
        case .vivid:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = 1.45
            filter.contrast = 1.08
            filter.brightness = 0.02
            output = filter.outputImage
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = ciImage
            filter.intensity = 0.85
            output = filter.outputImage
        case .vintage:
            // 色あせた質感（CIPhotoEffectTransfer）に、周辺を少し暗くする
            // ビネットを重ねて「古い写真」らしい見た目にする。
            let transfer = CIFilter.photoEffectTransfer()
            transfer.inputImage = ciImage
            let vignette = CIFilter.vignette()
            vignette.inputImage = transfer.outputImage ?? ciImage
            vignette.intensity = 0.9
            vignette.radius = 1.6
            output = vignette.outputImage
        }

        guard let output, let cgImage = Self.context.createCGImage(output, from: ciImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
