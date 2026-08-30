import CoreLocation
import GoogleMaps
import SwiftData
import SwiftUI

/// 保存した1回分の時間旅行（ウォーキング記録）の詳細。
/// 使っていた古地図・歩いたルート（塗りつぶした地図）・通ったチェックポイントと御朱印・
/// アップした写真をまとめて表示する。
struct WalkRouteDetailView: View {
    let route: WalkRoute

    @Query private var collectedStamps: [CollectedStamp]

    private var stampsForRoute: [CollectedStamp] {
        collectedStamps
            .filter { $0.walkRouteID == route.id }
            .sorted { $0.collectedAt < $1.collectedAt }
    }

    private var checkpointsForOverlay: [HistoricSite] {
        HistoricSiteCatalog.sites(forOverlayID: route.overlayMapID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WalkRouteMapView(
                    overlayMap: route.overlayMap,
                    overlayOpacity: Float(route.overlayOpacity),
                    path: route.coordinates,
                    checkpoints: checkpointsForOverlay,
                    collectedSiteIDs: Set(stampsForRoute.map(\.siteID))
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                header

                if !stampsForRoute.isEmpty {
                    checkpointsSection
                }
            }
            .padding()
        }
        .navigationTitle("時間旅の記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(route.startedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.title3.bold())

            Text(route.overlayMap?.title ?? "古地図なし")
                .font(.subheadline.bold())
                .foregroundStyle(.brown)

            HStack(spacing: 12) {
                Label(distanceText, systemImage: "figure.walk")
                Label("御朱印 \(stampsForRoute.count)件", systemImage: "seal.fill")
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通ったチェックポイント")
                .font(.headline)

            ForEach(stampsForRoute) { stamp in
                if let site = stamp.site {
                    CheckpointRow(site: site, stamp: stamp)
                }
            }
        }
    }

    private var distanceText: String {
        let meters = route.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

/// この時間旅で獲得した1つのチェックポイント（史跡・御朱印・アップした写真）を表す行。
private struct CheckpointRow: View {
    let site: HistoricSite
    let stamp: CollectedStamp

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let photo = stamp.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                    .frame(width: 56, height: 56)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .font(.subheadline.bold())
                Text(site.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(stamp.collectedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

/// 歩いたルート（＝自分が通って塗りつぶした地図）を、使っていた古地図・
/// チェックポイントと一緒に表示する、操作不要の小さな地図。
private struct WalkRouteMapView: UIViewRepresentable {
    let overlayMap: HistoricalOverlayMap?
    let overlayOpacity: Float
    let path: [CLLocationCoordinate2D]
    let checkpoints: [HistoricSite]
    let collectedSiteIDs: Set<String>

    func makeUIView(context: Context) -> GMSMapView {
        let initialCamera = GMSCameraPosition.camera(
            withLatitude: overlayMap?.center.latitude ?? path.first?.latitude ?? 35.6812,
            longitude: overlayMap?.center.longitude ?? path.first?.longitude ?? 139.767,
            zoom: 15
        )
        let mapView = GMSMapView()
        mapView.camera = initialCamera
        mapView.settings.scrollGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false

        if let overlayMap {
            let bounds = GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
            let overlay = GMSGroundOverlay(bounds: bounds, icon: UIImage(named: overlayMap.imageAssetName))
            overlay.opacity = overlayOpacity
            overlay.map = mapView
        }

        if path.count >= 2 {
            let gmsPath = GMSMutablePath()
            path.forEach { gmsPath.add($0) }
            let polyline = GMSPolyline(path: gmsPath)
            polyline.strokeColor = UIColor.systemOrange.withAlphaComponent(0.85)
            polyline.strokeWidth = 8
            polyline.map = mapView
        }

        for site in checkpoints {
            let marker = GMSMarker(position: site.coordinate)
            marker.title = site.name
            marker.icon = GMSMarker.markerImage(
                with: collectedSiteIDs.contains(site.id) ? .systemYellow : .systemBrown
            )
            marker.opacity = collectedSiteIDs.contains(site.id) ? 1.0 : 0.6
            marker.map = mapView
        }

        var pathBounds: GMSCoordinateBounds?
        for coordinate in path {
            pathBounds = pathBounds?.includingCoordinate(coordinate)
                ?? GMSCoordinateBounds(coordinate: coordinate, coordinate: coordinate)
        }
        if let pathBounds {
            mapView.moveCamera(GMSCameraUpdate.fit(pathBounds, withPadding: 32))
        }

        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {}
}

#Preview {
    NavigationStack {
        WalkRouteDetailView(
            route: WalkRoute(
                coordinates: [
                    CLLocationCoordinate2D(latitude: 35.6773, longitude: 139.7539),
                    CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.7565),
                ],
                overlayMapID: OldMapCatalog.edoCastle.id
            )
        )
    }
    .modelContainer(for: [WalkRoute.self, CollectedStamp.self], inMemory: true)
}
