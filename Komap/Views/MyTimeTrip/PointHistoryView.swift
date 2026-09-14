import SwiftData
import SwiftUI

/// My TimeTripの「時空ポイント」カードをタップした時に開く、獲得ポイントの内訳一覧。
/// 御朱印（+\(CollectedStamp.pointsPerStamp)pt/件）・写真投稿（+\(WalkPhotoPost.pointsPerPost)pt/枚）・
/// 歩いた距離（1kmあたり\(WalkRoute.pointsPerKilometer)pt）を、旅（`WalkRoute`）ごとにまとめて
/// 新しい順に表示する。どの旅にも紐付かない（記録前に獲得した等の）古いデータは「その他」に集約する。
struct PointHistoryView: View {
    @Query(sort: \WalkPhotoPost.postedAt, order: .reverse) private var photoPosts: [WalkPhotoPost]
    @Query(sort: \WalkRoute.startedAt, order: .reverse) private var walkRoutes: [WalkRoute]
    @Query(sort: \CollectedStamp.collectedAt, order: .reverse) private var collectedStamps: [CollectedStamp]

    private var tripGroups: [TripPoints] {
        walkRoutes.compactMap { route in
            let stamps = collectedStamps.filter { $0.walkRouteID == route.id }
            let posts = photoPosts.filter { $0.walkRouteID == route.id }
            let group = TripPoints(route: route, stampCount: stamps.count, photoCount: posts.count, photoPoints: posts.reduce(0) { $0 + $1.points })
            return group.totalPoints > 0 ? group : nil
        }
    }

    /// どの旅（`WalkRoute`）にも紐付かない御朱印・写真投稿（記録機能追加前の古いデータ等）。
    private var otherGroup: TripPoints? {
        let routeIDs = Set(walkRoutes.map(\.id))
        let stamps = collectedStamps.filter { $0.walkRouteID == nil || !routeIDs.contains($0.walkRouteID!) }
        let posts = photoPosts.filter { $0.walkRouteID == nil || !routeIDs.contains($0.walkRouteID!) }
        guard !stamps.isEmpty || !posts.isEmpty else { return nil }
        return TripPoints(route: nil, stampCount: stamps.count, photoCount: posts.count, photoPoints: posts.reduce(0) { $0 + $1.points })
    }

    private var totalPoints: Int {
        tripGroups.reduce(0) { $0 + $1.totalPoints } + (otherGroup?.totalPoints ?? 0)
    }

    var body: some View {
        ScrollView {
            if tripGroups.isEmpty && otherGroup == nil {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(tripGroups) { group in
                        TripPointsCard(group: group)
                    }
                    if let otherGroup {
                        TripPointsCard(group: otherGroup)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("ポイント \(totalPoints) pt")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("まだポイントがありません")
                .font(.headline)
            Text("ウォーキング中に御朱印を集める（+\(CollectedStamp.pointsPerStamp)pt/件）、「写真投稿」から気になった風景を残す（+\(WalkPhotoPost.pointsPerPost)pt/枚）、または歩く（1kmあたり\(Int(WalkRoute.pointsPerKilometer))pt）と、ポイントが貯まります。")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

/// 1つの旅（`WalkRoute`）で獲得したポイントの内訳。`route`が`nil`の時は
/// どの旅にも紐付かない「その他」の集計を表す。
private struct TripPoints: Identifiable {
    let route: WalkRoute?
    let stampCount: Int
    let photoCount: Int
    let photoPoints: Int

    var id: UUID { route?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }

    var stampPoints: Int { stampCount * CollectedStamp.pointsPerStamp }
    var walkPoints: Int { route?.distancePoints ?? 0 }
    var totalPoints: Int { stampPoints + photoPoints + walkPoints }

    private var distanceText: String? {
        guard let route, route.totalDistanceMeters > 0 else { return nil }
        let meters = route.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    var title: String {
        guard let route else { return "その他" }
        if let title = route.title, !title.isEmpty { return title }
        return route.overlayMap?.title ?? "名称未設定の時空旅"
    }

    var dateText: String? {
        guard let route else { return nil }
        return route.startedAt.formatted(.dateTime.year().month().day().hour().minute())
    }

    var walkLineText: String {
        if let distanceText {
            return "\(distanceText)歩いた"
        }
        return "歩いた距離"
    }
}

/// 1件の旅の、御朱印・写真投稿・歩いた距離それぞれのポイント内訳とトータルを表示するカード。
private struct TripPointsCard: View {
    let group: TripPoints

    private static let goldColor = Color(red: 0.86, green: 0.63, blue: 0.24)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(.subheadline.bold())
                if let dateText = group.dateText {
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                if group.stampCount > 0 {
                    breakdownRow(
                        icon: "seal.fill",
                        label: "御朱印ポイント（\(group.stampCount)件 × \(CollectedStamp.pointsPerStamp)pt）",
                        points: group.stampPoints
                    )
                }
                if group.photoCount > 0 {
                    breakdownRow(
                        icon: "camera.fill",
                        label: "写真投稿ポイント（\(group.photoCount)枚）",
                        points: group.photoPoints
                    )
                }
                if group.walkPoints > 0 {
                    breakdownRow(icon: "figure.walk", label: group.walkLineText, points: group.walkPoints)
                }
            }

            Divider()

            HStack {
                Text("この旅の合計")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(group.totalPoints) pt")
                    .font(.subheadline.bold())
                    .foregroundStyle(Self.goldColor)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func breakdownRow(icon: String, label: String, points: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text("+\(points) pt")
                .font(.footnote.bold())
        }
    }
}

#Preview {
    NavigationStack {
        PointHistoryView()
    }
    .modelContainer(for: [WalkPhotoPost.self, WalkRoute.self, CollectedStamp.self], inMemory: true)
}
