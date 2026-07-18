import CoreLocation
import SwiftUI

/// メインのマップ画面。現在地・古地図オーバーレイ・タップ操作をまとめる。
struct MapScreen: View {
    @StateObject private var locationManager = LocationManager()

    @State private var selectedOverlay: HistoricalOverlayMap? = OldMapCatalog.edoCastle
    @State private var overlayOpacity: Double = 0.55
    @State private var tappedPoint: TappedPoint?
    @State private var cameraTarget: CLLocationCoordinate2D?

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapRepresentable(
                overlayMap: selectedOverlay,
                overlayOpacity: Float(overlayOpacity),
                moveCameraTo: cameraTarget,
                onTap: { coordinate in
                    tappedPoint = TappedPoint(coordinate: coordinate)
                }
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                currentLocationButton
                OverlayControlPanel(selectedOverlay: $selectedOverlay, overlayOpacity: $overlayOpacity)
            }
            .padding(.bottom, 12)
        }
        .sheet(item: $tappedPoint) { point in
            StorySheetView(point: point, overlayMap: selectedOverlay)
        }
        .onAppear {
            locationManager.requestPermissionIfNeeded()
        }
    }

    private var currentLocationButton: some View {
        HStack {
            Spacer()
            Button {
                guard let coordinate = locationManager.currentLocation else { return }
                cameraTarget = coordinate
                tappedPoint = TappedPoint(coordinate: coordinate)
            } label: {
                Label("現在地の昔の物語を見る", systemImage: "figure.walk.motion")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .disabled(locationManager.currentLocation == nil)
            Spacer()
        }
    }
}

#Preview {
    MapScreen()
}
