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
    /// マップをタップした直後、「新しいポイントを追加しますか？」の確認待ちの座標。
    /// ここで確認してからAIへ問い合わせることで、探索中の何気ないタップで
    /// AI（課金対象）を無駄に呼び出さないようにする。
    @State private var pendingTapPoint: TappedPoint?
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
    /// 「写真投稿」メニューの「ライブラリから選ぶ」を押した時に、`.photosPicker`を
    /// プログラム的に開くためのフラグ（`Menu`内に`PhotosPicker`を直接置くと
    /// 開かないため）。
    @State private var isShowingPhotoLibraryPicker = false
    @State private var isPostingPhoto = false
    /// 写真投稿で獲得したポイントを一瞬だけ知らせるトースト表示。
    @State private var pointsToastMessage: String?
    /// 写真投稿のクラウドアップロードに失敗した時のメッセージ。
    /// 失敗しても端末には保存されているが、原因がわかるよう表示しておく。
    @State private var photoSyncErrorMessage: String?
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
    /// 現在地にカメラを追従させ続けるかどうか。基本は現在地中心のままにし、
    /// ユーザーが指で地図をドラッグ・ピンチ操作したら追従をやめる
    /// （現在地ボタンを押す・「スタート」を押すと再び追従を始める）。
    @State private var isFollowingCurrentLocation = true

    private let syncService = SyncService()
    private let stepCounter = StepCounter()
    /// Apple Watchと連携して歩いた記録の歩数を、Apple Healthからより正確に取得するために使う。
    private let healthKitStepReader = HealthKitStepReader()

    /// この距離（メートル）以内にチェックポイントへ近づいたら御朱印を獲得する。
    private let stampCollectionRadiusMeters: CLLocationDistance = 60

    /// 歩いて記録中は「古地図の上を歩いている」ように見せたいので、古地図が
    /// 選ばれていなければ自動で表示し、不透明度もこの値まで引き上げる
    /// （既にこれより濃く見せている場合はそのまま）。
    private let walkingOverlayOpacity: Double = 0.75

    /// 画面下部に浮かせているパネル（アクションボタン＋古地図コントロール）が占める高さ。
    /// Google純正の現在地ボタンなどがこのパネルに隠れて押せなくなるのを防ぐため、
    /// `GoogleMapRepresentable` にこの分の下余白を持たせる。
    private let bottomPanelHeight: CGFloat = 100

    private var collectedSiteIDs: Set<String> {
        Set(collectedStamps.map(\.siteID))
    }

    /// 現在選択中の古地図に紐づくチェックポイント（5箇所程度）。
    /// 「全ての古地図を表示」中は、同梱・登録済みの古地図すべてのチェックポイントを返す。
    /// 同じ実在の場所が複数の古地図（谷中七福神と上野の不忍池辯天堂など）にまたがって
    /// 登録されている場合、マーカーが同じ座標に重なって表示がおかしくなるため、
    /// 座標が同じチェックポイントは1つにまとめる。
    ///
    /// - Important: GPSの更新など、選択中の古地図と無関係な理由でもこの画面のbodyは
    ///   頻繁に再評価される。ここを計算プロパティのままにすると、その都度
    ///   （「全ての古地図を表示」中は約70件の）フィルタ処理をやり直すことになるため、
    ///   `cachedActiveCheckpoints`に結果をキャッシュし、実際に古地図の選択が
    ///   変わった時だけ`recomputeActiveCheckpoints()`で更新する。
    @State private var cachedActiveCheckpoints: [HistoricSite] = []

    private func recomputeActiveCheckpoints() {
        if mapSession.isShowingAllOverlays {
            var seenCoordinateKeys = Set<String>()
            cachedActiveCheckpoints = HistoricSiteCatalog.all.filter { site in
                let key = "\((site.coordinate.latitude * 100_000).rounded()),\((site.coordinate.longitude * 100_000).rounded())"
                return seenCoordinateKeys.insert(key).inserted
            }
        } else {
            cachedActiveCheckpoints = HistoricSiteCatalog.sites(forOverlayID: mapSession.selectedOverlay?.id)
        }
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
                showAllOverlays: mapSession.isShowingAllOverlays,
                moveCameraRequest: mapSession.cameraMoveRequest,
                bottomInset: bottomPanelHeight,
                savedWalkPaths: savedRoutes.filter { !$0.isHiddenOnMap }.map(\.coordinates),
                liveWalkPath: displayedLiveWalkPath,
                isRecordingWalk: locationManager.isRecordingWalk || isWatchTrackingActive,
                checkpoints: cachedActiveCheckpoints,
                collectedSiteIDs: collectedSiteIDs,
                photoPosts: photoPosts,
                onTap: { coordinate in
                    pendingTapPoint = TappedPoint(coordinate: coordinate)
                },
                onCheckpointTap: { site in
                    // 「全ての古地図を表示」中でも、チェックポイントの名称を押した時は
                    // 単体表示に切り替えず（他のマーカーが消えてしまうため）、
                    // そのまま詳細シートを開く。
                    tappedCheckpoint = site
                },
                onPhotoPostTap: { post in
                    tappedPhotoPost = post
                },
                onUserPanned: {
                    isFollowingCurrentLocation = false
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                actionButtonsRow
                OverlayControlPanel(
                    selectedOverlay: $mapSession.selectedOverlay,
                    overlayOpacity: $mapSession.overlayOpacity,
                    isShowingAllOverlays: $mapSession.isShowingAllOverlays,
                    onSelect: { _ in
                        // カメラ移動は`GoogleMapRepresentable`側で、古地図の範囲と
                        // チェックポイントが収まるよう自動的に行う。
                    },
                    onRequestSearch: {
                        mapSession.isShowingOldMapSearch = true
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
            } else if let photoSyncErrorMessage {
                Text(photoSyncErrorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    .padding(.top, 8)
                    .multilineTextAlignment(.center)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $mapSession.isShowingOldMapSearch) {
            OldMapSearchView(onAdd: { overlay in
                mapSession.selectedOverlay = overlay
            })
        }
        .alert(
            "新しいポイントを追加しますか？",
            isPresented: Binding(
                get: { pendingTapPoint != nil },
                set: { isPresented in if !isPresented { pendingTapPoint = nil } }
            ),
            presenting: pendingTapPoint
        ) { point in
            Button("追加する") {
                tappedPoint = point
                pendingTapPoint = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingTapPoint = nil
            }
        } message: { _ in
            Text("この場所の昔の物語をAIが生成します。")
        }
        .sheet(item: $tappedPoint) { point in
            StorySheetView(point: point, overlayMap: mapSession.selectedOverlay)
        }
        .sheet(item: $tappedCheckpoint) { site in
            CheckpointInfoSheet(
                site: site,
                overlayMap: OldMapCatalog.allIncludingCustom.first { $0.id == site.overlayMapID }
            )
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
            recomputeActiveCheckpoints()
        }
        .onChange(of: mapSession.selectedOverlay?.id) { _, _ in
            recomputeActiveCheckpoints()
        }
        .onChange(of: mapSession.isShowingAllOverlays) { _, _ in
            recomputeActiveCheckpoints()
        }
        .onChange(of: locationManager.walkPath.count) { _, _ in
            guard let latest = locationManager.walkPath.last else { return }
            checkForNewStamps(near: latest)
        }
        .onChange(of: locationManager.locationUpdateTick) { _, _ in
            // 記録中でない時（古地図を切り替えて眺めているだけの時など）まで追従すると、
            // チェックポイントに合わせたカメラフィットを現在地追従が直後に上書きしてしまい、
            // マーカーが画面外へ出て「消えた」ように見えてしまう。歩行記録中だけ追従する。
            guard isFollowingCurrentLocation,
                  locationManager.isRecordingWalk || isWatchTrackingActive,
                  let coordinate = locationManager.currentLocation
            else { return }
            mapSession.moveCamera(to: coordinate)
        }
        .onChange(of: photoPostPickerItem) { _, newItem in
            loadAndPostPhoto(newItem)
        }
        .onChange(of: locationManager.isRecordingWalk) { _, _ in
            syncWatchState()
            showOldMapForWalkingIfNeeded()
        }
        .onChange(of: isWatchTrackingActive) { _, _ in
            showOldMapForWalkingIfNeeded()
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

    /// Google純正の現在地ボタンより小さい、自前の現在地ボタン。
    /// 押すと現在地へカメラを移動する（現在地の「青い点」自体は`GMSMapView`側のまま）。
    /// 「スタート」など他のアクションボタンと横一線に並ぶよう、`actionButtonsRow`の
    /// トレイリング側に置く。
    private var currentLocationButton: some View {
        Button {
            isFollowingCurrentLocation = true
            if let coordinate = locationManager.currentLocation {
                mapSession.moveCamera(to: coordinate)
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 16.8, weight: .semibold)) // 14の20%増し
                .foregroundStyle(.primary)
                .frame(width: 38.4, height: 38.4) // 32の20%増し
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .disabled(locationManager.currentLocation == nil)
        .padding(.trailing, 9) // ほんの少しだけ左に寄せる
    }

    /// 「スタート」などの操作ボタン群を画面幅の中央に、現在地ボタンを右端に配置する。
    /// 以前は同じ`HStack`に両方を並べていたため、右端の現在地ボタンの分だけ
    /// 操作ボタン群の見た目の中心が左へずれて見えていた。現在地ボタンを別レイヤーの
    /// `overlay`にして独立させることで、操作ボタン群を画面の真ん中に置けるようにした。
    private var actionButtonsRow: some View {
        HStack(spacing: 8) {
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
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            currentLocationButton
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
            .font(.system(size: 18, weight: .bold)) // subheadline(15)の20%増し
            .padding(.horizontal, 16.8) // 14の20%増し
            .padding(.vertical, 12) // 10の20%増し
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
            // `PhotosPicker`をこのまま`Menu`の項目にすると、タップしてもメニューが
            // 閉じるだけでピッカーが開かない（`Menu`内では`PhotosPicker`の標準の
            // 見た目・挙動が正しく機能しないSwiftUI/PhotosUI側の既知の制約）。
            // 代わりに普通の`Button`でフラグを立て、`.photosPicker(isPresented:)`
            // をこのビュー自体に付けてプログラム的に開く。
            Button {
                isShowingPhotoLibraryPicker = true
            } label: {
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
        .photosPicker(isPresented: $isShowingPhotoLibraryPicker, selection: $photoPostPickerItem, matching: .images)
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
        Task { await healthKitStepReader.requestAuthorizationIfNeeded() }
        locationManager.startRecordingWalk()
        isFollowingCurrentLocation = true
        if let coordinate = locationManager.currentLocation {
            mapSession.moveCamera(to: coordinate)
        }
        showOldMapForWalkingIfNeeded()
    }

    /// 歩いて記録中（iPhone本体・Apple Watchどちらでも）は、古地図の上を
    /// 歩いているように見えるよう、古地図が表示されていなければ表示し、
    /// 不透明度もある程度濃くする。ユーザーが既にそれ以上濃くしていれば触らない。
    private func showOldMapForWalkingIfNeeded() {
        guard locationManager.isRecordingWalk || isWatchTrackingActive else { return }
        if mapSession.selectedOverlay == nil && !mapSession.isShowingAllOverlays {
            mapSession.selectedOverlay = OldMapCatalog.edoCastle
        }
        if mapSession.overlayOpacity < walkingOverlayOpacity {
            mapSession.overlayOpacity = walkingOverlayOpacity
        }
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
            // Apple Watchと連携していた場合、Apple Healthの歩数（Watch・iPhone双方の
            // センサー値がまとめて記録される）の方がiPhone単体の`CMPedometer`より
            // 実態に近いため、取得できればそちらを優先する。
            let pedometerStepCount = await stepCounter.finish()
            let healthStepCount = await healthKitStepReader.stepCount(from: startedAt, to: endedAt)
            let stepCount = healthStepCount ?? pedometerStepCount
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
        case .watchTrackingSnapshot(let sessionID, let coordinates):
            // iPhoneがロック中・バックグラウンドなどで`watchLocationUpdate`を取りこぼしていた間も、
            // ここで累積軌跡に追いつく。別セッションの古いスナップショットは無視し、
            // 既に持っている軌跡より短い（＝古い）ものでは上書きしない。
            guard let incomingSessionID = UUID(uuidString: sessionID) else { return }
            if let activeWatchSessionID, activeWatchSessionID != incomingSessionID { return }
            isWatchTrackingActive = true
            activeWatchSessionID = incomingSessionID
            if coordinates.count > watchTrackedPath.count {
                watchTrackedPath = coordinates
            }
        }
    }

    /// Watch単体のGPSで記録し終えた軌跡を、確認ダイアログを挟まずそのまま保存する
    /// （保存確認はWatch側で既に済んでいるため）。`WalkRoute`のIDはWatchのセッションIDと
    /// 揃え、記録中にiPhoneへ転送された御朱印・写真投稿がこの記録に正しく紐付くようにする。
    private func saveWatchTrackedRoute(_ route: WatchTrackedRoute) {
        guard route.coordinates.count >= 2 else { return }
        Task {
            // Watch自身の`CMPedometer`歩数（`route.stepCount`）より、Apple Healthの
            // 歩数の方がWatchのワークアウトセッション分も含めて正確なため、
            // 取得できればそちらを優先する。
            let healthStepCount = await healthKitStepReader.stepCount(from: route.startedAt, to: route.endedAt)
            let walkRoute = WalkRoute(
                id: UUID(uuidString: route.sessionID) ?? UUID(),
                coordinates: route.coordinates,
                startedAt: route.startedAt,
                endedAt: route.endedAt,
                stepCount: healthStepCount ?? route.stepCount,
                overlayMapID: mapSession.selectedOverlay?.id,
                overlayOpacity: mapSession.overlayOpacity
            )
            modelContext.insert(walkRoute)
            try? modelContext.save()

            if let userID = authService.userID {
                try? await syncService.upload(walkRoute, userID: userID)
            }
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

        photoSyncErrorMessage = nil
        let post = WalkPhotoPost(
            photoFileName: filename,
            coordinate: coordinate,
            walkRouteID: currentSessionID
        )
        modelContext.insert(post)
        watchConnectivity.notifyPhotoPosted(points: post.points)

        if let userID = authService.userID {
            Task {
                do {
                    try await syncService.uploadPhotoPostImage(post, userID: userID)
                    try? modelContext.save()
                } catch {
                    // 端末には保存済みだが、Webでも見られるようにするアップロードには失敗した。
                    withAnimation {
                        photoSyncErrorMessage = "写真のクラウド保存に失敗しました: \(error.localizedDescription)"
                    }
                }
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
            if photoSyncErrorMessage != nil {
                try? await Task.sleep(for: .seconds(4))
                withAnimation {
                    photoSyncErrorMessage = nil
                }
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

        for site in cachedActiveCheckpoints where !alreadyCollected.contains(site.id) {
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
                        .font(.system(size: 12)) // .caption2相当
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Button("キャンセル") { isConfirmingDiscard = false }
                            .font(.system(size: 14.4)) // .caption(12pt)の20%増し
                        Button("破棄する", role: .destructive) {
                            onDiscard()
                            dismiss()
                        }
                        .font(.system(size: 14.4, weight: .bold)) // .caption.bold()の20%増し
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Text("破棄")
                        .font(.system(size: 15.6)) // .footnote(13pt)の20%増し
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
