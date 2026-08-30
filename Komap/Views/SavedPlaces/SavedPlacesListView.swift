import SwiftData
import SwiftUI

/// ユーザーが保存してきた地点・ウォーキング履歴・御朱印をまとめた「わたしの時間旅行」タブ。
struct SavedPlacesListView: View {
    @EnvironmentObject private var mapSession: MapSessionState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.createdAt, order: .reverse) private var places: [SavedPlace]
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var walkRoutes: [WalkRoute]
    @Query private var collectedStamps: [CollectedStamp]

    var body: some View {
        NavigationStack {
            Group {
                if places.isEmpty && walkRoutes.isEmpty {
                    emptyState
                } else {
                    List {
                        if !walkRoutes.isEmpty {
                            Section("ウォーキング履歴") {
                                ForEach(walkRoutes) { route in
                                    NavigationLink(value: route) {
                                        WalkRouteRow(
                                            route: route,
                                            stampCount: stampCount(for: route),
                                            onResume: { resume(route) }
                                        )
                                    }
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
            .navigationTitle("わたしの時間旅行")
            .navigationDestination(for: SavedPlace.self) { place in
                SavedPlaceDetailView(place: place)
            }
            .navigationDestination(for: WalkRoute.self) { route in
                WalkRouteDetailView(route: route)
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

#Preview {
    SavedPlacesListView()
        .environmentObject(MapSessionState())
        .modelContainer(for: [SavedPlace.self, WalkRoute.self, CollectedStamp.self], inMemory: true)
}
