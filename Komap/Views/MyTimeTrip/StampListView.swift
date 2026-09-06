import CoreLocation
import SwiftData
import SwiftUI

/// My TimeTripの「御朱印」サマリーカードをタップした時に開く御朱印一覧。
/// `overlayMapID`を指定すると、その古地図のチェックポイントだけに絞り込み、
/// 一番上にその古地図とチェックポイントを重ねた地図を表示する。
struct StampListView: View {
    var overlayMapID: String?
    var title: String?

    @Query(sort: \CollectedStamp.collectedAt, order: .reverse) private var collectedStamps: [CollectedStamp]

    @State private var selectedStamp: StampSelection?

    private let cardColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    private var overlayMap: HistoricalOverlayMap? {
        overlayMapID.flatMap { id in OldMapCatalog.allIncludingCustom.first { $0.id == id } }
    }

    private var sites: [HistoricSite] {
        if let overlayMapID {
            return HistoricSiteCatalog.sites(forOverlayID: overlayMapID)
        }
        return HistoricSiteCatalog.all
    }

    /// 「すべての御朱印」表示時（`overlayMapID`が`nil`）に、チェックポイントを持つ古地図ごとに
    /// カタログの並び順のままグルーピングしたもの。
    private var sitesByMap: [(map: HistoricalOverlayMap, sites: [HistoricSite])] {
        OldMapCatalog.allIncludingCustom.compactMap { map in
            let mapSites = HistoricSiteCatalog.sites(forOverlayID: map.id)
            return mapSites.isEmpty ? nil : (map, mapSites)
        }
    }

    private var stampsBySiteID: [String: CollectedStamp] {
        Dictionary(collectedStamps.map { ($0.siteID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var collectedSiteIDs: Set<String> {
        Set(stampsBySiteID.keys)
    }

    private var collectedCount: Int {
        sites.filter { stampsBySiteID[$0.id] != nil }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let overlayMap {
                    CheckpointMapPreview(
                        overlayMap: overlayMap,
                        checkpoints: sites,
                        collectedSiteIDs: collectedSiteIDs
                    )
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if overlayMapID == nil {
                    ForEach(sitesByMap, id: \.map.id) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(group.map.title) (\(collectedCount(in: group.sites)) / \(group.sites.count))")
                                .font(.subheadline.bold())
                                .foregroundStyle(.brown)

                            CheckpointMapPreview(
                                overlayMap: group.map,
                                checkpoints: group.sites,
                                collectedSiteIDs: collectedSiteIDs
                            )
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            LazyVGrid(columns: cardColumns, spacing: 12) {
                                stampCells(for: group.sites)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: cardColumns, spacing: 12) {
                        stampCells(for: sites)
                    }
                }

                Text("「スタート」でウォーキングを記録しながら史跡チェックポイントに近づくと、御朱印が自動で貯まります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("\(title ?? "御朱印") \(collectedCount) / \(sites.count)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStamp) { selection in
            StampCheckInSheet(site: selection.site, stamp: selection.stamp)
        }
    }

    private func collectedCount(in sites: [HistoricSite]) -> Int {
        sites.filter { stampsBySiteID[$0.id] != nil }.count
    }

    @ViewBuilder
    private func stampCells(for sites: [HistoricSite]) -> some View {
        ForEach(sites) { site in
            let stamp = stampsBySiteID[site.id]
            StampCell(site: site, stamp: stamp)
                .onTapGesture {
                    if let stamp {
                        selectedStamp = StampSelection(site: site, stamp: stamp)
                    }
                }
        }
    }
}

/// 古地図の上にチェックポイントを重ねた、操作不要の小さな地図。
/// 獲得済みのチェックポイントは濃く、未獲得は薄く表示する。
///
/// - Important: 以前はこのプレビュー1件ごとに`GMSMapView`（Google Maps
///   SDKの動的地図）を生成していたが、「すべての御朱印」表示では古地図の数だけ
///   このプレビューが同時に並ぶため、開くたびにその数だけ「地図の読み込み」が
///   発生し、Google Maps Platformの従量課金（読み込み回数に応じた課金）を
///   無駄に積み増していた。この画面のプレビューは操作不要（パン・ズームしない）
///   なので、同梱の古地図画像の上に自前でチェックポイントのピンを描画する、
///   ただのSwiftUIビューに置き換え、Google Maps SDKを一切呼び出さないようにした
///   （地図の読み込み回数はゼロになる）。
private struct CheckpointMapPreview: View {
    let overlayMap: HistoricalOverlayMap
    let checkpoints: [HistoricSite]
    let collectedSiteIDs: Set<String>

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = Self.previewImage(for: overlayMap) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Color(.systemGray5)
                }

                ForEach(checkpoints) { site in
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                        .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
                        .opacity(collectedSiteIDs.contains(site.id) ? 1.0 : 0.45)
                        .position(Self.point(for: site.coordinate, in: overlayMap, canvasSize: geometry.size))
                }
            }
        }
        .background(Color(.systemGray6))
    }

    /// この小さなプレビュー用に画像を縮小したものを、古地図ごとにキャッシュして使い回す。
    /// 画面に表示するだけの小さなプレビューに実寸（実在の史料画像は3500×2610pxなど）の
    /// 画像をそのまま使うと無駄にメモリ・描画コストがかかるため、縮小したものを使う。
    private static var downsampledImageCache: [String: UIImage] = [:]
    private static let maxDimension: CGFloat = 600

    private static func previewImage(for overlayMap: HistoricalOverlayMap) -> UIImage? {
        let cacheKey = overlayMap.imageAssetName ?? overlayMap.imageFileName ?? overlayMap.id
        if let cached = downsampledImageCache[cacheKey] {
            return cached
        }
        guard let image = overlayMap.image else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            downsampledImageCache[cacheKey] = image
            return image
        }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        downsampledImageCache[cacheKey] = resized
        return resized
    }

