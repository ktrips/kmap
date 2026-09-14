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
            let background = UIColor(red: 0.98, green: 0.93, blue: 0.84, alpha: 1)
            let foreground = UIColor(red: 0.77, green: 0.35, blue: 0.29, alpha: 1)
            return Self.badgeIcon(emphasized: emphasized, backgroundColor: background) { cg, rect in
                Self.drawTravelerGlyph(in: cg, rect: rect, backgroundColor: background, foregroundColor: foreground)
            }
        case .samurai:
            let background = UIColor(red: 0.87, green: 0.91, blue: 0.97, alpha: 1)
            let foreground = UIColor(red: 0.16, green: 0.20, blue: 0.29, alpha: 1)
            return Self.badgeIcon(emphasized: emphasized, backgroundColor: background) { cg, rect in
                Self.drawSamuraiGlyph(in: cg, rect: rect, backgroundColor: background, foregroundColor: foreground)
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

    /// 菅笠（円錐形の笠）をかぶった旅人を、背景・本体の2色だけで表す、
    /// きのこのようなシルエット。飾りは一切足さず、丸みのある形そのもので
    /// 可愛さを出す（コケシのような、シンプルだけどセンスのある佇まい）。
    private static func drawTravelerGlyph(in cg: CGContext, rect: CGRect, backgroundColor: UIColor, foregroundColor: UIColor) {
        // 笠：横に大きく張り出した、丸みのあるドーム型。
        let hatTop = CGPoint(x: rect.midX, y: rect.minY)
        let hatLeft = CGPoint(x: rect.minX - rect.width * 0.10, y: rect.minY + rect.height * 0.30)
        let hatRight = CGPoint(x: rect.maxX + rect.width * 0.10, y: rect.minY + rect.height * 0.30)
        let hatBottomLeft = CGPoint(x: rect.midX - rect.width * 0.30, y: rect.minY + rect.height * 0.34)
        let hatBottomRight = CGPoint(x: rect.midX + rect.width * 0.30, y: rect.minY + rect.height * 0.34)

        let hat = CGMutablePath()
        hat.move(to: hatTop)
        hat.addQuadCurve(to: hatRight, control: CGPoint(x: rect.maxX * 1.02, y: rect.minY - rect.height * 0.02))
        hat.addQuadCurve(to: hatBottomRight, control: CGPoint(x: rect.midX + rect.width * 0.30, y: rect.minY + rect.height * 0.30))
        hat.addLine(to: hatBottomLeft)
        hat.addQuadCurve(to: hatLeft, control: CGPoint(x: rect.midX - rect.width * 0.30, y: rect.minY + rect.height * 0.30))
        hat.addQuadCurve(to: hatTop, control: CGPoint(x: rect.minX * 0.98, y: rect.minY - rect.height * 0.02))
        hat.closeSubpath()
        cg.setFillColor(foregroundColor.cgColor)
        cg.addPath(hat)
        cg.fillPath()

        // 体：笠より一回り細い、丸いカプセル形（笠の下からちょこんと覗く）。
        let bodyWidth = rect.width * 0.40
        let bodyTop = rect.minY + rect.height * 0.40
        let body = CGRect(x: rect.midX - bodyWidth / 2, y: bodyTop, width: bodyWidth, height: rect.maxY - bodyTop)
        cg.addPath(CGPath(roundedRect: body, cornerWidth: bodyWidth / 2, cornerHeight: bodyWidth / 2, transform: nil))
        cg.fillPath()

        // 目：背景色でくり抜いた2つの小さな点だけで表情を出す（色数は増やさない）。
        Self.drawDotEyes(in: cg, centerX: rect.midX, y: bodyTop + rect.height * 0.10, spread: rect.width * 0.11, diameter: rect.width * 0.065, color: backgroundColor)
    }

    /// 髷（まげ）を結った侍を、背景・本体の2色だけで表す、丸いシルエット。
    private static func drawSamuraiGlyph(in cg: CGContext, rect: CGRect, backgroundColor: UIColor, foregroundColor: UIColor) {
        cg.setFillColor(foregroundColor.cgColor)

        // 頭。
        let headRadius = rect.width * 0.30
        let headCenter = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.24)
        cg.addEllipse(in: CGRect(
            x: headCenter.x - headRadius, y: headCenter.y - headRadius,
            width: headRadius * 2, height: headRadius * 2
        ))
        cg.fillPath()

        // 髷（頭の上の小さな突起）。
        let bunWidth = rect.width * 0.14
        let bunHeight = rect.height * 0.12
        cg.addEllipse(in: CGRect(x: rect.midX - bunWidth / 2, y: rect.minY - bunHeight / 2, width: bunWidth, height: bunHeight))
        cg.fillPath()

        // 体（着物）：肩から丸みを帯びて広がる、角の丸いシルエット。
        let bodyTopY = headCenter.y + headRadius * 0.55
        let bodyTopLeft = CGPoint(x: rect.midX - rect.width * 0.16, y: bodyTopY)
        let bodyTopRight = CGPoint(x: rect.midX + rect.width * 0.16, y: bodyTopY)
        let shoulderY = rect.maxY - rect.height * 0.25
        let shoulderLeft = CGPoint(x: rect.midX - rect.width * 0.40, y: shoulderY)
        let shoulderRight = CGPoint(x: rect.midX + rect.width * 0.40, y: shoulderY)
        let cornerRadius = rect.width * 0.08
        let bottomLeft = CGPoint(x: rect.midX - rect.width * 0.34, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.midX + rect.width * 0.34, y: rect.maxY)

        let body = CGMutablePath()
        body.move(to: bodyTopLeft)
        body.addQuadCurve(to: shoulderLeft, control: CGPoint(x: rect.midX - rect.width * 0.44, y: rect.maxY - rect.height * 0.55))
        body.addLine(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y - cornerRadius))
        body.addQuadCurve(to: CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y), control: bottomLeft)
        body.addLine(to: CGPoint(x: bottomRight.x - cornerRadius, y: bottomRight.y))
        body.addQuadCurve(to: CGPoint(x: bottomRight.x, y: bottomRight.y - cornerRadius), control: bottomRight)
        body.addLine(to: shoulderRight)
        body.addQuadCurve(to: bodyTopRight, control: CGPoint(x: rect.midX + rect.width * 0.44, y: rect.maxY - rect.height * 0.55))
        body.closeSubpath()
        cg.addPath(body)
        cg.fillPath()

        // 目：背景色でくり抜いた2つの小さな点だけで表情を出す（色数は増やさない）。
        Self.drawDotEyes(
            in: cg,
            centerX: rect.midX,
            y: headCenter.y + headRadius * 0.05,
            spread: rect.width * 0.13,
            diameter: rect.width * 0.065,
            color: backgroundColor
        )
    }

    /// キャラの表情を2つの小さな点だけで表す共通処理（`travelerHat`／`samurai`共通）。
    private static func drawDotEyes(in cg: CGContext, centerX: CGFloat, y: CGFloat, spread: CGFloat, diameter: CGFloat, color: UIColor) {
        cg.setFillColor(color.cgColor)
        for dx in [-spread, spread] {
            let cx = centerX + dx
            cg.addEllipse(in: CGRect(x: cx - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter))
        }
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
