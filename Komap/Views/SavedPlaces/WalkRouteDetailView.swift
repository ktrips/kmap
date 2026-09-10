import CoreLocation
import GoogleMaps
import SwiftData
import SwiftUI

/// 時間旅の公開範囲。「公開」は誰でも見られる「みんなの時空旅」に出る状態、
/// 「自分だけ」は自分の「My Trips」とマップ上の軌跡表示の両方に出る状態、
/// 「非表示」は「My Trips」一覧には出るがマップ上の軌跡表示からは外れる状態。
enum TripVisibility: String, CaseIterable, Identifiable {
    case publicShared
    case onlyMe
    case hidden

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .publicShared: return "公開（みんなの時空旅に表示）"
        case .onlyMe: return "自分だけ（マップ上にも表示）"
        case .hidden: return "非表示（マップ上には表示しない）"
        }
    }

    var statusText: String {
        switch self {
        case .publicShared: return "公開中"
        case .onlyMe: return "自分だけ"
        case .hidden: return "マップ非表示"
        }
    }

    var systemImage: String {
        switch self {
        case .publicShared: return "person.2.fill"
        case .onlyMe: return "lock.fill"
        case .hidden: return "eye.slash.fill"
        }
    }
}

/// 保存した1回分の時間旅行（ウォーキング記録）の詳細。
/// 使っていた古地図・歩いたルート（塗りつぶした地図）・通ったチェックポイントと御朱印・
/// アップした写真をまとめて表示する。
struct WalkRouteDetailView: View {
    let route: WalkRoute

