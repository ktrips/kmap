import CoreLocation
import SwiftData
import SwiftUI

/// メインのマップ画面。現在地・古地図オーバーレイ・タップ操作をまとめる。
struct MapScreen: View {
    @StateObject private var locationManager = LocationManager()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var savedRoutes: [WalkRoute]

    @State private var selectedOverlay: HistoricalOverlayMap? = OldMapCatalog.edoCastle
    @State private var overlayOpacity: Double = 0.55
    @State private var tappedPoint: TappedPoint?
    @State private var cameraTarget: CLLocationCoordinate2D?

    /// 画面下部に浮かせているパネル（アクションボタン＋古地図コントロール）が占める高さ。
    /// Google純正の現在地ボタンなどがこのパネルに隠れて押せなくなるのを防ぐため、
    /// `GoogleMapRepresentable` にこの分の下余白を持たせる。
    private let bottomPanelHeight: CGFloat = 210

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapRepresentable(
                overlayMap: selectedOverlay,
                overlayOpacity: Float(overlayOpacity),
                moveCameraTo: cameraTarget,
                bottomInset: bottomPanelHeight,
                savedWalkPaths: savedRoutes.map(\.coordinates),
                liveWalkPath: locationManager.walkPath,
                onTap: { coordinate in
                    tappedPoint = TappedPoint(coordinate: coordinate)
                }
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                actionButtonsRow
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

    private var actionButtonsRow: some View {
        HStack(spacing: 10) {
            Spacer()
            walkRecordButton
            currentLocationButton
            Spacer()
        }
    }

    private var walkRecordButton: some View {
        Button {
            toggleWalkRecording()
        } label: {
            Label(
                locationManager.isRecordingWalk ? "記録終了" : "スタート",
                systemImage: locationManager.isRecordingWalk ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(locationManager.isRecordingWalk ? .white : .primary)
            .background(
                locationManager.isRecordingWalk ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.regularMaterial),
                in: Capsule()
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .disabled(locationManager.currentLocation == nil && !locationManager.isRecordingWalk)
    }

    private var currentLocationButton: some View {
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
    }

    /// 「スタート」で記録を開始し、もう一度押すと記録を終え、2点以上あればルートとして保存する。
    private func toggleWalkRecording() {
        if locationManager.isRecordingWalk {
            let path = locationManager.stopRecordingWalk()
            guard path.count >= 2 else { return }
            modelContext.insert(WalkRoute(coordinates: path))
        } else {
            locationManager.startRecordingWalk()
        }
    }
}

#Preview {
    MapScreen()
        .modelContainer(for: [SavedPlace.self, WalkRoute.self], inMemory: true)
}
