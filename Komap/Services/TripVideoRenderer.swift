import AVFoundation
import UIKit

/// 動画の途中で足を止めて写真を見せる地点1件分。
struct TripVideoStop {
    /// `TripVideoRenderer.render`の`points`（軌跡）のうち、この写真に最も近い点の番号。
    let pointIndex: Int
    let photo: UIImage
    let caption: String?
}

enum TripVideoError: LocalizedError {
    case invalidInput
    case writerFailed

    var errorDescription: String? {
        switch self {
        case .invalidInput: return "動画にできる軌跡がありませんでした。"
        case .writerFailed: return "動画の作成に失敗しました。"
        }
    }
}

/// 歩いた軌跡の上をアイコンが進み、写真を撮った地点で写真を見せる動画（MP4）を書き出す。
///
/// 背景は、画面に表示中の地図をスナップショットした画像（古地図・チェックポイントを含む）で、
/// その上に「ここまで歩いた道」とアイコンを1フレームずつ描いて`AVAssetWriter`で繋ぐ。
enum TripVideoRenderer {
    private static let outputWidth: CGFloat = 720
    private static let framesPerSecond: Int32 = 30
    /// 軌跡の始点から終点まで進むのにかける秒数（写真で止まっている時間は含まない）。
    private static let travelSeconds: Double = 8
    private static let photoHoldSeconds: Double = 2.6
    private static let photoFadeSeconds: Double = 0.35
    private static let endHoldSeconds: Double = 1.5

    private enum Segment {
        case move(from: CGFloat, to: CGFloat, frames: Int)
        case hold(stop: TripVideoStop?, distance: CGFloat, frames: Int)
    }

