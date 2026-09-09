import SwiftData
import SwiftUI

/// AIが生成した旅行記を読むための画面。
///
/// 題名・基本情報（日時・距離・時間・件数）・AIが書いたサマリー・実際に歩いたルートの
/// 地図・巡った御朱印/投稿写真（それぞれ説明文と並べて）の順に並べた、
/// スクラップブックのような構成にしている。
struct TravelJournalView: View {
    let route: WalkRoute
    let stamps: [CollectedStamp]
    let photoPosts: [WalkPhotoPost]
    let checkpoints: [HistoricSite]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                    titleSection

                    basicInfoSection

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
            .navigationTitle("旅行記")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let overlayMap = route.overlayMap {
                Text(overlayMap.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.brown)
            }

            Text(route.travelJournalTitle ?? route.title ?? "旅行記")
                .font(.title2.bold())

            if let generatedAt = route.travelJournalGeneratedAt {
                Text(generatedAt, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 旅の基本情報（日時・距離・時間・歩数・御朱印/写真の件数）。
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(route.startedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(distanceText, systemImage: "figure.walk")
                if let durationText {
                    Label(durationText, systemImage: "clock")
                }
                if let stepCount = route.stepCount {
                    Label("\(stepCount)歩", systemImage: "shoeprints.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label("御朱印 \(sortedStamps.count)件", systemImage: "seal.fill")
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                if !sortedPhotoPosts.isEmpty {
                    Label("写真 \(sortedPhotoPosts.count)件", systemImage: "camera.fill")
                        .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("旅のサマリー")
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
            Text("巡った御朱印")
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

/// 旅行記のギャラリー（御朱印・投稿写真）1件分の行。写真とその説明を横並びで見せる。
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
