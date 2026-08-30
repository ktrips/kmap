import SwiftData
import SwiftUI

/// My TimeTripの「御朱印」サマリーカードをタップした時に開く、全チェックポイントの御朱印一覧。
struct StampListView: View {
    @Query(sort: \CollectedStamp.collectedAt, order: .reverse) private var collectedStamps: [CollectedStamp]

    @State private var selectedStamp: StampSelection?

    private let cardColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    private var stampsBySiteID: [String: CollectedStamp] {
        Dictionary(collectedStamps.map { ($0.siteID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: cardColumns, spacing: 12) {
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

                Text("「スタート」でウォーキングを記録しながら史跡チェックポイントに近づくと、御朱印が自動で貯まります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("御朱印 \(collectedStamps.count) / \(HistoricSiteCatalog.all.count)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStamp) { selection in
            StampCheckInSheet(site: selection.site, stamp: selection.stamp)
        }
    }
}

#Preview {
    NavigationStack {
        StampListView()
    }
    .modelContainer(for: [CollectedStamp.self], inMemory: true)
}
