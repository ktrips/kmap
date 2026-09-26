import SwiftData
import SwiftUI

/// AIが生成した旅日記を読むための画面。
///
/// 題名・基本情報（日時・距離・時間・件数）・AIが書いたサマリー・実際に歩いたルートの
/// 地図・巡った御朱印/投稿写真（それぞれ説明文と並べて）の順に並べた、
/// スクラップブックのような構成にしている。
struct TravelJournalView: View {
    let route: WalkRoute
    let stamps: [CollectedStamp]
    let photoPosts: [WalkPhotoPost]
    let checkpoints: [HistoricSite]

    /// 「YYYY/M/D HH:MI」形式の日時表記（時間旅の記録画面と統一）。
    private static let dateFormatter: DateFormatter = TripFormat.dateTimeFormatter

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    @State private var likeCount = 0
    /// 御朱印スポットの説明（`siteID`ごと）。描き直しのたびに御朱印ごとにデータベースを
    /// 読み直さないよう、画面を開いた時に一度だけまとめて読む。
    @State private var checkpointDetails: [String: String] = [:]
    /// タップされたポイント（御朱印・チェックポイント、投稿写真）。写真を大きく説明と一緒に見せ、
    /// 左右のスワイプで前後のポイントへ移れる詳細（`JournalPointPagerSheet`）を開く。
    @State private var selectedPoint: JournalPointSelection?
    /// 端末に保存済みの旅の動画（クラウドのリンクが無い時に、ここから再生できるようにする）。
    @State private var localVideoURL: URL?
    @State private var isShowingVideo = false

    private let syncService = SyncService()

    /// 現在の公開状態（公開・自分だけ・非表示の3段階）。
    private var currentVisibility: TripVisibility {
        if route.isSharedPublicly { return .publicShared }
        return route.isHiddenOnMap ? .hidden : .onlyMe
    }

    private var sortedStamps: [CollectedStamp] {
        stamps.sorted { $0.collectedAt < $1.collectedAt }
    }

    private var sortedPhotoPosts: [WalkPhotoPost] {
        photoPosts.sorted { $0.postedAt < $1.postedAt }
    }

