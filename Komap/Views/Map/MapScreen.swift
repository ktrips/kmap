import CoreLocation
import PhotosUI
import SwiftData
import SwiftUI

/// メインのマップ画面。現在地・古地図オーバーレイ・タップ操作をまとめる。
struct MapScreen: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var watchConnectivity = WatchConnectivityManager()
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var mapSession: MapSessionState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var savedRoutes: [WalkRoute]
    @Query private var collectedStamps: [CollectedStamp]

    @State private var tappedPoint: TappedPoint?
    /// チェックポイントのマーカー上の小さなアイコンボタンがタップされた時に表示する史跡。
    @State private var tappedCheckpoint: HistoricSite?
    @State private var newlyCollectedSite: HistoricSite?
    @State private var newlyCollectedStamp: CollectedStamp?
    /// 記録中のウォーキングを識別するID。停止時に`WalkRoute`へそのまま使い、
    /// 記録中に獲得した御朱印もこのIDで紐付ける。
    @State private var activeWalkSessionID: UUID?
    /// 「記録終了」を押した直後、保存するかどうかの確認待ちになっているルート。
    /// 「保存する」が選ばれたらこの内容で`WalkRoute`を作成する。
    @State private var pendingWalkRoute: PendingWalkRoute?
    /// 記録中に自由なタイミングで写真を投稿するためのピッカー選択値。
    @State private var photoPostPickerItem: PhotosPickerItem?
    @State private var isPostingPhoto = false
    /// 写真投稿で獲得したポイントを一瞬だけ知らせるトースト表示。
    @State private var pointsToastMessage: String?

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
                },
                onCheckpointTap: { site in
                    tappedCheckpoint = site
                }
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                actionButtonsRow
                OverlayControlPanel(
                    selectedOverlay: $mapSession.selectedOverlay,
                    overlayOpacity: $mapSession.overlayOpacity,
                    onSelect: { overlay in
                        if let overlay {
                            mapSession.moveCamera(to: overlay.center)
                        }
                    }
                )
            }
            .padding(.bottom, 12)
        }
        .overlay(alignment: .top) {
            if let pointsToastMessage {
                Text(pointsToastMessage)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.72, green: 0.53, blue: 0.15), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $tappedPoint) { point in
            StorySheetView(point: point, overlayMap: mapSession.selectedOverlay)
        }
        .sheet(item: $tappedCheckpoint) { site in
            CheckpointInfoSheet(site: site, overlayMap: mapSession.selectedOverlay)
        }
        .sheet(isPresented: isCheckInSheetPresented) {
            if let newlyCollectedSite, let newlyCollectedStamp {
                StampCheckInSheet(site: newlyCollectedSite, stamp: newlyCollectedStamp)
            }
        }
        .onAppear {
            locationManager.requestPermissionIfNeeded()
            syncWatchState()
        }
        .onChange(of: locationManager.walkPath.count) { _, _ in
            guard let latest = locationManager.walkPath.last else { return }
            checkForNewStamps(near: latest)
        }
        .onChange(of: photoPostPickerItem) { _, newItem in
            loadAndPostPhoto(newItem)
        }
        .onChange(of: locationManager.isRecordingWalk) { _, _ in
            syncWatchState()
        }
        .onChange(of: locationManager.isWalkPaused) { _, _ in
            syncWatchState()
        }
        .onChange(of: mapSession.selectedOverlay) { _, _ in
            syncWatchState()
        }
        .onChange(of: watchConnectivity.lastCommand) { _, command in
            handleWatchCommand(command)
        }
        .confirmationDialog(
            "この時間旅を保存しますか？",
            isPresented: isSaveConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("保存する") { confirmPendingWalkRoute() }
            Button("保存しない", role: .destructive) { discardPendingWalkRoute() }
        } message: {
            Text("使った古地図・歩いたルート・通ったチェックポイントや御朱印を「わたしの時間旅行」に記録します。")
        }
    }

    private var isSaveConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingWalkRoute != nil },
            set: { isPresented in
                if !isPresented { discardPendingWalkRoute() }
            }
        )
    }

    private var actionButtonsRow: some View {
        HStack(spacing: 8) {
            Spacer()
            if locationManager.isRecordingWalk {
                photoPostButton
                pauseResumeButton
            }
            walkRecordButton
            Spacer()
        }
    }

    private var walkRecordButton: some View {
        Button {
            toggleWalkRecording()
        } label: {
            Label(
                locationManager.isRecordingWalk ? "終了" : "スタート",
                systemImage: locationManager.isRecordingWalk ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(locationManager.isRecordingWalk ? .white : .primary)
            .background(
                locationManager.isRecordingWalk ? AnyShapeStyle(Color.red) : AnyShapeStyle(.regularMaterial),
                in: Capsule()
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .disabled(locationManager.currentLocation == nil && !locationManager.isRecordingWalk)
    }

    private var pauseResumeButton: some View {
        Button {
            toggleWalkPause()
        } label: {
            Label(
                locationManager.isWalkPaused ? "再開" : "一時停止",
                systemImage: locationManager.isWalkPaused ? "play.circle.fill" : "pause.circle.fill"
            )
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                locationManager.isWalkPaused ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.orange),
                in: Capsule()
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
    }

    private var photoPostButton: some View {
        PhotosPicker(selection: $photoPostPickerItem, matching: .images) {
            Group {
                if isPostingPhoto {
                    ProgressView()
                } else {
                    Label("写真投稿", systemImage: "camera.fill")
                }
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.primary)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .disabled(isPostingPhoto)
    }

    /// 「スタート」で記録を開始し、もう一度押すと記録を終える。
    /// 2点以上歩いていれば、保存するかどうかを確認するダイアログを表示する。
    private func toggleWalkRecording() {
        if locationManager.isRecordingWalk {
            let path = locationManager.stopRecordingWalk()
            guard path.count >= 2, let sessionID = activeWalkSessionID else {
                activeWalkSessionID = nil
                return
            }
            pendingWalkRoute = PendingWalkRoute(
                id: sessionID,
                coordinates: path,
                overlayMapID: mapSession.selectedOverlay?.id,
                overlayOpacity: mapSession.overlayOpacity
            )
        } else {
            activeWalkSessionID = UUID()
            locationManager.startRecordingWalk()
        }
    }

    /// 記録中の一時停止・再開を切り替える。
    private func toggleWalkPause() {
        if locationManager.isWalkPaused {
            locationManager.resumeRecordingWalk()
        } else {
            locationManager.pauseRecordingWalk()
        }
    }

    /// Apple Watch側から届いたコマンドを、対応するアクションへ反映する。
    private func handleWatchCommand(_ command: WatchConnectivityManager.Command?) {
        guard let command else { return }
        switch command {
        case .start:
            if !locationManager.isRecordingWalk {
                toggleWalkRecording()
            }
        case .pause:
            if locationManager.isRecordingWalk && !locationManager.isWalkPaused {
                toggleWalkPause()
            }
        case .resume:
            if locationManager.isRecordingWalk && locationManager.isWalkPaused {
                toggleWalkPause()
            }
        case .stop:
            if locationManager.isRecordingWalk {
                toggleWalkRecording()
            }
        case .selectMap(let id):
            guard let overlay = OldMapCatalog.all.first(where: { $0.id == id }) else { return }
            mapSession.selectedOverlay = overlay
            mapSession.moveCamera(to: overlay.center)
        }
    }

    /// 現在の記録状態・選択中の古地図をWatchへ送る。
    private func syncWatchState() {
        watchConnectivity.updateState(
            isRecording: locationManager.isRecordingWalk,
            isPaused: locationManager.isWalkPaused,
            availableMaps: OldMapCatalog.all,
            selectedMapID: mapSession.selectedOverlay?.id
        )
    }

    /// 記録中に選んだ写真を保存し、ポイントを付与した`WalkPhotoPost`を作成する。
    private func loadAndPostPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        photoPostPickerItem = nil
        isPostingPhoto = true
        Task {
            defer { isPostingPhoto = false }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let filename = StampPhotoStore.save(uiImage),
                  let coordinate = locationManager.currentLocation ?? locationManager.walkPath.last
            else { return }

            let post = WalkPhotoPost(
                photoFileName: filename,
                coordinate: coordinate,
                walkRouteID: activeWalkSessionID
            )
            modelContext.insert(post)

            withAnimation {
                pointsToastMessage = "+\(post.points)pt 獲得！"
            }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation {
                pointsToastMessage = nil
            }
        }
    }

    /// 確認ダイアログで「保存する」が選ばれた時、蓄積しておいた内容で`WalkRoute`を作成する。
    private func confirmPendingWalkRoute() {
        guard let pending = pendingWalkRoute else { return }
        modelContext.insert(WalkRoute(
            id: pending.id,
            coordinates: pending.coordinates,
            overlayMapID: pending.overlayMapID,
            overlayOpacity: pending.overlayOpacity
        ))
        pendingWalkRoute = nil
        activeWalkSessionID = nil
    }

    /// 「保存しない」が選ばれた、またはダイアログが閉じられた時、記録を破棄する。
    /// 記録中に獲得した御朱印は「わたしの時間旅行」への記録とは切り離して、
    /// 御朱印帳の獲得実績としてはそのまま残す。
    private func discardPendingWalkRoute() {
        pendingWalkRoute = nil
        activeWalkSessionID = nil
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

/// 「記録終了」を押した直後、保存確認ダイアログの結果待ちで保持しておく内容。
/// ここではまだ`WalkRoute`（SwiftDataモデル）にはせず、確認が取れてから
/// `modelContext.insert`する。
private struct PendingWalkRoute {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    let overlayMapID: String?
    let overlayOpacity: Double
}

#Preview {
    MapScreen()
        .environmentObject(AuthService())
        .environmentObject(MapSessionState())
        .modelContainer(for: [SavedPlace.self, WalkRoute.self, CollectedStamp.self, WalkPhotoPost.self], inMemory: true)
}
