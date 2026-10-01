import Foundation
import SwiftData

/// 端末の旅・御朱印・投稿写真に、保存したアカウント（`ownerUserID`）を付ける。
///
/// `ownerUserID`を持つ前に保存した記録は、どのアカウントのものか分からない。サインイン中に保存した記録は
/// クラウド（`users/{uid}/walkRoutes`・`stamps`・`photoPosts`）にも上がっているので、クラウドに同じIDが
/// ある記録を、そのアカウントのものとする。アカウントごとに一度だけ行う（通信できなかった時は次回やり直す）。
@MainActor
enum AccountOwnership {
    private static func claimedKey(for userID: String) -> String { "accountOwnership.claimed.\(userID)" }

    static func claimCloudLinkedRecords(userID: String, context: ModelContext, syncService: SyncService = SyncService()) async {
        guard !UserDefaults.standard.bool(forKey: claimedKey(for: userID)) else { return }
        guard let cloud = try? await syncService.fetchCloudRecordIDs(userID: userID) else { return }

        let routes = (try? context.fetch(FetchDescriptor<WalkRoute>(predicate: #Predicate { $0.ownerUserID == nil }))) ?? []
        for route in routes where cloud.routes.contains(route.id) {
            route.ownerUserID = userID
        }
        let stamps = (try? context.fetch(FetchDescriptor<CollectedStamp>(predicate: #Predicate { $0.ownerUserID == nil }))) ?? []
        for stamp in stamps where cloud.stamps.contains(stamp.id) {
            stamp.ownerUserID = userID
        }
        let posts = (try? context.fetch(FetchDescriptor<WalkPhotoPost>(predicate: #Predicate { $0.ownerUserID == nil }))) ?? []
        for post in posts where cloud.photoPosts.contains(post.id) {
            post.ownerUserID = userID
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: claimedKey(for: userID))
    }

    /// サインインする前に保存した記録（持ち主のいないもの）を、`userID`のアカウントのものにする。
    /// 「設定」の「すべてクラウドに同期」を押した時だけ使う（本人が自分の記録だと示した時）。
    static func adoptUnownedRecords(userID: String, context: ModelContext) {
        let routes = (try? context.fetch(FetchDescriptor<WalkRoute>(predicate: #Predicate { $0.ownerUserID == nil }))) ?? []
        routes.forEach { $0.ownerUserID = userID }
        let stamps = (try? context.fetch(FetchDescriptor<CollectedStamp>(predicate: #Predicate { $0.ownerUserID == nil }))) ?? []
        stamps.forEach { $0.ownerUserID = userID }
        let posts = (try? context.fetch(FetchDescriptor<WalkPhotoPost>(predicate: #Predicate { $0.ownerUserID == nil }))) ?? []
        posts.forEach { $0.ownerUserID = userID }
        try? context.save()
    }
}
