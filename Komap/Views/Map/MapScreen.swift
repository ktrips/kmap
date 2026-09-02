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
    @Query private var photoPosts: [WalkPhotoPost]

    @State private var tappedPoint: TappedPoint?
    /// チェックポイントのマーカー上の小さなアイコンボタンがタップされた時に表示する史跡。
    @State private var tappedCheckpoint: HistoricSite?
    /// 地図上の写真ピンがタップされた時に表示する投稿。
    @State private var tappedPhotoPost: WalkPhotoPost?
    @State private var newlyCollectedSite: HistoricSite?
    @State private var newlyCollectedStamp: CollectedStamp?
    /// 記録中のウォーキングを識別するID。停止時に`WalkRoute`へそのまま使い、
    /// 記録中に獲得した御朱印もこのIDで紐付ける。
    @State private var activeWalkSessionID: UUID?
    /// 記録を開始した日時。歩いた時間の算出に使う。
    @State private var activeWalkStartedAt: Date?
    /// 「記録終了」を押した直後、保存するかどうかの確認待ちになっているルート。
    /// 「保存する」が選ばれたらこの内容で`WalkRoute`を作成する。
    @State private var pendingWalkRoute: PendingWalkRoute?
    /// 記録中に自由なタイミングで写真を投稿するためのピッカー選択値。
    @State private var photoPostPickerItem: PhotosPickerItem?
    @State private var isPostingPhoto = false
    /// 写真投稿で獲得したポイントを一瞬だけ知らせるトースト表示。
    @State private var pointsToastMessage: String?
    /// 「新しい古地図を登録」から開く検索シートの表示状態。
    @State private var isShowingOldMapSearch = false
    /// Watch自身のGPSで記録中かどうか（GPSはWatch側、iPhoneはこの状態を表示するだけ）。
    @State private var isWatchTrackingActive = false
    @State private var isWatchTrackingPaused = false
    /// Watch自身のGPSで記録中のセッションID。iPhone側の`activeWalkSessionID`が無い間、
    /// このIDで写真投稿・御朱印獲得を紐付け、記録終了時に届く`WalkRoute`と一致させる。
    @State private var activeWatchSessionID: UUID?
    /// Watch単体のGPSで記録中、Watchから転送されてきた軌跡。iPhone側の地図にも
    /// リアルタイムで表示するために使う（GPS自体はWatch側のまま）。
    @State private var watchTrackedPath: [CLLocationCoordinate2D] = []
    /// カメラで写真を撮って投稿するためのシート表示状態。
    @State private var isShowingPhotoPostCamera = false
    /// 「全ての古地図を表示」が選ばれているかどうか。
    @State private var isShowingAllOverlays = false

    private let syncService = SyncService()
    private let stepCounter = StepCounter()

    /// この距離（メートル）以内にチェックポイントへ近づいたら御朱印を獲得する。
    private let stampCollectionRadiusMeters: CLLocationDistance = 60

    /// 画面下部に浮かせているパネル（アクションボタン＋古地図コントロール）が占める高さ。
    /// Google純正の現在地ボタンなどがこのパネルに隠れて押せなくなるのを防ぐため、
    /// `GoogleMapRepresentable` にこの分の下余白を持たせる。
    private let bottomPanelHeight: CGFloat = 175

    private var collectedSiteIDs: Set<String> {
        Set(collectedStamps.map(\.siteID))
    }

    /// 現在選択中の古地図に紐づくチェックポイント（5箇所程度）。
    /// 「全ての古地図を表示」中は、同梱・登録済みの古地図すべてのチェックポイントを返す。
    /// 同じ実在の場所が複数の古地図（谷中七福神と上野の不忍池辯天堂など）にまたがって
    /// 登録されている場合、マーカーが同じ座標に重なって表示がおかしくなるため、
    /// 座標が同じチェックポイントは1つにまとめる。
    private var activeCheckpoints: [HistoricSite] {
        if isShowingAllOverlays {
            var seenCoordinateKeys = Set<String>()
            return HistoricSiteCatalog.all.filter { site in
                let key = "\((site.coordinate.latitude * 100_000).rounded()),\((site.coordinate.longitude * 100_000).rounded())"
                return seenCoordinateKeys.insert(key).inserted
            }
        }
        return HistoricSiteCatalog.sites(forOverlayID: mapSession.selectedOverlay?.id)
    }

    /// 今の記録セッションのID。iPhoneでの記録中は`activeWalkSessionID`、
    /// Apple Watch単体での記録中は`activeWatchSessionID`を使う。
    /// 御朱印獲得・写真投稿を、後で作られる`WalkRoute`と正しく紐付けるために使う。
    private var currentSessionID: UUID? {
        activeWalkSessionID ?? activeWatchSessionID
    }

    /// 地図に描く「記録中の軌跡」。iPhoneで記録中はiPhone自身のGPS、Apple Watch単体で
    /// 記録中はWatchから転送された軌跡を使う。
    private var displayedLiveWalkPath: [CLLocationCoordinate2D] {
        isWatchTrackingActive ? watchTrackedPath : locationManager.walkPath
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
                showAllOverlays: isShowingAllOverlays,
                moveCameraRequest: mapSession.cameraMoveRequest,
                bottomInset: bottomPanelHeight,
                savedWalkPaths: savedRoutes.map(\.coordinates),
                liveWalkPath: displayedLiveWalkPath,
                checkpoints: activeCheckpoints,
                collectedSiteIDs: collectedSiteIDs,
                photoPosts: photoPosts,
                onTap: { coordinate in
                    tappedPoint = TappedPoint(coordinate: coordinate)
                },
                onCheckpointTap: { site in
                    if isShowingAllOverlays {
                        // 「全ての古地図を表示」中にチェックポイントを押したら、
                        // その古地図単体の表示に切り替える。
                        isShowingAllOverlays = false
                        mapSession.selectedOverlay = OldMapCatalog.allIncludingCustom.first { $0.id == site.overlayMapID }
                    } else {
                        tappedCheckpoint = site
                    }
                },
                onPhotoPostTap: { post in
                    tappedPhotoPost = post
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                actionButtonsRow
                OverlayControlPanel(
                    selectedOverlay: $mapSession.selectedOverlay,
                    overlayOpacity: $mapSession.overlayOpacity,
                    isShowingAllOverlays: $isShowingAllOverlays,
                    onSelect: { _ in
                        // カメラ移動は`GoogleMapRepresentable`側で、古地図の範囲と
                        // チェックポイントが収まるよう自動的に行う。
                    },
                    onRequestSearch: {
                        isShowingOldMapSearch = true
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
        .sheet(isPresented: $isShowingOldMapSearch) {
            OldMapSearchView(onAdd: { overlay in
                mapSession.selectedOverlay = overlay
            })
        }
        .sheet(item: $tappedPoint) { point in
            StorySheetView(point: point, overlayMap: mapSession.selectedOverlay)
        }
        .sheet(item: $tappedCheckpoint) { site in
            CheckpointInfoSheet(site: site, overlayMap: mapSession.selectedOverlay)
        }
        .sheet(item: $tappedPhotoPost) { post in
            PhotoPostPreviewSheet(post: post)
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
        .onChange(of: watchConnectivity.isActivated) { _, isActivated in
            if isActivated {
                syncWatchState()
            }
        }
        .onChange(of: watchConnectivity.lastCommand) { _, command in
            handleWatchCommand(command)
        }
        .sheet(isPresented: isSaveConfirmationPresented) {
            WalkSaveDecisionSheet(
                onSave: confirmPendingWalkRoute,
                onDiscard: discardPendingWalkRoute
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.hidden)
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
            if isWatchTrackingActive {
                watchTrackingIndicator
                photoPostButton
            } else {
                if locationManager.isRecordingWalk {
                    photoPostButton
                    pauseResumeButton
                }
                walkRecordButton
            }
            Spacer()
        }
    }

    /// Watch自身のGPSで記録中の時に、iPhone側では操作ボタンの代わりに表示する状態表示。
    /// 一時停止・終了はWatch側でのみ行える。
    private var watchTrackingIndicator: some View {
        Label(
            isWatchTrackingPaused ? "Watchで一時停止中" : "Watchで記録中",
            systemImage: "applewatch"
        )
        .font(.subheadline.bold())
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(.white)
        .background(isWatchTrackingPaused ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.blue), in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }

    private var walkRecordButton: some View {
        Button {
            toggleWalkRecording()
        } label: {
            Label(
                locationManager.isRecordingWalk ? "完了" : "スタート",
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
        Menu {
            Button {
                isShowingPhotoPostCamera = true
            } label: {
                Label("カメラで撮る", systemImage: "camera.fill")
            }
            PhotosPicker(selection: $photoPostPickerItem, matching: .images) {
                Label("ライブラリから選ぶ", systemImage: "photo.on.rectangle")
            }
        } label: {
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
        .fullScreenCover(isPresented: $isShowingPhotoPostCamera) {
            CameraCaptureView(
                onCapture: { image in
                    isShowingPhotoPostCamera = false
                    postPhoto(image)
                },
                onCancel: { isShowingPhotoPostCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    /// 「スタート」で記録を開始し、もう一度押すと記録を終える。
    /// 2点以上歩いていれば、保存するかどうかを確認するダイアログを表示する。
    private func toggleWalkRecording() {
        if locationManager.isRecordingWalk {
            stopWalkRecording(autoSave: false)
        } else {
            startWalkRecording()
        }
    }

    private func startWalkRecording() {
        activeWalkSessionID = UUID()
        activeWalkStartedAt = Date()
        stepCounter.start()
        locationManager.startRecordingWalk()
    }

    /// 記録を終える。`autoSave`が`true`の時（Apple Watchからの「終了」など、
    /// 保存確認ダイアログを見せられない場面）は確認を挟まずそのまま保存する。
    private func stopWalkRecording(autoSave: Bool) {
        let path = locationManager.stopRecordingWalk()
        guard path.count >= 2, let sessionID = activeWalkSessionID, let startedAt = activeWalkStartedAt else {
            activeWalkSessionID = nil
            activeWalkStartedAt = nil
            return
        }
        let endedAt = Date()
        Task {
            let stepCount = await stepCounter.finish()
            let pending = PendingWalkRoute(
                id: sessionID,
                coordinates: path,
                startedAt: startedAt,
                endedAt: endedAt,
                stepCount: stepCount,
                overlayMapID: mapSession.selectedOverlay?.id,
                overlayOpacity: mapSession.overlayOpacity
            )
            if autoSave {
                save(pending)
                activeWalkSessionID = nil
                activeWalkStartedAt = nil
            } else {
                pendingWalkRoute = pending
            }
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
                // 保存するかどうかの確認はWatch側のシートで既に済んでいるため、そのまま保存する。
                stopWalkRecording(autoSave: true)
            }
        case .discard:
            if locationManager.isRecordingWalk {
                discardActiveWalkRecording()
            }
        case .selectMap(let id):
            guard let overlay = OldMapCatalog.allIncludingCustom.first(where: { $0.id == id }) else { return }
            mapSession.selectedOverlay = overlay
            mapSession.moveCamera(to: overlay.center)
        case .watchTrackingStarted(let sessionID):
            isWatchTrackingActive = true
            isWatchTrackingPaused = false
            activeWatchSessionID = UUID(uuidString: sessionID)
            watchTrackedPath = []
        case .watchTrackingPaused:
            isWatchTrackingPaused = true
        case .watchTrackingResumed:
            isWatchTrackingPaused = false
        case .watchTrackingFinished(let route):
            isWatchTrackingActive = false
            isWatchTrackingPaused = false
            activeWatchSessionID = nil
            watchTrackedPath = []
            saveWatchTrackedRoute(route)
        case .watchTrackingDiscarded:
            isWatchTrackingActive = false
            isWatchTrackingPaused = false
            activeWatchSessionID = nil
            watchTrackedPath = []
        case .watchLocationUpdate(let coordinate):
            // Watch単体のGPSで記録中は、iPhone側の地図にもリアルタイムで軌跡を表示し、
            // iPhone側の位置情報だけでは気づけない御朱印チェックポイントの判定も行う。
            guard isWatchTrackingActive else { return }
            watchTrackedPath.append(coordinate)
            checkForNewStamps(near: coordinate)
        }
    }

    /// Watch単体のGPSで記録し終えた軌跡を、確認ダイアログを挟まずそのまま保存する
    /// （保存確認はWatch側で既に済んでいるため）。`WalkRoute`のIDはWatchのセッションIDと
    /// 揃え、記録中にiPhoneへ転送された御朱印・写真投稿がこの記録に正しく紐付くようにする。
    private func saveWatchTrackedRoute(_ route: WatchTrackedRoute) {
        guard route.coordinates.count >= 2 else { return }
        let walkRoute = WalkRoute(
            id: UUID(uuidString: route.sessionID) ?? UUID(),
            coordinates: route.coordinates,
            startedAt: route.startedAt,
            endedAt: route.endedAt,
            stepCount: route.stepCount,
            overlayMapID: mapSession.selectedOverlay?.id,
            overlayOpacity: mapSession.overlayOpacity
        )
        modelContext.insert(walkRoute)
        try? modelContext.save()

        if let userID = authService.userID {
            Task { try? await syncService.upload(walkRoute, userID: userID) }
        }
    }

    /// 現在の記録状態・選択中の古地図をWatchへ送る。
    private func syncWatchState() {
        watchConnectivity.updateState(
            isRecording: locationManager.isRecordingWalk,
            isPaused: locationManager.isWalkPaused,
            availableMaps: OldMapCatalog.allIncludingCustom,
            selectedMapID: mapSession.selectedOverlay?.id
        )
    }

    /// 記録中に選んだ写真を読み込み、`postPhoto`で投稿する。
    private func loadAndPostPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        photoPostPickerItem = nil
        isPostingPhoto = true
        Task {
            defer { isPostingPhoto = false }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else { return }
            postPhoto(uiImage)
        }
    }

    /// 撮影・選択した写真を保存し、ポイントを付与した`WalkPhotoPost`を作成する。
    /// Apple Watch側にもトーストで知らせる。
    private func postPhoto(_ uiImage: UIImage) {
        guard let filename = StampPhotoStore.save(uiImage),
              let coordinate = locationManager.currentLocation ?? locationManager.walkPath.last ?? watchTrackedPath.last
        else { return }

        let post = WalkPhotoPost(
            photoFileName: filename,
            coordinate: coordinate,
            walkRouteID: currentSessionID
        )
        modelContext.insert(post)
        watchConnectivity.notifyPhotoPosted(points: post.points)

        if let userID = authService.userID {
            Task {
                try? await syncService.uploadPhotoPostImage(post, userID: userID)
                try? modelContext.save()
            }
        }

        Task {
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
        save(pending)
        pendingWalkRoute = nil
        activeWalkSessionID = nil
        activeWalkStartedAt = nil
    }

    /// 「保存しない」が選ばれた、またはダイアログが閉じられた時、記録を破棄する。
    /// 記録中に獲得した御朱印は「わたしの時間旅行」への記録とは切り離して、
    /// 御朱印帳の獲得実績としてはそのまま残す。
    private func discardPendingWalkRoute() {
        pendingWalkRoute = nil
        activeWalkSessionID = nil
        activeWalkStartedAt = nil
    }

    /// Watchの保存確認シートで「破棄」が選ばれた時、記録中のGPS計測を止めて何も保存しない。
    private func discardActiveWalkRecording() {
        _ = locationManager.stopRecordingWalk()
        activeWalkSessionID = nil
        activeWalkStartedAt = nil
    }

    private func save(_ pending: PendingWalkRoute) {
        let route = WalkRoute(
            id: pending.id,
            coordinates: pending.coordinates,
            startedAt: pending.startedAt,
            endedAt: pending.endedAt,
            stepCount: pending.stepCount,
            overlayMapID: pending.overlayMapID,
            overlayOpacity: pending.overlayOpacity
        )
        modelContext.insert(route)
        try? modelContext.save()

        if let userID = authService.userID {
            Task { try? await syncService.upload(route, userID: userID) }
        }
    }

    /// 記録中の現在地が、未獲得のチェックポイントに接近していれば御朱印を獲得する。
    private func checkForNewStamps(near coordinate: CLLocationCoordinate2D) {
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let alreadyCollected = collectedSiteIDs

        for site in activeCheckpoints where !alreadyCollected.contains(site.id) {
            let siteLocation = CLLocation(latitude: site.coordinate.latitude, longitude: site.coordinate.longitude)
            guard current.distance(from: siteLocation) <= stampCollectionRadiusMeters else { continue }

            let stamp = CollectedStamp(siteID: site.id, walkRouteID: currentSessionID)
            modelContext.insert(stamp)
            newlyCollectedSite = site
            newlyCollectedStamp = stamp
            watchConnectivity.notifyStampCollected(siteName: site.name, siteSummary: site.summary)

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
    let startedAt: Date
    let endedAt: Date
    let stepCount: Int?
    let overlayMapID: String?
    let overlayOpacity: Double
}

/// 「完了」を押した直後に出す保存確認シート。
/// 誤って破棄しないよう、「保存」を大きく目立たせ、「破棄」はその下に小さく置く。
private struct WalkSaveDecisionSheet: View {
    let onSave: () -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// 「破棄」を押した直後、誤操作を防ぐための小さな確認待ち状態。
    @State private var isConfirmingDiscard = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("この時間旅を保存しますか？")
                    .font(.headline)
                Text("使った古地図・歩いたルート・通ったチェックポイントや御朱印を「My Trips」に記録します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            Button {
                onSave()
                dismiss()
            } label: {
                Text("保存")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if isConfirmingDiscard {
                VStack(spacing: 6) {
                    Text("本当に破棄しますか？")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Button("キャンセル") { isConfirmingDiscard = false }
                            .font(.caption)
                        Button("破棄する", role: .destructive) {
                            onDiscard()
                            dismiss()
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Text("破棄")
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.15), value: isConfirmingDiscard)
    }
}

#Preview {
    MapScreen()
        .environmentObject(AuthService())
        .environmentObject(MapSessionState())
        .modelContainer(for: [SavedPlace.self, WalkRoute.self, CollectedStamp.self, WalkPhotoPost.self], inMemory: true)
}
