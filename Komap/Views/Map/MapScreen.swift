import CoreLocation
import SwiftData
import SwiftUI

/// メインのマップ画面。現在地・古地図オーバーレイ・タップ操作をまとめる。
struct MapScreen: View {
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var mapSession: MapSessionState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var savedRoutes: [WalkRoute]
    @Query private var collectedStamps: [CollectedStamp]

    @State private var tappedPoint: TappedPoint?
    @State private var newlyCollectedSite: HistoricSite?
    @State private var newlyCollectedStamp: CollectedStamp?
    /// 記録中のウォーキングを識別するID。停止時に`WalkRoute`へそのまま使い、
    /// 記録中に獲得した御朱印もこのIDで紐付ける。
    @State private var activeWalkSessionID: UUID?

    private let syncService = SyncService()

    /// この距離（メートル）以内にチェックポイントへ近づいたら御朱印を獲得する。
    private let stampCollectionRadiusMeters: CLLocationDistance = 60

    /// 画面下部に浮かせているパネル（アクションボタン＋古地図コントロール）が占める高さ。
    /// Google純正の現在地ボタンなどがこのパネルに隠れて押せなくなるのを防ぐため、
    /// `GoogleMapRepresentable` にこの分の下余白を持たせる。
    private let bottomPanelHeight: CGFloat = 210

    private var collectedSiteIDs: Set<String> {
        Set(collectedStamps.map(\.siteID))
    }

    /// 現在選択中の古地図に紐づくチェックポイント（5箇所程度）。
    private var activeCheckpoints: [HistoricSite] {
        HistoricSiteCatalog.sites(forOverlayID: mapSession.selectedOverlay?.id)
    }

    private var isCheckInSheetPresented: Binding<Bool> {
        Binding(
            get: { newlyCollectedSite != nil && newlyCollectedStamp != nil },
            set: { isPresented in
                if !isPresented {
                    newlyCollectedSite = nil
                    newlyCollectedStamp = nil
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapRepresentable(
                overlayMap: mapSession.selectedOverlay,
                overlayOpacity: Float(mapSession.overlayOpacity),
                moveCameraRequest: mapSession.cameraMoveRequest,
                bottomInset: bottomPanelHeight,
                savedWalkPaths: savedRoutes.map(\.coordinates),
                liveWalkPath: locationManager.walkPath,
                checkpoints: activeCheckpoints,
                collectedSiteIDs: collectedSiteIDs,
                onTap: { coordinate in
                    tappedPoint = TappedPoint(coordinate: coordinate)
                }
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                actionButtonsRow
                OverlayControlPanel(
                    selectedOverlay: $mapSession.selectedOverlay,
                    overlayOpacity: $mapSession.overlayOpacity
                )
            }
            .padding(.bottom, 12)
        }
        .sheet(item: $tappedPoint) { point in
            StorySheetView(point: point, overlayMap: mapSession.selectedOverlay)
        }
        .sheet(isPresented: isCheckInSheetPresented) {
            if let newlyCollectedSite, let newlyCollectedStamp {
                StampCheckInSheet(site: newlyCollectedSite, stamp: newlyCollectedStamp)
            }
        }
        .onAppear {
            locationManager.requestPermissionIfNeeded()
        }
        .onChange(of: locationManager.walkPath.count) { _, _ in
            guard let latest = locationManager.walkPath.last else { return }
            checkForNewStamps(near: latest)
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
            mapSession.moveCamera(to: coordinate)
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
            defer { activeWalkSessionID = nil }
            guard path.count >= 2 else { return }
            modelContext.insert(WalkRoute(
                id: activeWalkSessionID ?? UUID(),
                coordinates: path,
                overlayMapID: mapSession.selectedOverlay?.id,
                overlayOpacity: mapSession.overlayOpacity
            ))
        } else {
            activeWalkSessionID = UUID()
            locationManager.startRecordingWalk()
        }
    }

    /// 記録中の現在地が、未獲得のチェックポイントに接近していれば御朱印を獲得する。
    private func checkForNewStamps(near coordinate: CLLocationCoordinate2D) {
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let alreadyCollected = collectedSiteIDs

        for site in activeCheckpoints where !alreadyCollected.contains(site.id) {
            let siteLocation = CLLocation(latitude: site.coordinate.latitude, longitude: site.coordinate.longitude)
            guard current.distance(from: siteLocation) <= stampCollectionRadiusMeters else { continue }

            let stamp = CollectedStamp(siteID: site.id, walkRouteID: activeWalkSessionID)
            modelContext.insert(stamp)
            newlyCollectedSite = site
            newlyCollectedStamp = stamp

            if let userID = authService.userID {
                Task { try? await syncService.upload(stamp, userID: userID) }
            }
            // 1回の更新で複数箇所に同時到達することは想定しないため、1件見つけたら終える。
            break
        }
    }
}

#Preview {
    MapScreen()
        .environmentObject(AuthService())
        .environmentObject(MapSessionState())
        .modelContainer(for: [SavedPlace.self, WalkRoute.self, CollectedStamp.self], inMemory: true)
}
