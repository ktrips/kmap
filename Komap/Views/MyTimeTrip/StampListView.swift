import GoogleMaps
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
            VStack(alignment: .leading, spacing: 12) {
                if let overlayMap {
                    CheckpointMapPreview(
                        overlayMap: overlayMap,
                        checkpoints: sites,
                        collectedSiteIDs: collectedSiteIDs
                    )
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if overlayMapID == nil {
                    ForEach(sitesByMap, id: \.map.id) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(group.map.title) (\(collectedCount(in: group.sites)) / \(group.sites.count))")
                                .font(.subheadline.bold())
                                .foregroundStyle(.brown)

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
private struct CheckpointMapPreview: UIViewRepresentable {
    let overlayMap: HistoricalOverlayMap
    let checkpoints: [HistoricSite]
    let collectedSiteIDs: Set<String>

    func makeUIView(context: Context) -> GMSMapView {
        let initialCamera = GMSCameraPosition.camera(
            withLatitude: overlayMap.center.latitude,
            longitude: overlayMap.center.longitude,
            zoom: 14
        )
        let mapView = GMSMapView()
        mapView.camera = initialCamera
        mapView.settings.scrollGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false

        let bounds = GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
        let overlay = GMSGroundOverlay(bounds: bounds, icon: overlayMap.image)
        overlay.opacity = 0.85
        overlay.map = mapView

        var fitBounds = bounds
        for site in checkpoints {
            let marker = GMSMarker(position: site.coordinate)
            marker.title = site.name
            marker.icon = GMSMarker.markerImage(with: .shuiro)
            marker.opacity = collectedSiteIDs.contains(site.id) ? 1.0 : 0.5
            marker.map = mapView
            fitBounds = fitBounds.includingCoordinate(site.coordinate)
        }
        mapView.moveCamera(GMSCameraUpdate.fit(fitBounds, withPadding: 20))

        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {}
}

#Preview {
    NavigationStack {
        StampListView()
    }
    .modelContainer(for: [CollectedStamp.self], inMemory: true)
}
