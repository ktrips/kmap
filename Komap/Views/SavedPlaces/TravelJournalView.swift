import SwiftUI

/// AIが生成した旅行記を読むための画面。
struct TravelJournalView: View {
    let route: WalkRoute

    @Environment(\.dismiss) private var dismiss

    private var bodyText: AttributedString {
        (try? AttributedString(
            markdown: route.travelJournalMarkdown ?? "",
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(route.travelJournalMarkdown ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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

                    Text(bodyText)
                        .font(.body)
                        .padding(.top, 4)
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
        )
    )
}