    /// - Parameters:
    ///   - base: 背景の地図画像。
    ///   - points: 軌跡を`base`上の座標（ポイント単位）にしたもの。
    ///   - stops: 写真を見せる地点（`pointIndex`の昇順でなくてよい）。
    static func render(base: UIImage, points: [CGPoint], stops: [TripVideoStop]) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try renderSync(base: base, points: points, stops: stops)
        }.value
    }

    private static func renderSync(base: UIImage, points rawPoints: [CGPoint], stops rawStops: [TripVideoStop]) throws -> URL {
        guard rawPoints.count >= 2, base.size.width > 0, base.size.height > 0 else { throw TripVideoError.invalidInput }

        let scale = outputWidth / base.size.width
        let width = Int(outputWidth)
        let height = Int((base.size.height * scale / 2).rounded()) * 2 // H.264は偶数サイズ
        let canvas = CGSize(width: width, height: height)
        let points = rawPoints.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }

        // 各点までの累積距離
        var cumulative: [CGFloat] = [0]
        for i in 1..<points.count {
            cumulative.append(cumulative[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))
        }
        let total = max(cumulative.last ?? 0, 1)

        let fps = Int(framesPerSecond)
        let stops = rawStops
            .filter { points.indices.contains($0.pointIndex) }
            .sorted { $0.pointIndex < $1.pointIndex }

        var segments: [Segment] = []
        var cursor: CGFloat = 0
        for stop in stops {
            let distance = cumulative[stop.pointIndex]
            let moveFrames = max(Int(Double(fps) * travelSeconds * Double((distance - cursor) / total)), 0)
            if moveFrames > 0 { segments.append(.move(from: cursor, to: distance, frames: moveFrames)) }
            segments.append(.hold(stop: stop, distance: distance, frames: Int(photoHoldSeconds * Double(fps))))
            cursor = distance
        }
        let lastFrames = max(Int(Double(fps) * travelSeconds * Double((total - cursor) / total)), 0)
        if lastFrames > 0 { segments.append(.move(from: cursor, to: total, frames: lastFrames)) }
        segments.append(.hold(stop: nil, distance: total, frames: Int(endHoldSeconds * Double(fps))))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("komap-trip-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        guard writer.canAdd(input) else { throw TripVideoError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw TripVideoError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        var frameIndex: Int64 = 0
        func append(distance: CGFloat, photo: (stop: TripVideoStop, alpha: CGFloat, progress: CGFloat)?) throws {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            guard let pool = adaptor.pixelBufferPool else { throw TripVideoError.writerFailed }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw TripVideoError.writerFailed }
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { throw TripVideoError.writerFailed }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(context)
            drawFrame(base: base, canvas: canvas, points: points, cumulative: cumulative, distance: distance, photo: photo)
            UIGraphicsPopContext()
            let time = CMTime(value: frameIndex, timescale: framesPerSecond)
            guard adaptor.append(buffer, withPresentationTime: time) else { throw TripVideoError.writerFailed }
            frameIndex += 1
        }

        for segment in segments {
            switch segment {
            case let .move(from, to, frames):
                for f in 0..<frames {
                    let t = CGFloat(f + 1) / CGFloat(frames)
                    try append(distance: from + (to - from) * t, photo: nil)
                }
            case let .hold(stop, distance, frames):
                let fade = max(Int(photoFadeSeconds * Double(fps)), 1)
                for f in 0..<frames {
                    guard let stop else {
                        try append(distance: distance, photo: nil)
                        continue
                    }
                    let alpha = min(1, CGFloat(f + 1) / CGFloat(fade), CGFloat(frames - f) / CGFloat(fade))
                    try append(distance: distance, photo: (stop, alpha, CGFloat(f) / CGFloat(max(frames - 1, 1))))
                }
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()
        guard writer.status == .completed else { throw writer.error ?? TripVideoError.writerFailed }
        return url
    }

    // MARK: - 1フレームの描画

    private static func drawFrame(
        base: UIImage,
        canvas: CGSize,
        points: [CGPoint],
        cumulative: [CGFloat],
        distance: CGFloat,
        photo: (stop: TripVideoStop, alpha: CGFloat, progress: CGFloat)?
    ) {
        base.draw(in: CGRect(origin: .zero, size: canvas))

        // ここまで歩いた道
        var current = points[0]
        let walked = UIBezierPath()
        walked.move(to: points[0])
        for i in 1..<points.count {
            if cumulative[i] <= distance {
                walked.addLine(to: points[i])
                current = points[i]
            } else {
                let span = max(cumulative[i] - cumulative[i - 1], 0.0001)
                let t = (distance - cumulative[i - 1]) / span
                current = CGPoint(
                    x: points[i - 1].x + (points[i].x - points[i - 1].x) * t,
                    y: points[i - 1].y + (points[i].y - points[i - 1].y) * t
                )
                walked.addLine(to: current)
                break
            }
        }
        walked.lineCapStyle = .round
        walked.lineJoinStyle = .round
        UIColor.white.withAlphaComponent(0.9).setStroke()
        walked.lineWidth = 11
        walked.stroke()
        UIColor.liveWalkedTrailBorder.setStroke()
        walked.lineWidth = 8
        walked.stroke()

        drawIcon(at: current)

        if let photo {
            drawPhotoCard(photo.stop, alpha: photo.alpha, progress: photo.progress, canvas: canvas, iconAt: current)
            // 写真の間も、いま進んでいる地点が見えるよう、アイコンを写真より前に描き直し、
            // 波紋を広げて目立たせる。
            drawPulse(at: current, progress: photo.progress, alpha: photo.alpha)
            drawIcon(at: current)
        }
    }

    private static func drawIcon(at point: CGPoint) {
        let radius: CGFloat = 18
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: rect.insetBy(dx: -3, dy: -3)).fill()
        UIColor.liveWalkedTrailBorder.setFill()
        UIBezierPath(ovalIn: rect).fill()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        if let symbol = UIImage(systemName: "figure.walk", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let size = symbol.size
            symbol.draw(in: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height))
        }
    }

    /// 進んでいる地点（アイコン）の周りに広がる波紋。
    private static func drawPulse(at point: CGPoint, progress: CGFloat, alpha: CGFloat) {
        for ring in 0..<2 {
            let phase = (progress * 3 + CGFloat(ring) * 0.5).truncatingRemainder(dividingBy: 1)
            let radius = 22 + phase * 34
            UIColor.liveWalkedTrailBorder.withAlphaComponent((1 - phase) * 0.7 * alpha).setStroke()
            let path = UIBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            path.lineWidth = 4
            path.stroke()
        }
    }

    /// 少し暗くした背景の上に、白い縁取りの写真カード（と名前）をふわっと表示する。
    /// 写真は大きく、しかも動いているポイント（アイコン）に重ならないよう、アイコンから遠い側
    /// （画面の上下のうち広く空いている方）へずらして置く。
    private static func drawPhotoCard(
        _ stop: TripVideoStop, alpha: CGFloat, progress: CGFloat, canvas: CGSize, iconAt icon: CGPoint
    ) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer { context.restoreGState() }

        UIColor.black.withAlphaComponent(0.25 * alpha).setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: canvas)).fill()

        let margin: CGFloat = 12
        let gapFromIcon: CGFloat = 44
        let spaceAbove = icon.y - gapFromIcon - margin
        let spaceBelow = canvas.height - icon.y - gapFromIcon - margin
        let placeBelow = spaceBelow >= spaceAbove
        let availableHeight = max(placeBelow ? spaceBelow : spaceAbove, canvas.height * 0.3)

        let border: CGFloat = 8
        let captionHeight: CGFloat = stop.caption == nil ? 0 : 44
        let maxPhoto = CGSize(
            width: canvas.width * 0.98 - border * 2,
            height: min(availableHeight, canvas.height * 0.72) - border * 2 - captionHeight
        )
        let fit = min(maxPhoto.width / stop.photo.size.width, maxPhoto.height / stop.photo.size.height)
        let photoSize = CGSize(width: stop.photo.size.width * fit, height: stop.photo.size.height * fit)
        let cardSize = CGSize(
            width: photoSize.width + border * 2,
            height: photoSize.height + border * 2 + captionHeight
        )

        // アイコンの反対側の端に寄せて置く（中央からずらす）。
        let centerY: CGFloat = placeBelow
            ? canvas.height - margin - cardSize.height / 2
            : margin + cardSize.height / 2
        let center = CGPoint(x: canvas.width / 2, y: centerY)

        // ゆっくり少し拡大しながら表示する。
        let zoom = 0.94 + 0.06 * progress
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: zoom, y: zoom)
        context.translateBy(x: -cardSize.width / 2, y: -cardSize.height / 2)
        context.setAlpha(alpha)

        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.4).cgColor)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: cardSize), cornerRadius: 6).fill()
        context.setShadow(offset: .zero, blur: 0, color: nil)

        stop.photo.draw(in: CGRect(x: border, y: border, width: photoSize.width, height: photoSize.height))

        if let caption = stop.caption {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byTruncatingTail
            (caption as NSString).draw(
                in: CGRect(x: border, y: photoSize.height + border + 10, width: photoSize.width, height: captionHeight - 10),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                    .foregroundColor: UIColor(white: 0.2, alpha: 1),
                    .paragraphStyle: style,
                ]
            )
        }
    }
}