    /// 史跡の実際の緯度経度を、古地図画像上の座標（キャンバスのピクセル位置）へ変換する。
    /// `overlayMap.bearing`（画像の回転）が0でない場合（例: 五色不動めぐり）も、
    /// 画像の向きに合わせて正しい位置に投影されるよう、回転を打ち消してから計算する。
    private static func point(for coordinate: CLLocationCoordinate2D, in overlayMap: HistoricalOverlayMap, canvasSize: CGSize) -> CGPoint {
        let sw = overlayMap.southWest
        let ne = overlayMap.northEast
        let centerLat = (sw.latitude + ne.latitude) / 2
        let centerLng = (sw.longitude + ne.longitude) / 2
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLng = 111_320.0 * cos(centerLat * .pi / 180)

        // 中心からの実距離（東西・南北、メートル）。
        let eastMeters = (coordinate.longitude - centerLng) * metersPerDegreeLng
        let northMeters = (coordinate.latitude - centerLat) * metersPerDegreeLat

        // 画像は`bearing`度だけ真北から時計回りに回転して表示されるため、
        // 画像自身の座標系に合わせて実距離を逆回転させる。
        let bearingRad = overlayMap.bearing * .pi / 180
        let uMeters = eastMeters * cos(bearingRad) - northMeters * sin(bearingRad)
        let vMeters = -eastMeters * sin(bearingRad) - northMeters * cos(bearingRad)

        let widthMeters = (ne.longitude - sw.longitude) * metersPerDegreeLng
        let heightMeters = (ne.latitude - sw.latitude) * metersPerDegreeLat
        guard widthMeters != 0, heightMeters != 0 else {
            return CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        }

        let uFraction = 0.5 + uMeters / widthMeters
        let vFraction = 0.5 + vMeters / heightMeters
        // 古地図の範囲からわずかにはみ出すチェックポイントも、プレビュー内に収まるよう
        // 端に寄せる（実際の地図タブでは範囲外でも正しい位置に表示される）。
        let clampedU = min(max(uFraction, 0.04), 0.96)
        let clampedV = min(max(vFraction, 0.04), 0.96)

        return CGPoint(x: clampedU * canvasSize.width, y: clampedV * canvasSize.height)
    }
}

#Preview {
    NavigationStack {
        StampListView()
    }
    .modelContainer(for: [CollectedStamp.self], inMemory: true)
}
