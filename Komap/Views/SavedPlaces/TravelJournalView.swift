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
            markdown: route.travelJournalMarkdown ?? "",
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(route.travelJournalMarkdown ?? "")
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
                    title: post.placeName ?? post.postedAt.formatted(date: .omitted, time: .shortened),
                    detail: post.storyBody
                )
            }
        }
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
    let detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: placeholderSystemImage)
                    .font(.system(size: 32))
                    .foregroundStyle(placeholderColor)
                    .frame(width: 84, height: 84)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
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
