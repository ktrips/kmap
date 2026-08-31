import SwiftData
import SwiftUI

/// 自分が歩いた地図・アップした写真・御朱印・保存した物語を、
/// それぞれカードでまとめて表示する「My TimeTrip」タブ。
struct MyTimeTripView: View {
    @EnvironmentObject private var mapSession: MapSessionState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.createdAt, order: .reverse) private var places: [SavedPlace]
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var walkRoutes: [WalkRoute]
    @Query(sort: \CollectedStamp.collectedAt, order: .reverse) private var collectedStamps: [CollectedStamp]
    @Query(sort: \WalkPhotoPost.postedAt, order: .reverse) private var photoPosts: [WalkPhotoPost]

    @State private var shareImage: UIImage?
    @State private var isPreparingShare = false
    @State private var selectedStamp: StampSelection?

    private let cardColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    private var collectedSiteIDs: Set<String> {
        Set(collectedStamps.map(\.siteID))
    }

    /// 「アップした写真」カード用に、写真が添えられている御朱印だけを抽出したもの。
    private var stampsWithPhoto: [CollectedStamp] {
        collectedStamps.filter { $0.photoFileName != nil }
    }

    private var totalPoints: Int {
        photoPosts.reduce(0) { $0 + $1.points }
    }

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty && walkRoutes.isEmpty && collectedStamps.isEmpty && photoPosts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            if !walkRoutes.isEmpty {
                                walkRoutesSection
                            }
                            pointsSection
                            if !stampsWithPhoto.isEmpty {
                                photosSection
                            }
                            stampsSection
                            if !places.isEmpty {
                                storiesSection
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My TimeTrip")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareAndShowShareSheet()
                    } label: {
                        if isPreparingShare {
                            ProgressView()
                        } else {
                            Label("共有", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(collectedStamps.isEmpty || isPreparingShare)
                }
            }
            .navigationDestination(for: SavedPlace.self) { place in
                SavedPlaceDetailView(place: place)
            }
            .navigationDestination(for: WalkRoute.self) { route in
                WalkRouteDetailView(route: route)
            }
            .sheet(item: $selectedStamp) { selection in
                StampCheckInSheet(site: selection.site, stamp: selection.stamp)
            }
            .sheet(item: shareImageBinding) { holder in
                ActivityView(items: [holder.image])
            }
        }
    }

    // MARK: - 自分がスタート〜終了した地図

    private var walkRoutesSection: some View {
        TimeTripSection(title: "歩いた地図", systemImage: "map.fill") {
            LazyVGrid(columns: cardColumns, spacing: 12) {
                ForEach(walkRoutes) { route in
                    NavigationLink(value: route) {
                        WalkRouteCard(route: route, stampCount: stampCount(for: route))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("この古地図で再スタート") { resume(route) }
                        Button("削除", role: .destructive) { delete(route) }
                    }
                }
            }
        }
    }

    // MARK: - アップした写真

    private var photosSection: some View {
        TimeTripSection(title: "アップした写真", systemImage: "photo.on.rectangle.angled") {
            LazyVGrid(columns: cardColumns, spacing: 12) {
                ForEach(stampsWithPhoto) { stamp in
                    if let site = stamp.site {
                        PhotoCard(site: site, stamp: stamp)
                            .onTapGesture {
                                selectedStamp = StampSelection(site: site, stamp: stamp)
                            }
                    }
                }
            }
        }
    }

    // MARK: - ポイント

    private var pointsSection: some View {
        TimeTripSection(title: "ポイント", systemImage: "star.fill") {
            NavigationLink {
                PointHistoryView()
            } label: {
                PointsSummaryCard(totalPoints: totalPoints, postCount: photoPosts.count)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 御朱印

    private var stampsSection: some View {
        TimeTripSection(title: "御朱印", systemImage: "seal.fill") {
            NavigationLink {
                StampListView()
            } label: {
                StampSummaryCard(
                    collectedCount: collectedStamps.count,
                    totalCount: HistoricSiteCatalog.all.count
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 保存した物語

    private var storiesSection: some View {
        TimeTripSection(title: "保存した物語", systemImage: "book.closed.fill") {
            LazyVGrid(columns: cardColumns, spacing: 12) {
                ForEach(places) { place in
                    NavigationLink(value: place) {
                        StoryCard(place: place)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("削除", role: .destructive) { delete(place) }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("まだ記録がありません")
                .font(.headline)
            Text("マップで気になる場所をタップして昔の物語を保存したり、\n「スタート」でウォーキングを記録してみましょう。")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stampCount(for route: WalkRoute) -> Int {
        collectedStamps.filter { $0.walkRouteID == route.id }.count
    }

    /// その時に使っていた古地図・不透明度・位置を復元してマップタブへ切り替える。
    private func resume(_ route: WalkRoute) {
        mapSession.resume(
            overlayMapID: route.overlayMapID,
            overlayOpacity: route.overlayOpacity,
            cameraTarget: route.coordinates.first
        )
    }

    private func delete(_ route: WalkRoute) {
        modelContext.delete(route)
    }

    private func delete(_ place: SavedPlace) {
        modelContext.delete(place)
    }

    /// `.sheet(item:)` に渡すための、UIImageをIdentifiableでラップした値。
    private var shareImageBinding: Binding<IdentifiableImage?> {
        Binding(
            get: { shareImage.map(IdentifiableImage.init) },
            set: { shareImage = $0?.image }
        )
    }

    private func prepareAndShowShareSheet() {
        isPreparingShare = true
        let renderer = ImageRenderer(
            content: StampShareCardView(
                collectedCount: collectedStamps.count,
                totalCount: HistoricSiteCatalog.all.count,
                collectedSiteNames: HistoricSiteCatalog.all
                    .filter { collectedSiteIDs.contains($0.id) }
                    .map(\.name)
            )
        )
        renderer.scale = UIScreen.main.scale
        shareImage = renderer.uiImage
        isPreparingShare = false
    }
}

/// カードのグリッドをタイトル・アイコン付きの見出しでまとめる共通コンテナ。
private struct TimeTripSection<Content: View>: View {
    let title: String
    let systemImage: String
    var footer: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.brown)
            content
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 「歩いた地図」カード。使っていた古地図のサムネイル・日時・距離・獲得御朱印数を表示する。
private struct WalkRouteCard: View {
    let route: WalkRoute
    let stampCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                thumbnail
                LinearGradient(
                    colors: [.black.opacity(0.55), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                Text(route.overlayMap?.title ?? "古地図なし")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(8)
            }
            .frame(height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(route.title?.isEmpty == false ? route.title! : route.startedAt.formatted(.dateTime.year().month().day().hour().minute()))
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 10) {
                Label(distanceText, systemImage: "figure.walk")
                if let durationText {
                    Label(durationText, systemImage: "clock")
                }
                if stampCount > 0 {
                    Label("\(stampCount)", systemImage: "seal.fill")
                        .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let stepCount = route.stepCount {
                Label("\(stepCount)歩", systemImage: "shoeprints.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let uiImage = route.overlayMap?.image {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.brown.opacity(0.25))
                .overlay(Image(systemName: "map").foregroundStyle(.brown))
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
}

/// 「アップした写真」カード。御朱印獲得時に添えた写真を、場所名・日付とともに見せる。
private struct PhotoCard: View {
    let site: HistoricSite
    let stamp: CollectedStamp

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let photo = stamp.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 110)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(site.name)
                .font(.caption.bold())
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(stamp.collectedAt, format: .dateTime.month().day())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 「保存した物語」カード。
private struct StoryCard: View {
    let place: SavedPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 20))
                .foregroundStyle(.brown)

            Text(place.title)
                .font(.subheadline.bold())
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(place.era)
                .font(.caption2)
                .foregroundStyle(.brown)

            Text(place.storyText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct IdentifiableImage: Identifiable {
    let image: UIImage
    var id: ObjectIdentifier { ObjectIdentifier(image) }
}

/// タップされたセルを御朱印チェックインシートへ渡すための値。
struct StampSelection: Identifiable {
    let site: HistoricSite
    let stamp: CollectedStamp
    var id: String { site.id }
}

/// 「御朱印」カードのサマリー表示。集めた数と、タップで一覧へ進めることを示す。
private struct StampSummaryCard: View {
    let collectedCount: Int
    let totalCount: Int

    private var progress: Double {
        totalCount == 0 ? 0 : Double(collectedCount) / Double(totalCount)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(red: 0.72, green: 0.53, blue: 0.15),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Image(systemName: "seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(collectedCount) / \(totalCount) 集めました")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(collectedCount == 0 ? "まだ御朱印がありません" : "タップして一覧を見る")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 「ポイント」カードのサマリー表示。合計ポイントと投稿件数を示す。
private struct PointsSummaryCard: View {
    let totalPoints: Int
    let postCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.86, green: 0.63, blue: 0.24).opacity(0.15))
                Image(systemName: "star.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(totalPoints) pt")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(postCount == 0 ? "ウォーキング中に写真を投稿して貯めよう" : "\(postCount)件の投稿。タップして見る")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct StampCell: View {
    let site: HistoricSite
    let stamp: CollectedStamp?

    private var isCollected: Bool { stamp != nil }

    var body: some View {
        VStack(spacing: 8) {
            if let photo = stamp?.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: isCollected ? "seal.fill" : "seal")
                    .font(.system(size: 36))
                    .foregroundStyle(isCollected ? Color(red: 0.72, green: 0.53, blue: 0.15) : .secondary.opacity(0.4))
            }

            Text(site.name)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(isCollected ? .primary : .secondary)

            if let collectedAt = stamp?.collectedAt {
                Text(collectedAt, format: .dateTime.year().month().day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("未獲得")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 御朱印帳の共有用サマリーカード（`ImageRenderer` で画像化する）。
private struct StampShareCardView: View {
    let collectedCount: Int
    let totalCount: Int
    let collectedSiteNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "seal.fill")
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                Text("わたしの御朱印帳")
                    .font(.title2.bold())
            }
            Text("Komap 古地図巡り")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(collectedCount) / \(totalCount) 集めました")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(collectedSiteNames, id: \.self) { name in
                    Label(name, systemImage: "seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                }
            }
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
        .background(Color(red: 0.973, green: 0.945, blue: 0.894))
    }
}

/// `UIActivityViewController` をSwiftUIから使うための薄いラッパー。
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    MyTimeTripView()
        .environmentObject(MapSessionState())
        .modelContainer(for: [SavedPlace.self, WalkRoute.self, CollectedStamp.self, WalkPhotoPost.self], inMemory: true)
}
