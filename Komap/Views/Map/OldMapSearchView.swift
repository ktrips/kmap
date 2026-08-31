import SwiftUI

/// 「古地図を選択」メニュー最下部の「新しい古地図を登録」から開く、古地図の検索・追加画面。
/// AIが地域の説明からおおよその位置を推定し、Web検索で見つけた古地図の画像と
/// 組み合わせて候補を1件提示する。
struct OldMapSearchView: View {
    /// 候補が追加された時に呼ばれる（呼び出し側でマップに選択・移動する等に使う）。
    var onAdd: (HistoricalOverlayMap) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var isSearching = false
    @State private var result: OldMapSearchResult?
    @State private var errorMessage: String?

    private let service = OldMapSearchService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "例: 六本木付近の、毛利庭園や乃木神社などをポイントとした、明治以後の古地図を見つけて",
                        text: $query,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    Button {
                        Task { await search() }
                    } label: {
                        if isSearching {
                            ProgressView()
                        } else {
                            Label("検索する", systemImage: "magnifyingglass")
                        }
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                } header: {
                    Text("見つけたい古地図の地域")
                } footer: {
                    Text("AIが説明からおおよその位置を推定し、Web検索で見つけた古地図の画像と組み合わせて候補を作ります。位置合わせは概算のため、実際の史料とは多少ずれます。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let result {
                    resultSection(result)
                }
            }
            .navigationTitle("古地図を検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func resultSection(_ result: OldMapSearchResult) -> some View {
        Section("見つかった候補") {
            Image(uiImage: result.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(result.title)
                .font(.headline)
            Text(result.era)
                .font(.subheadline.bold())
                .foregroundStyle(.brown)
            Text(result.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("この古地図を追加する") {
                addResult(result)
            }
        }
    }

    private func search() async {
        isSearching = true
        errorMessage = nil
        result = nil
        do {
            result = try await service.search(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func addResult(_ result: OldMapSearchResult) {
        guard let overlay = CustomOverlayMapStore.add(
            title: result.title,
            era: result.era,
            summary: result.summary,
            image: result.image,
            southWest: result.southWest,
            northEast: result.northEast
        ) else { return }
        onAdd(overlay)
        dismiss()
    }
}

#Preview {
    OldMapSearchView(onAdd: { _ in })
}
