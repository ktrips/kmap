import SwiftData
import SwiftUI

/// 保存した物語・ウォーキング履歴・御朱印をまとめた「My TimeTrip」タブ。
struct MyTimeTripView: View {
    @EnvironmentObject private var mapSession: MapSessionState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.createdAt, order: .reverse) private var places: [SavedPlace]
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var walkRoutes: [WalkRoute]
    @Query(sort: \CollectedStamp.collectedAt, order: .reverse) private var collectedStamps: [CollectedStamp]

    @State private var shareImage: UIImage?
    @State private var isPreparingShare = false
    @State private var selectedStamp: StampSelection?

    private let stampColumns = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    private var collectedSiteIDs: Set<String> {
        Set(collectedStamps.map(\.siteID))
    }

    private var stampsBySiteID: [String: CollectedStamp] {
        Dictionary(collectedStamps.map { ($0.siteID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty && walkRoutes.isEmpty && collectedStamps.isEmpty {
                    emptyState
                } else {
                    List {
                        stampSection

                        if !walkRoutes.isEmpty {
                            Section("ウォーキング履歴") {
                                ForEach(walkRoutes) { route in
                                    WalkRouteRow(
                                        route: route,
                                        stampCount: stampCount(for: route),
                                        onResume: { resume(route) }
                                    )
                                }
                                .onDelete(perform: deleteRoutes)
                            }
                        }

                        if !places.isEmpty {
                            Section("保存した物語") {
                                ForEach(places) { place in
                                    NavigationLink(value: place) {
                                        SavedPlaceRow(place: place)
                                    }
                                }
                                .onDelete(perform: deletePlaces)
                            }
                        }
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
            .sheet(item: $selectedStamp) { selection in
                StampCheckInSheet(site: selection.site, stamp: selection.stamp)
            }
            .sheet(item: shareImageBinding) { holder in
                ActivityView(items: [holder.image])
            }
        }
    }

    private var stampSection: some View {
        Section {
            LazyVGrid(columns: stampColumns, spacing: 10) {
                ForEach(HistoricSiteCatalog.all) { site in
                    let stamp = stampsBySiteID[site.id]
                    StampCell(site: site, stamp: stamp)
                        .onTapGesture {
                            if let stamp {
                                selectedStamp = StampSelection(site: site, stamp: stamp)
                            }
                        }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("御朱印 \(collectedStamps.count) / \(HistoricSiteCatalog.all.count)")
        } footer: {
            Text("「スタート」でウォーキングを記録しながら史跡チェックポイントに近づくと、御朱印が自動で貯まります。")
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

    private func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(places[index])
        }
    }

    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(walkRoutes[index])
        }
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

private struct WalkRouteRow: View {
    let route: WalkRoute
    let stampCount: Int
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(route.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.headline)
                Spacer()
                Button("再スタート", action: onResume)
                    .font(.subheadline)
                    .buttonStyle(.bordered)
            }

            Text(route.overlayMap?.title ?? "古地図なし")
                .font(.caption)
                .foregroundStyle(.brown)

            HStack(spacing: 12) {
                Label(distanceText, systemImage: "figure.walk")
                Label("不透明度 \(Int(route.overlayOpacity * 100))%", systemImage: "map")
                if stampCount > 0 {
                    Label("御朱印 \(stampCount)件", systemImage: "seal.fill")
                        .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var distanceText: String {
        let meters = route.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

private struct SavedPlaceRow: View {
    let place: SavedPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.title)
                .font(.headline)
            Text(place.era)
                .font(.caption)
                .foregroundStyle(.brown)
            Text(place.storyText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct IdentifiableImage: Identifiable {
    let image: UIImage
    var id: ObjectIdentifier { ObjectIdentifier(image) }
}

/// タップされたセルを御朱印チェックインシートへ渡すための値。
private struct StampSelection: Identifiable {
    let site: HistoricSite
    let stamp: CollectedStamp
    var id: String { site.id }
}

private struct StampCell: View {
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
        .modelContainer(for: [SavedPlace.self, WalkRoute.self, CollectedStamp.self], inMemory: true)
}
