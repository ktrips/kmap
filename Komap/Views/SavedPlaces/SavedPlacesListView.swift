import SwiftData
import SwiftUI

/// ユーザーが保存してきた地点（=自分だけの時間旅行の記録）の一覧。
struct SavedPlacesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.createdAt, order: .reverse) private var places: [SavedPlace]

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(places) { place in
                            NavigationLink(value: place) {
                                SavedPlaceRow(place: place)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("わたしの時間旅行")
            .navigationDestination(for: SavedPlace.self) { place in
                SavedPlaceDetailView(place: place)
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
            Text("マップで気になる場所をタップして、\n昔の物語を保存してみましょう。")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(places[index])
        }
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

#Preview {
    SavedPlacesListView()
        .modelContainer(for: SavedPlace.self, inMemory: true)
}
