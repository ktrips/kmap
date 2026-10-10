import CoreLocation
import Foundation
import SwiftData

/// チェックイン（御朱印）・写真投稿のポイントについて、AIでその地点の情報（説明）を集めて保存する。
/// ポイントを1つずつ開かなくても、チェックインした時・写真を上げた時に自動で作り、
/// 写真や名前を変えた時は、それに合わせて作り直す。作った説明はクラウドにも上げ
/// （Webの旅のページ・公開ページにも出る）、旅日記も新しい説明で作り直す（`TravelJournalAutoUpdater`）。
///
/// - 御朱印のポイントの説明（`CheckpointStory`、史跡ごとに1つ）を自動で作るのは Komap Plus の時だけ
///   （無料の「場所の詳細」3か所分を、本人が開かないうちに使ってしまわないため）。手で直した説明は、
///   写真を変えても上書きしない。
/// - 写真投稿の説明（`WalkPhotoPost.storyTitle`/`storyBody`）は、これまでも写真を開けば無料で作っていたので、
///   Plus でなくても作る。
@MainActor
final class PointStoryAutoGenerator: ObservableObject {
    static let shared = PointStoryAutoGenerator()

    /// いま説明を作っている史跡（`siteID`）・投稿写真（`id`）。シートで「調べています…」を出すため。
    @Published private(set) var generatingSiteIDs: Set<String> = []
    @Published private(set) var generatingPostIDs: Set<UUID> = []

    /// 作っている途中で写真・名前が変わったポイント。今の分が終わったら、新しい内容でもう一度作り直す。
    private var staleSiteIDs: Set<String> = []
    private var stalePostIDs: Set<UUID> = []

    private let historyService = AIHistoryService()
    private let syncService = SyncService()
    private let geocoder = CLGeocoder()

    private init() {}

    // MARK: - 御朱印（チェックイン）のポイント

    /// チェックインした時・御朱印の写真を変えた時に呼ぶ。Plus でなければ何もしない。
    /// - Parameter photoChanged: 写真を追加・変更・削除した時は`true`（説明が既にあっても、写真に合わせて作り直す）。
    func stampChanged(_ stamp: CollectedStamp, photoChanged: Bool, context: ModelContext, userID: String?, isPlus: Bool) {
        guard isPlus else { return }
        Task {
            try? await generateCheckpointStory(for: stamp, overwrite: photoChanged, context: context, userID: userID, isPlus: isPlus)
        }
    }

    /// 史跡の説明をAIで作って保存し、その史跡の自分の御朱印に添えてクラウドへ上げる。
    /// - Parameter overwrite: 既に説明があっても作り直すか（手で直した説明は、それでも上書きしない）。
    func generateCheckpointStory(
        for stamp: CollectedStamp,
        overwrite: Bool,
        context: ModelContext,
        userID: String?,
        isPlus: Bool
    ) async throws {
        guard let site = stamp.site else { return }
        if generatingSiteIDs.contains(site.id) {
            if overwrite { staleSiteIDs.insert(site.id) }
            return
        }
        let existing = savedStory(siteID: site.id, in: context)
        if let existing, !overwrite || existing.isManuallyEdited { return }

        generatingSiteIDs.insert(site.id)
        defer {
            generatingSiteIDs.remove(site.id)
            if staleSiteIDs.remove(site.id) != nil {
                stampChanged(stamp, photoChanged: true, context: context, userID: userID, isPlus: isPlus)
            }
        }
        // チェックイン時の写真があれば、その内容も踏まえた説明にする。
        let story = try await historyService.generateStory(
            for: site.coordinate,
            overlayMap: OldMapCatalog.overlay(withID: site.overlayMapID),
            placeName: site.name,
            photo: stamp.photo
        )
        // 作っている間に手で直されていたら、そちらを残す。
        if let current = savedStory(siteID: site.id, in: context) {
            guard !current.isManuallyEdited else { return }
            current.title = story.title
            current.body = story.body
            current.updatedAt = Date()
        } else {
            context.insert(CheckpointStory(siteID: site.id, title: story.title, body: story.body))
        }
        try? context.save()

        await uploadDetail(story.body, siteID: site.id, context: context, userID: userID)
        TravelJournalAutoUpdater.shared.scheduleRefresh(context: context, userID: userID, isPlus: isPlus)
    }

    private func savedStory(siteID: String, in context: ModelContext) -> CheckpointStory? {
        let descriptor = FetchDescriptor<CheckpointStory>(predicate: #Predicate { $0.siteID == siteID })
        return try? context.fetch(descriptor).first
    }

    /// この史跡で獲得した自分の御朱印に、説明文を添えてクラウドへ上げる（Webの旅日記・公開ページにも同じ説明が出る）。
    private func uploadDetail(_ detail: String, siteID: String, context: ModelContext, userID: String?) async {
        guard let userID else { return }
        let descriptor = FetchDescriptor<CollectedStamp>(
            predicate: #Predicate { $0.siteID == siteID && $0.ownerUserID == userID }
        )
        for stamp in (try? context.fetch(descriptor)) ?? [] {
            try? await syncService.uploadDetail(detail, of: stamp, userID: userID)
        }
    }

    // MARK: - 写真投稿のポイント

    /// 写真を投稿した時・写真や名前を変えた時に呼ぶ。
    /// - Parameter regenerate: 写真・名前を変えた時は`true`（説明が既にあっても作り直す）。
    func photoPostChanged(_ post: WalkPhotoPost, regenerate: Bool, context: ModelContext, userID: String?, isPlus: Bool) {
        Task {
            try? await generatePostInfo(for: post, regenerate: regenerate, context: context, userID: userID, isPlus: isPlus)
        }
    }

    /// 投稿写真の場所の名前（逆ジオコーディング）とAIの説明を作って保存し、クラウドへ上げる。
    func generatePostInfo(
        for post: WalkPhotoPost,
        regenerate: Bool,
        context: ModelContext,
        userID: String?,
        isPlus: Bool
    ) async throws {
        if generatingPostIDs.contains(post.id) {
            if regenerate { stalePostIDs.insert(post.id) }
            return
        }
        guard regenerate || post.placeName == nil || post.storyTitle == nil else { return }
        generatingPostIDs.insert(post.id)
        defer {
            generatingPostIDs.remove(post.id)
            if stalePostIDs.remove(post.id) != nil {
                photoPostChanged(post, regenerate: true, context: context, userID: userID, isPlus: isPlus)
            }
        }

        if post.placeName == nil {
            let location = CLLocation(latitude: post.coordinate.latitude, longitude: post.coordinate.longitude)
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                post.placeName = [placemark.name, placemark.locality].compactMap { $0 }.first
            }
        }

        var storyError: Error?
        if regenerate || post.storyTitle == nil {
            do {
                // 写真の内容（被写体・雰囲気）と、付けた名前を踏まえた説明にする。
                let story = try await historyService.generateStory(
                    for: post.coordinate,
                    overlayMap: nil,
                    placeName: post.placeName,
                    userTitle: post.userTitle,
                    photo: post.photo
                )
                post.storyTitle = story.title
                post.storyBody = story.body
                post.storyUpdatedAt = Date()
            } catch {
                storyError = error
            }
        }

        try? context.save()
        // 場所の名前・AIの説明は、サインイン中ならクラウドにも反映し、Webでもこの写真の説明が出るようにする。
        try? await syncService.uploadInfo(of: post, userID: userID)
        if let storyError { throw storyError }
        TravelJournalAutoUpdater.shared.scheduleRefresh(context: context, userID: userID, isPlus: isPlus)
    }
}