    /// 「YYYY/M/D HH:MI」形式の日時表記。
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter
    }()

    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var collectedStamps: [CollectedStamp]
    @Query private var photoPosts: [WalkPhotoPost]

    @State private var isRenaming = false
    @State private var editedTitle = ""
    @State private var isEditingNotes = false
    @State private var editedNotes = ""
    @State private var isConfirmingDelete = false
    @State private var selectedPhotoPost: WalkPhotoPost?
    @State private var selectedStamp: StampSelection?
    @State private var isUpdatingShare = false
    @State private var shareErrorMessage: String?
    @State private var isGeneratingJournal = false
    @State private var journalErrorMessage: String?
    @State private var isShowingJournal = false
    @State private var likeCount = 0

    private let syncService = SyncService()
    private let journalService = TravelJournalService()

    private var stampsForRoute: [CollectedStamp] {
        collectedStamps
            .filter { $0.walkRouteID == route.id }
            .sorted { $0.collectedAt < $1.collectedAt }
    }

    private var photoPostsForRoute: [WalkPhotoPost] {
        photoPosts
            .filter { $0.walkRouteID == route.id }
            .sorted { $0.postedAt < $1.postedAt }
    }

    private var checkpointsForOverlay: [HistoricSite] {
        HistoricSiteCatalog.sites(forOverlayID: route.overlayMap?.id)
    }

    /// 巡った御朱印スポットについて、旅日記画面（`TravelJournalView`）が表示するのと
    /// 同じ説明文（既にAIで生成済みの`CheckpointStory`があればその本文、無ければ
    /// 史跡カタログの`summary`）を`siteID`をキーにまとめたもの。公開データ
    /// （`sharedTrips`）に、御朱印の写真と一緒に説明文も添えられるようにするために使う。
    /// 新規のAI生成は行わない（生成済みのものだけをそのまま使う、読み取り専用の軽い処理）。
    private func checkpointDetailTexts() -> [String: String] {
        guard !stampsForRoute.isEmpty else { return [:] }
        let siteIDs = Set(stampsForRoute.map(\.siteID))
        let descriptor = FetchDescriptor<CheckpointStory>(
            predicate: #Predicate { siteIDs.contains($0.siteID) }
        )
        let stories = (try? modelContext.fetch(descriptor)) ?? []
        var details = Dictionary(uniqueKeysWithValues: stories.map { ($0.siteID, $0.body) })
        for siteID in siteIDs where details[siteID] == nil {
            details[siteID] = HistoricSiteCatalog.site(withID: siteID)?.summary
        }
        return details
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

                nameSection

                statsSection

                countsSection

                descriptionAndJournalSection

                if !stampsForRoute.isEmpty {
                    checkpointsSection
                }

                if !photoPostsForRoute.isEmpty {
                    photoPostsSection
                }

                if route.isSharedPublicly {
                    TripEngagementView(
                        tripID: route.id.uuidString,
                        currentUserID: authService.userID,
                        currentUserDisplayName: authService.displayName
                    )
                }
            }
            .padding()
        }
        .navigationTitle("時間旅の記録")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: route.isSharedPublicly) {
            guard route.isSharedPublicly else { return }
            guard let counts = try? await syncService.fetchEngagementCounts(tripID: route.id.uuidString) else { return }
            likeCount = counts.likeCount
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editedTitle = route.title ?? ""
                        isRenaming = true
                    } label: {
                        Label("名前を変更", systemImage: "pencil")
                    }
                    Button {
                        editedNotes = route.notes ?? ""
                        isEditingNotes = true
                    } label: {
                        Label(route.notes?.isEmpty == false ? "感想を編集" : "感想を書く", systemImage: "text.quote")
                    }
                    Menu {
                        ForEach(TripVisibility.allCases) { visibility in
                            Button {
                                Task { await setVisibility(visibility) }
                            } label: {
                                if visibility == currentVisibility {
                                    Label(visibility.menuTitle, systemImage: "checkmark")
                                } else {
                                    Text(visibility.menuTitle)
                                }
                            }
                        }
                    } label: {
                        Label("公開設定: \(currentVisibility.menuTitle)", systemImage: currentVisibility.systemImage)
                    }
                    .disabled(isUpdatingShare)
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("時間旅の名前", isPresented: $isRenaming) {
            TextField("例: 皇居さんぽ", text: $editedTitle)
            Button("保存する") {
                let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                route.title = trimmed.isEmpty ? nil : trimmed
                try? modelContext.save()
                Task { await resyncSharedTripIfNeeded() }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "この時間旅を削除しますか？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                deleteRoute()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("歩いたルートの記録が削除されます。この操作は取り消せません。")
        }
        .sheet(item: $selectedPhotoPost) { post in
            PhotoPostPreviewSheet(post: post)
        }
        .sheet(item: $selectedStamp) { selection in
            StampCheckInSheet(site: selection.site, stamp: selection.stamp)
        }
        .sheet(isPresented: $isShowingJournal) {
            TravelJournalView(
                route: route,
                stamps: stampsForRoute,
                photoPosts: photoPostsForRoute,
                checkpoints: checkpointsForOverlay
            )
        }
        .sheet(isPresented: $isEditingNotes) {
            NavigationStack {
                TextEditor(text: $editedNotes)
                    .padding(12)
                    .navigationTitle("感想")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { isEditingNotes = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存する") {
                                let trimmed = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                                route.notes = trimmed.isEmpty ? nil : trimmed
                                try? modelContext.save()
                                isEditingNotes = false
                                Task { await resyncSharedTripIfNeeded() }
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// 1行目：旅の名前（使っていた古地図）と、その右横に公開状況アイコン・ラベル。
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let title = route.title, !title.isEmpty {
                    Text(title)
                        .font(.title3.bold())
                } else {
                    Text(Self.dateFormatter.string(from: route.startedAt))
                        .font(.title3.bold())
                }
                Text("（\(route.overlayMap?.title ?? "古地図なし")）")
                    .font(.subheadline.bold())
                    .foregroundStyle(.brown)

                Spacer(minLength: 8)

                Label(currentVisibility.statusText, systemImage: currentVisibility.systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(currentVisibility == .publicShared ? .blue : .secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            if let shareErrorMessage {
                Text(shareErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// 3行目：日付・歩いた距離・歩数・時間。
    private var statsSection: some View {
        HStack(spacing: 12) {
            Label(Self.dateFormatter.string(from: route.startedAt), systemImage: "calendar")
            Label(distanceText, systemImage: "figure.walk")
            if let stepCount = route.stepCount {
                Label("\(stepCount)歩", systemImage: "shoeprints.fill")
            }
            if let durationText {
                Label(durationText, systemImage: "clock")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// 4行目：御朱印の数・写真の数・いいねの数。
    private var countsSection: some View {
        HStack(spacing: 12) {
            Label("御朱印 \(stampsForRoute.count)件", systemImage: "seal.fill")
                .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
            Label("写真 \(photoPostsForRoute.count)件", systemImage: "camera.fill")
                .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
            if route.isSharedPublicly {
                Label("いいね \(likeCount)件", systemImage: "heart.fill")
                    .foregroundStyle(.pink)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// 5行目：旅の説明（感想）と、旅日記を作る/読むボタン。
    private var descriptionAndJournalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let notes = route.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            travelJournalSection
        }
    }

    private var photoPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投稿した写真")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(photoPostsForRoute) { post in
                    if let photo = post.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture {
                                selectedPhotoPost = post
                            }
                    }
                }
            }
        }
    }

    private var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("御朱印・チェックポイント")
                .font(.headline)

            ForEach(stampsForRoute) { stamp in
                if let site = stamp.site {
                    CheckpointRow(site: site, stamp: stamp)
                        .onTapGesture {
                            selectedStamp = StampSelection(site: site, stamp: stamp)
                        }
                }
            }
        }
    }

    private var travelJournalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let journalErrorMessage {
                Text(journalErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if route.travelJournalMarkdown != nil {
                HStack(spacing: 8) {
                    Button {
                        isShowingJournal = true
                    } label: {
                        Label("旅日記を読む", systemImage: "book.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await generateJournal() }
                    } label: {
                        if isGeneratingJournal {
                            ProgressView()
                                .frame(width: 20)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGeneratingJournal)
                    .accessibilityLabel("旅日記を作り直す")
                }
            } else {
                Button {
                    Task { await generateJournal() }
                } label: {
                    if isGeneratingJournal {
                        HStack {
                            ProgressView()
                            Text("旅日記を作成中…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("旅日記を作成する", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingJournal)
            }
        }
    }

    /// AIに、この時間旅の内容から旅日記を生成してもらい、成功したら保存・同期する。
    private func generateJournal() async {
        isGeneratingJournal = true
        journalErrorMessage = nil
        do {
            let journal = try await journalService.generateJournal(
                for: route,
                stamps: stampsForRoute,
                photoPosts: photoPostsForRoute,
                modelContext: modelContext
            )
            route.travelJournalTitle = journal.title
            route.travelJournalMarkdown = journal.markdownBody
            route.travelJournalGeneratedAt = Date()
            try? modelContext.save()
            await resyncSharedTripIfNeeded()
            let userID = authService.userID
            try? await syncService.upload(route, userID: userID)
        } catch {
            journalErrorMessage = error.localizedDescription
        }
        isGeneratingJournal = false
    }

    /// この時間旅を削除する。公開中だった場合は「みんなの時空旅」からも取り除き、
    /// クラウド側（`users/{uid}/walkRoutes/{id}`）のコピーも削除する。
    private func deleteRoute() {
        let routeID = route.id
        let wasPublic = route.isSharedPublicly
        let userID = authService.userID
        modelContext.delete(route)
        try? modelContext.save()
        dismiss()
        Task {
            if wasPublic {
                try? await syncService.unpublishSharedTrip(tripID: routeID)
            }
            try? await syncService.delete(walkRouteID: routeID, userID: userID)
        }
    }

    /// 既に「みんなの時空旅」に公開済みなら、名前・感想の変更を公開データにも反映する。
    private func resyncSharedTripIfNeeded() async {
        let details = checkpointDetailTexts()
        await syncService.resyncSharedTripIfNeeded(
            route,
            userID: authService.userID,
            ownerDisplayName: authService.displayName,
            stamps: stampsForRoute,
            photoPosts: photoPostsForRoute,
            checkpointDetails: details
        )
        await syncCheckpointDetailsToPrivateCloud(details: details)
    }

    /// 巡った御朱印の説明文を、公開・非公開に関わらず自分用のプライベート同期
    /// （`users/{uid}/stamps`）にも書き込む。サインインしてWebの「My Trips」を
    /// 見た時にも、御朱印の説明が（公開していない時空旅でも）表示されるようにするため。
    private func syncCheckpointDetailsToPrivateCloud(details: [String: String]) async {
        guard !details.isEmpty else { return }
        let userID = authService.userID
        for stamp in stampsForRoute {
            guard let detail = details[stamp.siteID] else { continue }
            try? await syncService.upload(stamp, userID: userID, detail: detail)
        }
    }

    /// 現在の公開状態（公開・自分だけ・非表示の3段階）。
    private var currentVisibility: TripVisibility {
        if route.isSharedPublicly { return .publicShared }
        return route.isHiddenOnMap ? .hidden : .onlyMe
    }

    /// 公開状態を切り替える。「公開」⇔他の状態の間ではFirestoreへの
    /// 公開・非公開の同期が必要なため、それ以外（自分だけ⇔非表示）より時間がかかる。
    private func setVisibility(_ visibility: TripVisibility) async {
        guard visibility != currentVisibility else { return }
        isUpdatingShare = true
        shareErrorMessage = nil

        let shouldBePublic = visibility == .publicShared
        if shouldBePublic != route.isSharedPublicly {
            let details = checkpointDetailTexts()
            do {
                try await syncService.setPubliclyShared(
                    route,
                    isShared: shouldBePublic,
                    userID: authService.userID,
                    ownerDisplayName: authService.displayName,
                    stamps: stampsForRoute,
                    photoPosts: photoPostsForRoute,
                    checkpointDetails: details
                )
                route.isSharedPublicly = shouldBePublic
                await syncCheckpointDetailsToPrivateCloud(details: details)
            } catch {
                shareErrorMessage = "共有の変更に失敗しました: \(error.localizedDescription)"
                isUpdatingShare = false
                return
            }
        }

        route.isHiddenOnMap = (visibility == .hidden)
        try? modelContext.save()
        isUpdatingShare = false
    }

    private var distanceText: String {
        let meters = route.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private var durationText: String? {
        guard let durationSeconds = route.durationSeconds else { return nil }
        let totalMinutes = Int(durationSeconds / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)時間\(totalMinutes % 60)分"
        }
        return "\(max(totalMinutes, 1))分"
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
struct WalkRouteMapView: UIViewRepresentable {
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
            let overlay = GMSGroundOverlay(bounds: bounds, icon: overlayMap.image)
            overlay.opacity = overlayOpacity
            overlay.map = mapView
        }

        if path.count >= 2 {
            let gmsPath = GMSMutablePath()
            path.forEach { gmsPath.add($0) }

            let border = GMSPolyline(path: gmsPath)
            border.strokeColor = .walkedTrailBorder
            border.strokeWidth = 9
            border.zIndex = 0
            border.map = mapView

            let fill = GMSPolyline(path: gmsPath)
            fill.strokeColor = .walkedTrailFill
            fill.strokeWidth = 6
            fill.zIndex = 1
            fill.map = mapView
        }

        for site in checkpoints {
            let marker = GMSMarker(position: site.coordinate)
            marker.title = site.name
            marker.icon = GMSMarker.markerImage(with: .shuiro)
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
    .modelContainer(for: [WalkRoute.self, CollectedStamp.self, WalkPhotoPost.self], inMemory: true)
}
