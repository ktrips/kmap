import Foundation
import SwiftData

/// 旅日記（AIの旅のサマリー）を、「旅日記を作成する」ボタンを押さなくても自動で作り、
/// 旅の名前・感想・御朱印や写真の名前／AIの説明が変わったら作り直して、クラウド経由で
/// Webの旅のページ（My Trips・公開中なら「みんなの時空旅」）にも反映する。
///
/// - 旅を保存した直後・アプリに戻った時・名前や説明を編集した時に`scheduleRefresh`を呼ぶ。
///   続けて何か所も直した時に毎回AIを呼ばないよう、少し待ってからまとめて1回だけ調べる。
/// - 作るのは、旅日記がまだ無い最近の旅（`recentTripWindow`以内）と、明示的に頼まれた旅
///   （`including`）。作り直すのは、旅日記を作った後に内容が変わった旅。
/// - AIの旅日記は Komap Plus の機能なので、Plus でなければ何もしない（手動の作成ボタンと同じ）。
@MainActor
final class TravelJournalAutoUpdater: ObservableObject {
    static let shared = TravelJournalAutoUpdater()

    /// いま旅日記を作っている旅（詳細画面で「作成中…」を出すため）。
    @Published private(set) var generatingRouteIDs: Set<UUID> = []

    /// 旅日記がまだ無い旅を自動で作る対象にする期間（それより前の旅は、開いた時だけ作る）。
    private let recentTripWindow: TimeInterval = 7 * 24 * 60 * 60
    /// 失敗した旅（APIキー未設定・通信エラーなど）は、しばらく自動では作り直さない。
    private let retryInterval: TimeInterval = 10 * 60

    private let journalService = TravelJournalService()
    private let syncService = SyncService()
    /// 待っている間の次の処理（待っている間に頼まれ直したら、待ち直す）。
    private var pendingRefresh: Task<Void, Never>?
    /// 処理中に頼まれた時は、途中の旅日記の作成を止めず、終わってからもう一度調べる。
    private var isRefreshing = false
    private var needsAnotherPass = false
    private var latestRequest: (context: ModelContext, userID: String?)?
    private var requestedRouteIDs: Set<UUID> = []
    private var lastFailureAt: [UUID: Date] = [:]

    private init() {}

    /// 少し待ってから、旅日記を作る・作り直す必要のある旅を探して処理する。
    /// - Parameter including: 旅日記が無ければ、古い旅でも作る旅（保存した直後の旅・開いた旅）。
    func scheduleRefresh(
        context: ModelContext,
        userID: String?,
        isPlus: Bool,
        including routeID: UUID? = nil,
        delay: Duration = .seconds(5)
    ) {
        guard isPlus else { return }
        if let routeID { requestedRouteIDs.insert(routeID) }
        latestRequest = (context, userID)
        if isRefreshing {
            needsAnotherPass = true
            return
        }
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.runRefreshes()
        }
    }

    private func runRefreshes() async {
        isRefreshing = true
        defer { isRefreshing = false }
        repeat {
            needsAnotherPass = false
            guard let request = latestRequest else { return }
            await refresh(context: request.context, userID: request.userID)
        } while needsAnotherPass
    }

    /// 1件の旅の旅日記を、今すぐ作る（作り直す）。手動の「作成する」「作り直す」ボタン用。
    func generate(for route: WalkRoute, context: ModelContext, userID: String?) async throws {
        guard !generatingRouteIDs.contains(route.id) else { return }
        generatingRouteIDs.insert(route.id)
        defer { generatingRouteIDs.remove(route.id) }

        let stamps = stamps(of: route, in: context)
        let photoPosts = photoPosts(of: route, in: context)
        let journal = try await journalService.generateJournal(
            for: route,
            stamps: stamps,
            photoPosts: photoPosts,
            modelContext: context
        )
        route.travelJournalTitle = journal.title
        route.travelJournalMarkdown = journal.markdownBody
        route.travelJournalGeneratedAt = Date()
        try? context.save()
        lastFailureAt[route.id] = nil

        guard let userID else { return }
        // 旅日記を作る途中で新しくAIが書いた史跡の説明も、御朱印に添えてWebに出す。
        let details = SyncService.checkpointDetailTexts(for: stamps, in: context)
        await syncService.uploadTripContents(stamps: stamps, photoPosts: photoPosts, userID: userID, checkpointDetails: details)
        try? await syncService.upload(route, userID: userID)
    }

    private func refresh(context: ModelContext, userID: String?) async {
        let requested = requestedRouteIDs
        requestedRouteIDs = []
        let descriptor = FetchDescriptor<WalkRoute>(
            predicate: #Predicate { $0.ownerUserID == userID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let routes = (try? context.fetch(descriptor)) ?? []
        for route in routes where needsJournal(route, requested: requested.contains(route.id), context: context) {
            do {
                try await generate(for: route, context: context, userID: userID)
            } catch {
                lastFailureAt[route.id] = Date()
            }
        }
    }

    private func needsJournal(_ route: WalkRoute, requested: Bool, context: ModelContext) -> Bool {
        guard route.endedAt != nil, !generatingRouteIDs.contains(route.id) else { return false }
        if !requested, let failedAt = lastFailureAt[route.id], Date().timeIntervalSince(failedAt) < retryInterval {
            return false
        }
        guard let generatedAt = route.travelJournalGeneratedAt, route.travelJournalMarkdown != nil else {
            return requested || route.startedAt > Date().addingTimeInterval(-recentTripWindow)
        }
        return latestContentChange(of: route, context: context) > generatedAt
    }

    /// 旅日記の内容に関わるもの（旅の名前・感想、御朱印・投稿写真の追加、その名前・AIの説明）が
    /// 最後に変わった日時。
    private func latestContentChange(of route: WalkRoute, context: ModelContext) -> Date {
        let stamps = stamps(of: route, in: context)
        let posts = photoPosts(of: route, in: context)
        var latest = route.detailsUpdatedAt ?? .distantPast
        for stamp in stamps { latest = max(latest, stamp.collectedAt) }
        for post in posts { latest = max(latest, post.postedAt, post.storyUpdatedAt ?? .distantPast) }
        if !stamps.isEmpty {
            let siteIDs = Set(stamps.map(\.siteID))
            let descriptor = FetchDescriptor<CheckpointStory>(predicate: #Predicate { siteIDs.contains($0.siteID) })
            for story in (try? context.fetch(descriptor)) ?? [] { latest = max(latest, story.updatedAt) }
        }
        return latest
    }

    private func stamps(of route: WalkRoute, in context: ModelContext) -> [CollectedStamp] {
        let routeID: UUID? = route.id
        let descriptor = FetchDescriptor<CollectedStamp>(
            predicate: #Predicate { $0.walkRouteID == routeID },
            sortBy: [SortDescriptor(\.collectedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func photoPosts(of route: WalkRoute, in context: ModelContext) -> [WalkPhotoPost] {
        let routeID: UUID? = route.id
        let descriptor = FetchDescriptor<WalkPhotoPost>(
            predicate: #Predicate { $0.walkRouteID == routeID },
            sortBy: [SortDescriptor(\.postedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
