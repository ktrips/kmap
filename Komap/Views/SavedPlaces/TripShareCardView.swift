import CoreLocation
import SwiftUI
import UIKit

/// SNS・LINEなどで共有するために、1枚の画像にまとめた時空旅の要約カード。
/// `ImageRenderer`でこのViewをそのままUIImageへ書き出して使う。
struct TripShareCardView: View {
    let route: WalkRoute
    let stamps: [CollectedStamp]
    let photoPosts: [WalkPhotoPost]
    /// 時間旅の記録画面に既に表示されている地図（`WalkRouteMapView`）をそのまま
    /// スナップショットしたもの。現在の地図・古地図・歩いたルート・御朱印スポットの
    /// マーカーが実際の画面と同じ見た目で重なった状態で載せられる。取得できなかった
    /// 場合だけ、簡易的に描き直した地図（`fallbackMapArea`）を使う。
    let mapSnapshot: UIImage?

    static let cardWidth: CGFloat = 1080
    private static let brown = Color(red: 0.72, green: 0.35, blue: 0.15)
    private static let goldBrown = Color(red: 0.72, green: 0.53, blue: 0.15)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header
            mapArea
            statsRow
            if let notes = route.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 30))
                    .foregroundStyle(.black.opacity(0.78))
                    .lineLimit(4)
            }
            if !stamps.isEmpty {
                goshuinSection
            }
            if !photoPosts.isEmpty {
                photosSection
            }
            footer
        }
        .padding(44)
        .frame(width: Self.cardWidth, alignment: .leading)
        .background(Color(red: 0.99, green: 0.97, blue: 0.93))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let overlayMap = route.overlayMap {
                Text(overlayMap.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Self.brown)
            }
            Text(route.title?.isEmpty == false ? route.title! : "時空旅の記録")
                .font(.system(size: 52, weight: .heavy))
                .foregroundStyle(.black)
        }
    }

    @ViewBuilder
    private var mapArea: some View {
        if let mapSnapshot {
            Image(uiImage: mapSnapshot)
                .resizable()
                .scaledToFill()
                .frame(height: Self.cardWidth - 88)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
        } else {
            fallbackMapArea
        }
    }

    /// 画面の地図をスナップショットできなかった時だけ使う、簡易的な地図の描き直し。
    /// ネットワーク通信や実行中のGMSMapViewを必要とせず、既に端末上にある古地図画像
    /// （`overlayMap.image`）とルート座標だけで描画する。
    private var fallbackMapArea: some View {
        Canvas { context, size in
            if let overlayMap = route.overlayMap, let cgImage = overlayMap.image?.cgImage {
                context.draw(Image(decorative: cgImage, scale: 1), in: CGRect(origin: .zero, size: size))
            } else {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            }

            let path = routePath(in: size)
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Self.brown), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    /// 緯度経度を、古地図の範囲（`overlayMap.southWest`〜`northEast`）を基準に
    /// カード内の座標へ単純な線形変換で写す（`bearing`による回転は考慮しない、
    /// フォールバック描画としては十分な近似）。古地図が無い場合は歩いたルート自体の
    /// 範囲を基準にする。
    private func routePath(in size: CGSize) -> Path {
        var path = Path()
        let coordinates = route.coordinates
        guard coordinates.count >= 2 else { return path }

        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double
        if let overlayMap = route.overlayMap {
            minLat = min(overlayMap.southWest.latitude, overlayMap.northEast.latitude)
            maxLat = max(overlayMap.southWest.latitude, overlayMap.northEast.latitude)
            minLon = min(overlayMap.southWest.longitude, overlayMap.northEast.longitude)
            maxLon = max(overlayMap.southWest.longitude, overlayMap.northEast.longitude)
        } else {
            let lats = coordinates.map(\.latitude)
            let lons = coordinates.map(\.longitude)
            minLat = lats.min() ?? 0
            maxLat = lats.max() ?? 0
            minLon = lons.min() ?? 0
            maxLon = lons.max() ?? 0
        }
        let latSpan = max(maxLat - minLat, 0.0001)
        let lonSpan = max(maxLon - minLon, 0.0001)

        func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            let x = (coordinate.longitude - minLon) / lonSpan * size.width
            let y = (1 - (coordinate.latitude - minLat) / latSpan) * size.height
            return CGPoint(x: x, y: y)
        }

        path.move(to: point(for: coordinates[0]))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: point(for: coordinate))
        }
        return path
    }

    private var statsRow: some View {
        HStack(spacing: 28) {
            statItem(systemImage: "figure.walk", text: distanceText)
            if let durationText {
                statItem(systemImage: "clock", text: durationText)
            }
            statItem(systemImage: "seal.fill", text: "御朱印 \(stamps.count)件", tint: Self.goldBrown)
            if !photoPosts.isEmpty {
                statItem(systemImage: "camera.fill", text: "写真 \(photoPosts.count)件", tint: Color(red: 0.86, green: 0.63, blue: 0.24))
            }
        }
        .font(.system(size: 26, weight: .semibold))
    }

    private func statItem(systemImage: String, text: String, tint: Color = .black.opacity(0.7)) -> some View {
        Label(text, systemImage: systemImage)
            .foregroundStyle(tint)
    }

    /// 御朱印・チェックポイントは、時間旅の記録画面の「御朱印・チェックポイント」
    /// セクション（`CheckpointRow`）と同じく、写真・名前・史跡の紹介文を横並びで
    /// 1件ずつ、件数の上限なく全て並べる。
    private var goshuinSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("御朱印・チェックポイント")
                .font(.system(size: 28, weight: .bold))
            ForEach(stamps) { stamp in
                if let site = stamp.site {
                    HStack(alignment: .top, spacing: 18) {
                        thumbnailImage(stamp.photo, placeholderSystemImage: "seal.fill", size: 120)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.name)
                                .font(.system(size: 24, weight: .bold))
                            Text(site.summary)
                                .font(.system(size: 20))
                                .foregroundStyle(.black.opacity(0.6))
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    /// 投稿した写真は、記録画面の「投稿した写真」セクションと同じく、
    /// キャプション無しのグリッドで件数の上限なく全て並べる。
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("投稿した写真")
                .font(.system(size: 28, weight: .bold))
            let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(photoPosts) { post in
                    thumbnailImage(post.photo, placeholderSystemImage: "camera.fill", size: 220)
                }
            }
        }
    }

    private func thumbnailImage(_ image: UIImage?, placeholderSystemImage: String, size: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .overlay(Image(systemName: placeholderSystemImage).font(.system(size: 32)).foregroundStyle(Self.goldBrown))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        Text("Komap 古地図巡り")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Self.brown)
            .padding(.top, 8)
    }

    private var distanceText: String {
        let meters = route.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private var durationText: String? {
        guard let durationSeconds = route.durationSeconds else { return nil }
        let totalMinutes = Int(durationSeconds / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)時間\(totalMinutes % 60)分"
        }
        return "\(max(totalMinutes, 1))分"
    }
}

/// 生成した共有アイテム（画像・メッセージ）を、標準のシステム共有シートで見せる。
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