    private var bodyText: AttributedString {
        (try? AttributedString(
            markdown: route.travelJournalMarkdownWithVideoLink ?? "",
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(route.travelJournalMarkdownWithVideoLink ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        nameSection
                        statsSection
                        countsSection
                    }

                    summarySection

                    WalkRouteMapView(
                        overlayMap: route.overlayMap,
                        overlayOpacity: Float(route.overlayOpacity),
                        path: route.coordinates,
                        checkpoints: checkpoints,
                        collectedSiteIDs: Set(stamps.map(\.siteID))
                    )
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .playsTripVideoOnTap(localVideoURL: localVideoURL, cloudVideoURL: route.tripVideoURL) {
                        isShowingVideo = true
                    }

                    if !sortedStamps.isEmpty {
                        goshuinGallery
                    }

                    if !sortedPhotoPosts.isEmpty {
                        photoGallery
                    }
                }
                .padding()
            }
            .navigationTitle("時空旅日記")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task(id: route.isSharedPublicly) {
                guard route.isSharedPublicly else { return }
                guard let counts = try? await syncService.fetchEngagementCounts(tripID: route.id.uuidString) else { return }
                likeCount = counts.likeCount
            }
            .sheet(item: $selectedPoint) { selection in
                JournalPointPagerSheet(points: journalPoints, initialID: selection.id)
            }
            .sheet(isPresented: $isShowingVideo) {
                if let localVideoURL {
                    TripVideoPlayerSheet(videoURL: localVideoURL)
                }
            }
            .onAppear {
                localVideoURL = TripVideoStore.existingURL(for: route.id)
                checkpointDetails = SyncService.checkpointDetailTexts(for: stamps, in: modelContext)
            }
        }
    }

    /// 旅の動画のクラウドの共有リンク（未作成・未アップロードなら`nil`）。
    private var cloudVideoURL: URL? {
        route.tripVideoURL.flatMap(URL.init(string:))
    }

    /// 旅の動画を再生する。端末に動画があればアプリ内のプレーヤーで、無ければクラウドの共有リンクを開く
    /// （地図を押した時と同じ）。
    private func playVideo() {
        if localVideoURL != nil {
            isShowingVideo = true
        } else if let cloudVideoURL {
            openURL(cloudVideoURL)
        }
    }

    /// 1行目：旅の名前と、その右横に公開状況アイコン・ラベル。
    private var nameSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let title = route.title, !title.isEmpty {
                Text(title)
                    .font(.title3.bold())
            } else {
                Text(Self.dateFormatter.string(from: route.startedAt))
                    .font(.title3.bold())
            }

            Spacer(minLength: 8)

            Label(currentVisibility.statusText, systemImage: currentVisibility.systemImage)
                .font(.caption.bold())
                .foregroundStyle(currentVisibility == .publicShared ? .blue : .secondary)
                .lineLimit(1)
                .layoutPriority(1)
        }
    }

    /// 2行目：日付・歩いた距離・歩数・時間。
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

    /// 3行目：御朱印の数・写真の数・いいねの数。
    private var countsSection: some View {
        HStack(spacing: 12) {
            Label("御朱印 \(sortedStamps.count)件", systemImage: "seal.fill")
                .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
            Label("写真 \(sortedPhotoPosts.count)件", systemImage: "camera.fill")
                .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
            if route.isSharedPublicly {
                Label("いいね \(likeCount)件", systemImage: "heart.fill")
                    .foregroundStyle(.pink)
            }
            if localVideoURL != nil || cloudVideoURL != nil {
                Button(action: playVideo) {
                    Label("動画", systemImage: "play.rectangle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("旅の動画を再生")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(route.overlayMap.map { "\($0.title)の時空旅" } ?? "時空旅")
                .font(.headline)
            Text(bodyText)
                .font(.body)
        }
    }

    private var distanceText: String {
        TripFormat.distance(route.totalDistanceMeters)
    }

    private var durationText: String? {
        TripFormat.duration(route.durationSeconds)
    }

    /// 旅日記に並べている順（御朱印・チェックポイント → 投稿した写真）のポイント一覧。
    /// 詳細シートでは、この順に左右のスワイプで前後へ移る。
    private var journalPoints: [JournalPoint] {
        let stampPoints: [JournalPoint] = sortedStamps.compactMap { stamp in
            guard let site = stamp.site else { return nil }
            return JournalPoint(
                id: "stamp-\(stamp.id.uuidString)",
                section: "御朱印・チェックポイント",
                image: { stamp.photo },
                placeholderSystemImage: "seal.fill",
                placeholderColor: Self.stampColor,
                title: site.name,
                subtitle: nil,
                detail: checkpointDetails[site.id] ?? site.summary
            )
        }
        let photoPoints: [JournalPoint] = sortedPhotoPosts.map { post in
            JournalPoint(
                id: "post-\(post.id.uuidString)",
                section: "投稿した写真",
                image: { post.photo },
                placeholderSystemImage: "camera.fill",
                placeholderColor: Self.photoColor,
                title: post.displayTitle ?? post.postedAt.formatted(date: .omitted, time: .shortened),
                subtitle: photoSubtitle(for: post),
                detail: post.storyBody
            )
        }
        return stampPoints + photoPoints
    }

    private static let stampColor = Color(red: 0.72, green: 0.53, blue: 0.15)
    private static let photoColor = Color(red: 0.86, green: 0.63, blue: 0.24)

    private var goshuinGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("御朱印・チェックポイント")
                .font(.headline)

            ForEach(sortedStamps) { stamp in
                if let site = stamp.site {
                    JournalGalleryRow(
                        image: stamp.thumbnail,
                        placeholderSystemImage: "seal.fill",
                        placeholderColor: Self.stampColor,
                        title: site.name,
                        detail: checkpointDetails[site.id] ?? site.summary,
                        onTap: { selectedPoint = JournalPointSelection(id: "stamp-\(stamp.id.uuidString)") }
                    )
                }
            }
        }
    }

    private var photoGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投稿した写真")
                .font(.headline)

            ForEach(sortedPhotoPosts) { post in
                JournalGalleryRow(
                    image: post.thumbnail,
                    placeholderSystemImage: "camera.fill",
                    placeholderColor: Self.photoColor,
                    title: post.displayTitle ?? post.postedAt.formatted(date: .omitted, time: .shortened),
                    subtitle: photoSubtitle(for: post),
                    detail: post.storyBody,
                    onTap: { selectedPoint = JournalPointSelection(id: "post-\(post.id.uuidString)") }
                )
            }
        }
    }

    /// 付けた名前を表示に使った場合、GPSから取得した場所名があれば小さく添える
    /// （名前が無ければ場所名の方がそのまま見出しに使われるため、ここでは出さない）。
    private func photoSubtitle(for post: WalkPhotoPost) -> String? {
        let trimmedUserTitle = post.userTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedUserTitle, !trimmedUserTitle.isEmpty else { return nil }
        guard let placeName = post.placeName, !placeName.isEmpty, placeName != trimmedUserTitle else { return nil }
        return placeName
    }

}

