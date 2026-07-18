import CoreLocation
import SwiftData
import SwiftUI

/// タップした地点についてAIが生成した「昔の物語」を表示し、
/// 気に入ったものを自分のマップとして保存できるシート。
struct StorySheetView: View {
    let point: TappedPoint
    let overlayMap: HistoricalOverlayMap?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    @State private var isLoading = true
    @State private var story: GeneratedStory?
    @State private var errorMessage: String?
    @State private var isSaved = false
    @State private var syncStatusMessage: String?

    private let service = AIHistoryService()
    private let syncService = SyncService()

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
            .navigationTitle("昔のこの場所")
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
        VStack(alignment: .leading, spacing: 4) {
            Label(overlayMap?.era ?? "江戸時代", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.bold())
                .foregroundStyle(.brown)
            Text(String(format: "緯度 %.5f / 経度 %.5f", point.coordinate.latitude, point.coordinate.longitude))
                .font(.caption)
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

            Button {
                Task { await save(story) }
            } label: {
                Label(isSaved ? "保存しました" : "自分のマップに保存する", systemImage: isSaved ? "checkmark.circle.fill" : "bookmark.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaved)
            .padding(.top, 8)

            if let syncStatusMessage {
                Text(syncStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadStory() async {
        isLoading = true
        errorMessage = nil
        do {
            story = try await service.generateStory(for: point.coordinate, overlayMap: overlayMap)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save(_ story: GeneratedStory) async {
        let place = SavedPlace(
            title: story.title,
            latitude: point.coordinate.latitude,
            longitude: point.coordinate.longitude,
            overlayMapID: overlayMap?.id,
            era: overlayMap?.era ?? "江戸時代",
            storyText: story.body
        )
        modelContext.insert(place)
        isSaved = true

        guard authService.isSignedIn else {
            syncStatusMessage = "端末に保存しました（設定タブでAppleサインインするとWebでも見られます）"
            return
        }

        do {
            try await syncService.upload(place, userID: authService.userID)
            syncStatusMessage = "端末とクラウドに保存しました。Webアプリでも見られます。"
        } catch {
            syncStatusMessage = "端末には保存しましたが、クラウドへの同期に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    StorySheetView(
        point: TappedPoint(coordinate: CLLocationCoordinate2D(latitude: 35.685, longitude: 139.752)),
        overlayMap: OldMapCatalog.edoCastle
    )
    .environmentObject(AuthService())
}
