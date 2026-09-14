import UIKit

/// 歩いている時、地図上に表示する「自分の現在地」マークの見た目。
/// 「設定」画面で選んだものが、地図画面ですぐ反映される。
enum CurrentLocationIconStyle: String, CaseIterable, Identifiable, Equatable {
    /// Google純正の「青い点」に似せた、標準的な青い丸。
    case blueDot
    /// 菅笠をかぶった、昔の旅人風のアイコン。
    case travelerHat
    /// 髷を結った、昔の侍風のアイコン。
    case samurai
    /// 現代の歩行者アイコン（SF Symbolsの人物アイコン）。
    case modernPerson

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blueDot: return "青い丸（標準）"
        case .travelerHat: return "旅人（菅笠）"
        case .samurai: return "侍"
        case .modernPerson: return "現代人"
        }
    }

    /// 現在地マークのアイコンを生成する。`emphasized`（歩行記録中）は一回り大きくする。
    ///
    /// - Note: チェックポイント（御朱印）のマーカーは朱色系の縦長ピン（`GMSMarker.markerImage(with: .shuiro)`）
    ///   で、ここで作るどの現在地マークとも形・色が異なるため混同しない。
    func icon(emphasized: Bool) -> UIImage {
        switch self {
        case .blueDot:
            return Self.blueDotIcon(emphasized: emphasized)
        case .travelerHat:
            return Self.badgeIcon(emphasized: emphasized, backgroundColor: UIColor(red: 0.98, green: 0.91, blue: 0.78, alpha: 1)) { cg, rect in
                Self.drawTravelerGlyph(in: cg, rect: rect)
            }
        case .samurai:
            return Self.badgeIcon(emphasized: emphasized, backgroundColor: UIColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1)) { cg, rect in
                Self.drawSamuraiGlyph(in: cg, rect: rect)
            }
        case .modernPerson:
            return Self.badgeIcon(emphasized: emphasized, backgroundColor: UIColor.systemTeal) { cg, rect in
                Self.drawModernPersonGlyph(in: cg, rect: rect)
            }
        }
    }

    /// 青い円＋白い縁取り。歩行記録中（`emphasized`）は一回り大きく、
    /// 外側にもう一段リングを足してさらに目立たせる（従来の現在地マークと同じ見た目）。
    private static func blueDotIcon(emphasized: Bool) -> UIImage {
        let diameter: CGFloat = emphasized ? 40 : 26
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { context in
            let cg = context.cgContext
            let center = CGPoint(x: diameter / 2, y: diameter / 2)

            if emphasized {
                let outerRadius = diameter / 2 - 1
                cg.setFillColor(UIColor.systemBlue.withAlphaComponent(0.22).cgColor)
                cg.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                cg.fillPath()
            }

            let dotDiameter: CGFloat = emphasized ? 26 : 20
            let dotRect = CGRect(
                x: center.x - dotDiameter / 2,
                y: center.y - dotDiameter / 2,
                width: dotDiameter,
                height: dotDiameter
            )
            cg.setFillColor(UIColor.white.cgColor)
            cg.addEllipse(in: dotRect)
            cg.fillPath()

            let innerInset: CGFloat = 3.5
            let innerRect = dotRect.insetBy(dx: innerInset, dy: innerInset)
            cg.setFillColor(UIColor.systemBlue.cgColor)
            cg.addEllipse(in: innerRect)
            cg.fillPath()
        }
    }

    /// 白い縁取りつきの円形バッジの中に、`drawGlyph`で人物シルエットを描く共通の土台。
    /// 「青い丸」と大きさ・縁取りの見た目を揃えることで、地図上での視認性を統一する。
    private static func badgeIcon(
        emphasized: Bool,
        backgroundColor: UIColor,
        drawGlyph: (CGContext, CGRect) -> Void
    ) -> UIImage {
        let diameter: CGFloat = emphasized ? 44 : 30
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { context in
            let cg = context.cgContext
            let fullRect = CGRect(x: 0, y: 0, width: diameter, height: diameter)

            // 白い縁取り（「青い丸」と同じく、地図の色に埋もれないようにするため）。
            cg.setFillColor(UIColor.white.cgColor)
            cg.addEllipse(in: fullRect)
            cg.fillPath()

            let badgeInset: CGFloat = 2.5
            let badgeRect = fullRect.insetBy(dx: badgeInset, dy: badgeInset)
            cg.setFillColor(backgroundColor.cgColor)
            cg.addEllipse(in: badgeRect)
            cg.fillPath()

            let glyphInset = badgeRect.width * 0.22
            let glyphRect = badgeRect.insetBy(dx: glyphInset, dy: glyphInset)
            drawGlyph(cg, glyphRect)
        }
    }

    /// アニメ風の大きな瞳（白目＋色付きの虹彩＋瞳孔＋2つのきらめきハイライト＋まつ毛）・
    /// 頬の赤み・小さな笑顔を共通で描く（`travelerHat`／`samurai`どちらのキャラも、
    /// これで「アニメっぽい可愛さ」を出す）。`irisColor`でキャラごとに瞳の色を変えられる。
    private static func drawChibiFace(in cg: CGContext, faceRect: CGRect, irisColor: UIColor) {
        let lineColor = UIColor(red: 0.14, green: 0.11, blue: 0.10, alpha: 1)
        let blushColor = UIColor(red: 1.0, green: 0.55, blue: 0.59, alpha: 0.6)

        let eyeWidth = faceRect.width * 0.24
        let eyeHeight = faceRect.height * 0.30
        let eyeY = faceRect.minY + faceRect.height * 0.52
        let lineWidth = max(faceRect.width * 0.014, 0.6)

        for dx: CGFloat in [-0.26, 0.26] {
            let cx = faceRect.midX + faceRect.width * dx
            let eyeRect = CGRect(x: cx - eyeWidth / 2, y: eyeY - eyeHeight / 2, width: eyeWidth, height: eyeHeight)

            // 白目（縁取りつき）。
            cg.setFillColor(UIColor.white.cgColor)
            cg.addEllipse(in: eyeRect)
            cg.fillPath()
            cg.setStrokeColor(lineColor.cgColor)
            cg.setLineWidth(lineWidth)
            cg.addEllipse(in: eyeRect)
            cg.strokePath()

            // 虹彩（少し上寄り）と瞳孔。
            let irisDiameter = eyeHeight * 0.86
            let irisCenter = CGPoint(x: cx, y: eyeY - eyeHeight * 0.03)
            cg.setFillColor(irisColor.cgColor)
            cg.addEllipse(in: CGRect(
                x: irisCenter.x - irisDiameter / 2, y: irisCenter.y - irisDiameter / 2,
                width: irisDiameter, height: irisDiameter
            ))
            cg.fillPath()
            let pupilDiameter = irisDiameter * 0.5
            cg.setFillColor(lineColor.cgColor)
            cg.addEllipse(in: CGRect(
                x: irisCenter.x - pupilDiameter / 2, y: irisCenter.y - pupilDiameter / 2,
                width: pupilDiameter, height: pupilDiameter
            ))
            cg.fillPath()

            // きらめきのハイライトを2つ（大小）入れて、アニメ絵らしい潤んだ瞳にする。
            cg.setFillColor(UIColor.white.cgColor)
            let hi1Diameter = irisDiameter * 0.32
            cg.addEllipse(in: CGRect(
                x: irisCenter.x - irisDiameter * 0.26 - hi1Diameter / 2,
                y: irisCenter.y - irisDiameter * 0.28 - hi1Diameter / 2,
                width: hi1Diameter, height: hi1Diameter
            ))
            cg.fillPath()
            let hi2Diameter = irisDiameter * 0.16
            cg.addEllipse(in: CGRect(
                x: irisCenter.x + irisDiameter * 0.16 - hi2Diameter / 2,
                y: irisCenter.y + irisDiameter * 0.14 - hi2Diameter / 2,
                width: hi2Diameter, height: hi2Diameter
            ))
            cg.fillPath()

            // 目尻の短いまつ毛。
            cg.setStrokeColor(lineColor.cgColor)
            cg.setLineWidth(lineWidth * 1.4)
            cg.setLineCap(.round)
            let lashStart = CGPoint(x: eyeRect.minX + eyeWidth * 0.06, y: eyeRect.minY + eyeHeight * 0.08)
            cg.move(to: lashStart)
            cg.addLine(to: CGPoint(x: lashStart.x - eyeWidth * 0.16, y: lashStart.y - eyeHeight * 0.22))
            cg.strokePath()
        }

        let blushDiameter = faceRect.width * 0.17
        let blushY = eyeY + faceRect.height * 0.21
        cg.setFillColor(blushColor.cgColor)
        for dx: CGFloat in [-0.42, 0.42] {
            let blushRect = CGRect(
                x: faceRect.midX + faceRect.width * dx - blushDiameter / 2,
                y: blushY - blushDiameter / 2,
                width: blushDiameter,
                height: blushDiameter
            )
            cg.addEllipse(in: blushRect)
        }
        cg.fillPath()

        // 小さな笑顔（口）。
        let mouthWidth = faceRect.width * 0.17
        let mouthY = blushY + faceRect.height * 0.10
        cg.setStrokeColor(lineColor.cgColor)
        cg.setLineWidth(max(faceRect.width * 0.04, 0.8))
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: faceRect.midX - mouthWidth / 2, y: mouthY))
        cg.addQuadCurve(
            to: CGPoint(x: faceRect.midX + mouthWidth / 2, y: mouthY),
            control: CGPoint(x: faceRect.midX, y: mouthY + faceRect.height * 0.10)
        )
        cg.strokePath()
    }

    /// 菅笠（円錐形の笠）をかぶった、アニメ風の大きな瞳が可愛い旅人。
    private static func drawTravelerGlyph(in cg: CGContext, rect: CGRect) {
        let hatColor = UIColor(red: 0.90, green: 0.73, blue: 0.43, alpha: 1)
        let hatRimColor = UIColor(red: 0.77, green: 0.58, blue: 0.29, alpha: 1)
        let hatTipColor = UIColor(red: 0.89, green: 0.47, blue: 0.43, alpha: 1)
        let skinColor = UIColor(red: 1.0, green: 0.88, blue: 0.77, alpha: 1)
        let robeColor = UIColor(red: 0.35, green: 0.75, blue: 0.59, alpha: 1)
        let sashColor = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        let irisColor = UIColor(red: 0.43, green: 0.29, blue: 0.63, alpha: 1)

        // 顔（丸くふっくらした頬）。笠の下から覗く。
        let faceDiameter = rect.width * 0.68
        let faceRect = CGRect(
            x: rect.midX - faceDiameter / 2,
            y: rect.minY + rect.height * 0.20,
            width: faceDiameter,
            height: faceDiameter
        )
        cg.setFillColor(skinColor.cgColor)
        cg.addEllipse(in: faceRect)
        cg.fillPath()

        // 笠（丸みを帯びた、きのこ型に近い可愛らしいシルエット）。
        let hatTop = CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.02)
        let hatLeft = CGPoint(x: rect.minX - rect.width * 0.06, y: rect.minY + rect.height * 0.36)
        let hatRight = CGPoint(x: rect.maxX + rect.width * 0.06, y: rect.minY + rect.height * 0.36)
        let hat = CGMutablePath()
        hat.move(to: hatTop)
        hat.addQuadCurve(to: hatRight, control: CGPoint(x: rect.maxX * 0.94, y: rect.minY - rect.height * 0.04))
        hat.addQuadCurve(
            to: hatLeft,
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.48)
        )
        hat.addQuadCurve(to: hatTop, control: CGPoint(x: rect.minX * 1.06, y: rect.minY - rect.height * 0.04))
        hat.closeSubpath()
        cg.setFillColor(hatColor.cgColor)
        cg.addPath(hat)
        cg.fillPath()
        cg.setStrokeColor(hatRimColor.cgColor)
        cg.setLineWidth(max(rect.width * 0.03, 0.8))
        cg.addPath(hat)
        cg.strokePath()

        // 笠のてっぺんに、可愛いポンポン。
        let pomDiameter = rect.width * 0.1
        cg.setFillColor(hatTipColor.cgColor)
        cg.addEllipse(in: CGRect(x: hatTop.x - pomDiameter / 2, y: hatTop.y - pomDiameter / 2, width: pomDiameter, height: pomDiameter))
        cg.fillPath()

        drawChibiFace(in: cg, faceRect: faceRect, irisColor: irisColor)

        // 体（丸みのある、かわいい色の着物）。
        let bodyTop = faceRect.maxY - rect.height * 0.02
        let body = CGRect(x: rect.midX - rect.width * 0.36, y: bodyTop, width: rect.width * 0.72, height: rect.maxY - bodyTop)
        cg.setFillColor(robeColor.cgColor)
        cg.addPath(CGPath(roundedRect: body, cornerWidth: body.width * 0.42, cornerHeight: body.width * 0.42, transform: nil))
        cg.fillPath()

        // 帯（体の中央を横切る、明るい一本線）。
        let sashHeight = body.height * 0.24
        let sashRect = CGRect(x: body.minX, y: body.midY - sashHeight / 2, width: body.width, height: sashHeight)
        cg.setFillColor(sashColor.cgColor)
        cg.addRect(sashRect)
        cg.fillPath()
    }

    /// 髷（まげ）を結った、アニメ風の大きな瞳が可愛い侍。
    private static func drawSamuraiGlyph(in cg: CGContext, rect: CGRect) {
        let skinColor = UIColor(red: 1.0, green: 0.88, blue: 0.77, alpha: 1)
        let hairColor = UIColor(red: 0.18, green: 0.14, blue: 0.13, alpha: 1)
        let kimonoColor = UIColor(red: 0.80, green: 0.27, blue: 0.29, alpha: 1)
        let sashColor = UIColor(red: 0.98, green: 0.82, blue: 0.43, alpha: 1)
        let irisColor = UIColor(red: 0.59, green: 0.16, blue: 0.20, alpha: 1)

        // 頭（顔色にして、可愛い表情を乗せられるようにする）。
        let headDiameter = rect.width * 0.62
        let headRect = CGRect(x: rect.midX - headDiameter / 2, y: rect.minY + rect.height * 0.02, width: headDiameter, height: headDiameter)
        cg.setFillColor(skinColor.cgColor)
        cg.addEllipse(in: headRect)
        cg.fillPath()

        // 髷（頭の上に小さな突起）。
        let bun = CGRect(
            x: rect.midX - headDiameter * 0.17,
            y: headRect.minY - headDiameter * 0.28,
            width: headDiameter * 0.34,
            height: headDiameter * 0.30
        )
        cg.setFillColor(hairColor.cgColor)
        cg.addEllipse(in: bun)
        cg.fillPath()

        // 前髪（頭の上部を軽く覆う弧）。
        let bangs = CGRect(
            x: headRect.minX,
            y: headRect.minY - headDiameter * 0.03,
            width: headRect.width,
            height: headDiameter * 0.33
        )
        cg.setFillColor(hairColor.cgColor)
        cg.addEllipse(in: bangs)
        cg.fillPath()

        drawChibiFace(in: cg, faceRect: headRect, irisColor: irisColor)

        // 肩の張った着物（丸みを持たせた台形）。
        let shoulderY = headRect.maxY - rect.height * 0.02
        let kimono = CGMutablePath()
        kimono.move(to: CGPoint(x: rect.midX - rect.width * 0.12, y: shoulderY))
        kimono.addQuadCurve(
            to: CGPoint(x: rect.maxX * 0.96, y: rect.maxY),
            control: CGPoint(x: rect.maxX * 0.98, y: shoulderY + rect.height * 0.1)
        )
        kimono.addLine(to: CGPoint(x: rect.minX * 0.96, y: rect.maxY))
        kimono.addQuadCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.12, y: shoulderY),
            control: CGPoint(x: rect.minX * 0.9, y: shoulderY + rect.height * 0.1)
        )
        kimono.closeSubpath()
        cg.setFillColor(kimonoColor.cgColor)
        cg.addPath(kimono)
        cg.fillPath()

        // 帯（着物の中央を横切る、明るい一本線）。着物の実際の幅に合わせる。
        let kimonoBounds = kimono.boundingBoxOfPath
        let sashY = shoulderY + (rect.maxY - shoulderY) * 0.4
        let sashHeight = (rect.maxY - shoulderY) * 0.2
        let sashRect = CGRect(x: kimonoBounds.minX, y: sashY, width: kimonoBounds.width, height: sashHeight)
        cg.setFillColor(sashColor.cgColor)
        cg.addRect(sashRect)
        cg.fillPath()
    }

    /// 現代の歩行者アイコン（SF Symbolsの`figure.walk`をそのまま使う）。
    private static func drawModernPersonGlyph(in cg: CGContext, rect: CGRect) {
        let config = UIImage.SymbolConfiguration(pointSize: rect.height, weight: .bold)
        guard let symbol = UIImage(systemName: "figure.walk", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        else { return }

        // シンボルの実際の描画サイズは指定`pointSize`ぴったりにならないことがあるため、
        // アスペクト比を保ったまま`rect`の中央に収める。`UIImage.draw(in:)`は
        // `UIGraphicsImageRenderer`が設定済みのUIKit座標系（原点が左上）をそのまま
        // 使うため、`CGContext.draw(_:in:)`と違って上下反転の心配がない。
        let symbolSize = symbol.size
        let scale = min(rect.width / symbolSize.width, rect.height / symbolSize.height)
        let drawSize = CGSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        symbol.draw(in: drawRect)
    }
}
