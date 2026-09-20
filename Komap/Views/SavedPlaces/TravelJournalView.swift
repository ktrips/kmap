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
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter
    }()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var likeCount = 0
    /// タップされた投稿写真。大きく・前後にスワイプできる詳細（`PhotoPostPreviewSheet`）を開く。
    @State private var selectedPhotoPost: WalkPhotoPost?
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

                    videoLinkSection

                    WalkRouteMapView(
                        overlayMap: route.overlayMap,
                        overlayOpacity: Float(route.overlayOpacity),
                        path: route.coordinates,
                        checkpoints: checkpoints,
                        collectedSiteIDs: Set(stamps.map(\.siteID))
                    )
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

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
            .sheet(item: $selectedPhotoPost) { post in
                PhotoPostPreviewSheet(post: post)
            }
            .sheet(isPresented: $isShowingVideo) {
                if let localVideoURL {
                    TripVideoPlayerSheet(videoURL: localVideoURL)
                }
            }
            .onAppear { localVideoURL = TripVideoStore.existingURL(for: route.id) }
        }
    }

    /// 旅の動画へのリンク。クラウドの共有リンクがあればそれを開き（本文末尾にも同じリンクを載せている）、
    /// リンクが無くても端末に動画があればここから再生できる。
    @ViewBuilder
    private var videoLinkSection: some View {
        if let urlString = route.tripVideoURL, let url = URL(string: urlString) {
            Link(destination: url) {
                Label("旅の動画を見る", systemImage: "play.rectangle.fill")
            }
            .font(.subheadline.bold())
        } else if localVideoURL != nil {
            Button {
                isShowingVideo = true
            } label: {
                Label("旅の動画を見る", systemImage: "play.rectangle.fill")
            }
            .font(.subheadline.bold())
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

    private var goshuinGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("御朱印・チェックポイント")
                .font(.headline)

            ForEach(sortedStamps) { stamp in
                if let site = stamp.site {
                    JournalGalleryRow(
                        image: stamp.photo,
                        placeholderSystemImage: "seal.fill",
                        placeholderColor: Color(red: 0.72, green: 0.53, blue: 0.15),
                        title: site.name,
                        detail: checkpointDetail(siteID: site.id) ?? site.summary
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
                    image: post.photo,
                    placeholderSystemImage: "camera.fill",
                    placeholderColor: Color(red: 0.86, green: 0.63, blue: 0.24),
                    title: post.displayTitle ?? post.postedAt.formatted(date: .omitted, time: .shortened),
                    subtitle: photoSubtitle(for: post),
                    detail: post.storyBody,
                    onTapImage: post.photo != nil ? { selectedPhotoPost = post } : nil
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

    /// 既にAIで生成済みの、その御朱印スポットの詳細（`CheckpointStory`）があればその本文を返す。
    private func checkpointDetail(siteID: String) -> String? {
        let descriptor = FetchDescriptor<CheckpointStory>(
            predicate: #Predicate { $0.siteID == siteID }
        )
        return try? modelContext.fetch(descriptor).first?.body
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
    /// 写真をタップした時に呼ばれる。`nil`ならタップしても何も起きない
    /// （写真が無い＝プレースホルダー表示の時など）。
    var onTapImage: (() -> Void)? = nil

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
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                onTapImage?()
            }

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
