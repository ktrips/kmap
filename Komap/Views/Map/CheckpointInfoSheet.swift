import SwiftUI

/// チェックポイント（史跡・御朱印の場所）マーカー上の小さなアイコンボタンをタップした時に
/// 表示する、その地域にまつわる情報シート。
///
/// `StorySheetView`と異なり「自分のマップに保存する」操作は持たない。
/// チェックポイントは誰の地図上でも同じ位置に表示される共有のポイントなので、
/// ここではその場所にまつわる情報をさりげなく見せるだけにとどめる。
struct CheckpointInfoSheet: View {
    let site: HistoricSite
    let overlayMap: HistoricalOverlayMap?

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var story: GeneratedStory?
    @State private var errorMessage: String?

    private let service = AIHistoryService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if isLoading {
                        loadingView
                    } else if let errorMessage {
                        errorView(errorMessage)
                    } else if let story {
                        storyView(story)
                    }
                }
                .padding()
            }
            .navigationTitle(site.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task {
            await loadStory()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(overlayMap?.era ?? "江戸時代", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.bold())
                .foregroundStyle(.brown)
            Text(site.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("AIが昔の出来事を紐解いています…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .foregroundStyle(.red)
            Button("もう一度試す") {
                Task { await loadStory() }
            }
        }
    }

    private func storyView(_ story: GeneratedStory) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(story.title)
                .font(.title3.bold())
            Text(story.body)
                .font(.body)
                .lineSpacing(4)
        }
    }

    private func loadStory() async {
        isLoading = true
        errorMessage = nil
        do {
            story = try await service.generateStory(
                for: site.coordinate,
                overlayMap: overlayMap,
                placeName: site.name
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    CheckpointInfoSheet(
        site: HistoricSiteCatalog.all[0],
        overlayMap: OldMapCatalog.edoCastle
    )
}
