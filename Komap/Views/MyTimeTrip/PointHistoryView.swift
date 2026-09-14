import SwiftData
import SwiftUI

/// My TimeTripの「ポイント」サマリーカードをタップした時に開く、獲得履歴一覧。
/// 写真投稿（+10pt/枚）と、歩いた距離（1kmあたり`WalkRoute.pointsPerKilometer`pt）の
/// 両方を、日時が新しい順にまとめて表示する。
struct PointHistoryView: View {
    @Query(sort: \WalkPhotoPost.postedAt, order: .reverse) private var photoPosts: [WalkPhotoPost]
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var walkRoutes: [WalkRoute]

    @State private var selectedPost: WalkPhotoPost?

    private var entries: [PointEntry] {
        let photoEntries = photoPosts.map(PointEntry.photo)
        let walkEntries = walkRoutes.filter { $0.distancePoints > 0 }.map(PointEntry.walk)
        return (photoEntries + walkEntries).sorted { $0.date > $1.date }
    }

    private var totalPoints: Int {
        entries.reduce(0) { $0 + $1.points }
    }

    var body: some View {
        ScrollView {
            if entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        switch entry {
                        case .photo(let post):
                            PhotoPostRow(post: post)
                                .onTapGesture {
                                    selectedPost = post
                                }
                        case .walk(let route):
                            WalkDistancePointRow(route: route)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("ポイント \(totalPoints) pt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPost) { post in
            PhotoPostPreviewSheet(post: post)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("まだポイントがありません")
                .font(.headline)
            Text("ウォーキングの記録中に「写真投稿」から気になった風景を残す、または歩くと、ポイントが貯まります（歩いた距離1kmあたり\(Int(WalkRoute.pointsPerKilometer))pt）。")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

/// ポイント履歴に表示する1件（写真投稿、または歩いた距離によるポイント）。
private enum PointEntry: Identifiable {
    case photo(WalkPhotoPost)
    case walk(WalkRoute)

    var id: String {
        switch self {
        case .photo(let post): "photo-\(post.id)"
        case .walk(let route): "walk-\(route.id)"
        }
    }

    var date: Date {
        switch self {
        case .photo(let post): post.postedAt
        case .walk(let route): route.startedAt
        }
    }

    var points: Int {
        switch self {
        case .photo(let post): post.points
        case .walk(let route): route.distancePoints
        }
    }
}

/// ポイント履歴の1行。投稿写真・日時・獲得ポイントを表示する。
private struct PhotoPostRow: View {
    let post: WalkPhotoPost

    var body: some View {
        HStack(spacing: 12) {
            if let photo = post.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(post.postedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline.bold())
                Text("+\(post.points) pt")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// ポイント履歴の1行。歩いた距離とそれに応じて獲得したポイントを表示する。
private struct WalkDistancePointRow: View {
    let route: WalkRoute

    private var distanceText: String {
        let meters = route.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km歩いた", meters / 1000)
        }
        return String(format: "%.0f m歩いた", meters)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(route.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline.bold())
                Text(distanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("+\(route.distancePoints) pt")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PointHistoryView()
    }
    .modelContainer(for: [WalkPhotoPost.self, WalkRoute.self], inMemory: true)
}