/// 旅日記のギャラリー（御朱印・投稿写真）1件分の行。写真とその説明を横並びで見せる。
private struct JournalGalleryRow: View {
    let image: UIImage?
    let placeholderSystemImage: String
    let placeholderColor: Color
    let title: String
    /// 見出し（`title`）の下に、さらに小さく添える補足（例: 名前を付けた写真の、GPSから
    /// 取得した場所名）。無ければ何も出さない。
    var subtitle: String? = nil
    let detail: String?
    /// 行（写真・説明）をタップした時に呼ばれる。
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: placeholderSystemImage)
                        .font(.system(size: 32))
                        .foregroundStyle(placeholderColor)
                        .background(.regularMaterial)
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

/// 旅日記のポイント（御朱印・チェックポイント、投稿写真）1件分。詳細シートの1ページになる。
struct JournalPoint: Identifiable {
    let id: String
    /// 「御朱印・チェックポイント」「投稿した写真」のどちらか。
    let section: String
    /// 写真は大きいため、ページを表示する時に初めて読み込む。
    let image: () -> UIImage?
    let placeholderSystemImage: String
    let placeholderColor: Color
    let title: String
    let subtitle: String?
    let detail: String?
}

/// `.sheet(item:)`に渡す、最初に開くポイントのID。
struct JournalPointSelection: Identifiable {
    let id: String
}

/// 旅日記のポイントを、写真を大きく・説明を全文で見せるシート。左右のスワイプで前後のポイントへ移る。
struct JournalPointPagerSheet: View {
    let points: [JournalPoint]
    @State private var currentID: String
    @Environment(\.dismiss) private var dismiss

    init(points: [JournalPoint], initialID: String) {
        self.points = points
        _currentID = State(initialValue: initialID)
    }

    private var currentIndex: Int {
        points.firstIndex { $0.id == currentID } ?? 0
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentID) {
                ForEach(points) { point in
                    JournalPointPage(point: point)
                        .tag(point.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle(points.isEmpty ? "" : "\(currentIndex + 1) / \(points.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct JournalPointPage: View {
    let point: JournalPoint
    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: point.placeholderSystemImage)
                            .font(.system(size: 64))
                            .foregroundStyle(point.placeholderColor)
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .background(.regularMaterial)
                            .opacity(didLoad ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(point.section)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(point.title)
                    .font(.title3.bold())
                if let subtitle = point.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let detail = point.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .task {
            guard !didLoad else { return }
            image = point.image()
            didLoad = true
        }
    }
}

#Preview {
    TravelJournalView(
        route: WalkRoute(
            coordinates: [],
            overlayMapID: OldMapCatalog.edoCastle.id,
            title: "皇居さんぽ",
            travelJournalTitle: "江戸城をめぐる小さな旅",
            travelJournalMarkdown: "## 出発\nある晴れた日、江戸城の面影を求めて歩き出した。",
            travelJournalGeneratedAt: Date()
        ),
        stamps: [],
        photoPosts: [],
        checkpoints: []
    )
    .modelContainer(for: [WalkRoute.self, CheckpointStory.self], inMemory: true)
}
