import CoreLocation
import GoogleMaps
import SwiftUI

/// 保存済みの1地点の詳細。小さなマップと物語本文を表示する。
struct SavedPlaceDetailView: View {
    let place: SavedPlace

    private var overlayMap: HistoricalOverlayMap? {
        OldMapCatalog.resolve(id: place.overlayMapID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MiniMapView(coordinate: place.coordinate)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Label(place.era, systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.bold())
                        .foregroundStyle(.brown)
                    if let overlayMap {
                        Text(overlayMap.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(place.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(place.title)
                    .font(.title2.bold())

                Text(place.storyText)
                    .font(.body)
                    .lineSpacing(4)
            }
            .padding()
        }
        .navigationTitle("記録の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 保存地点にピンを立てた、操作不要の小さな地図。
private struct MiniMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withTarget: coordinate, zoom: 16)
        let mapView = GMSMapView()
        mapView.camera = camera
        mapView.settings.scrollGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false

        let marker = GMSMarker(position: coordinate)
        marker.map = mapView
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {}
}

#Preview {
    NavigationStack {
        SavedPlaceDetailView(
            place: SavedPlace(
                title: "江戸城の桜田門",
                latitude: 35.679,
                longitude: 139.753,
                overlayMapID: OldMapCatalog.edoCastle.id,
                era: OldMapCatalog.edoCastle.era,
                storyText: "この付近は江戸城の桜田門があった場所と伝えられています。"
            )
        )
    }
}
