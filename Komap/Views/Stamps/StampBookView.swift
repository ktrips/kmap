import SwiftData
import SwiftUI

/// 獲得した御朱印の一覧・進捗・共有をまとめた「御朱印帳」画面。
struct StampBookView: View {
    @Query(sort: \CollectedStamp.collectedAt, order: .reverse) private var stamps: [CollectedStamp]

    @State private var shareImage: UIImage?
    @State private var isPreparingShare = false
    @State private var selection: StampSelection?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var collectedSiteIDs: Set<String> {
        Set(stamps.map(\.siteID))
    }

    private var stampsBySiteID: [String: CollectedStamp] {
        Dictionary(stamps.map { ($0.siteID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    progressHeader

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(HistoricSiteCatalog.all) { site in
                            let stamp = stampsBySiteID[site.id]
                            StampCell(site: site, stamp: stamp)
                                .onTapGesture {
                                    if let stamp {
                                        selection = StampSelection(site: site, stamp: stamp)
                                    }
                                }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("御朱印帳")
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
                    .disabled(stamps.isEmpty || isPreparingShare)
                }
            }
            .sheet(item: shareImageBinding) { holder in
                ActivityView(items: [holder.image])
            }
            .sheet(item: $selection) { selection in
                StampCheckInSheet(site: selection.site, stamp: selection.stamp)
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(stamps.count) / \(HistoricSiteCatalog.all.count) 集めました")
                .font(.title3.bold())
            Text("「スタート」でウォーキングを記録しながら史跡チェックポイントに近づくと、御朱印が自動で貯まります。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                collectedCount: stamps.count,
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
    StampBookView()
        .modelContainer(for: CollectedStamp.self, inMemory: true)
}
