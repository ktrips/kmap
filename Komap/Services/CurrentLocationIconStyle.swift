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
            return Self.badgeIcon(emphasized: emphasized, backgroundColor: UIColor(red: 0.93, green: 0.85, blue: 0.68, alpha: 1)) { cg, rect in
                Self.drawTravelerGlyph(in: cg, rect: rect)
            }
        case .samurai:
            return Self.badgeIcon(emphasized: emphasized, backgroundColor: UIColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1)) { cg, rect in
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

    /// 菅笠（円錐形の笠）をかぶった旅人のシルエット。
    private static func drawTravelerGlyph(in cg: CGContext, rect: CGRect) {
        let color = UIColor(red: 0.36, green: 0.24, blue: 0.13, alpha: 1)
        cg.setFillColor(color.cgColor)

        // 笠（三角形に近い、少し丸みを持たせた円錐）。
        let hatTop = CGPoint(x: rect.midX, y: rect.minY)
        let hatLeft = CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.42)
        let hatRight = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.42)
        let hat = CGMutablePath()
        hat.move(to: hatTop)
        hat.addQuadCurve(to: hatRight, control: CGPoint(x: rect.maxX * 0.9, y: rect.minY + rect.height * 0.18))
        hat.addLine(to: hatLeft)
        hat.addQuadCurve(to: hatTop, control: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.18))
        hat.closeSubpath()
        cg.addPath(hat)
        cg.fillPath()

        // 体（笠の下の、簡単な人型シルエット）。
        let bodyTop = rect.minY + rect.height * 0.5
        let body = CGRect(x: rect.midX - rect.width * 0.16, y: bodyTop, width: rect.width * 0.32, height: rect.height * 0.5)
        cg.addPath(CGPath(roundedRect: body, cornerWidth: body.width * 0.4, cornerHeight: body.width * 0.4, transform: nil))
        cg.fillPath()
    }

    /// 髷（まげ）を結った頭と、肩の張った着物のシルエット。
    private static func drawSamuraiGlyph(in cg: CGContext, rect: CGRect) {
        let color = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        cg.setFillColor(color.cgColor)

        // 頭。
        let headDiameter = rect.width * 0.42
        let headRect = CGRect(x: rect.midX - headDiameter / 2, y: rect.minY, width: headDiameter, height: headDiameter)
        cg.addEllipse(in: headRect)
        cg.fillPath()

        // 髷（頭の上に小さな突起）。
        let bun = CGRect(
            x: rect.midX - headDiameter * 0.16,
            y: headRect.minY - headDiameter * 0.28,
            width: headDiameter * 0.32,
            height: headDiameter * 0.28
        )
        cg.addEllipse(in: bun)
        cg.fillPath()

        // 肩の張った着物（台形）。
        let shoulderY = headRect.maxY + rect.height * 0.04
        let kimono = CGMutablePath()
        kimono.move(to: CGPoint(x: rect.midX - rect.width * 0.1, y: shoulderY))
        kimono.addLine(to: CGPoint(x: rect.midX + rect.width * 0.1, y: shoulderY))
        kimono.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        kimono.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        kimono.closeSubpath()
        cg.addPath(kimono)
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
