import CoreLocation
import FirebaseFirestore
import Foundation
import SwiftData
import UIKit

/// 同じGoogleアカウントで記録した旅・御朱印・投稿写真を、どの端末でも同じように見られるようにする。
///
/// - クラウド（`users/{uid}/walkRoutes`・`stamps`・`photoPosts`）にあって端末に無い記録は、
///   この端末に取り込む（写真は Storage から取ってくる）。別のスマホで記録した旅も、ここで見えるようになる。
/// - 端末にある持ち主の分からない記録（`ownerUserID`を持つ前に保存したもの）は、クラウドに同じIDがあれば
///   そのアカウントのものにする。サインイン中に保存した記録は、クラウドにも上がっているため。
/// Webは同じクラウドのデータを直接表示しているので、iOSとWebでも同じ旅が見える。
@MainActor
enum AccountOwnership {
    /// 直近に取り込んだ時刻（アカウントごと）。画面を開くたびに全件を読み直さないよう、短い間は省く。
    private static var lastRestoredAt: [String: Date] = [:]
    private static let minimumInterval: TimeInterval = 60

    /// クラウドの記録をこの端末に取り込む。
    /// - Returns: 端末に新しく取り込んだ件数（旅・御朱印・投稿写真の合計）。
    @discardableResult
    static func restoreFromCloud(userID: String, context: ModelContext, syncService: SyncService = SyncService(), force: Bool = false) async -> Int {
        if !force, let last = lastRestoredAt[userID], Date().timeIntervalSince(last) < minimumInterval { return 0 }
        guard let cloud = try? await syncService.fetchCloudRecords(userID: userID) else { return 0 }
        lastRestoredAt[userID] = Date()

        var importedCount = 0
        let localRoutes = Dictionary(
            ((try? context.fetch(FetchDescriptor<WalkRoute>())) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for record in cloud.routes {
            guard let id = UUID(uuidString: record.id) else { continue }
            if let local = localRoutes[id] {
                if local.ownerUserID == nil { local.ownerUserID = userID }
            } else if let route = makeRoute(id: id, data: record.data, userID: userID) {
                context.insert(route)
                importedCount += 1
            }
        }

        let localStamps = Dictionary(
            ((try? context.fetch(FetchDescriptor<CollectedStamp>())) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for record in cloud.stamps {
            guard let id = UUID(uuidString: record.id) else { continue }
            if let local = localStamps[id] {
                if local.ownerUserID == nil { local.ownerUserID = userID }
            } else if let stamp = await makeStamp(id: id, data: record.data, userID: userID) {
                context.insert(stamp)
                importedCount += 1
            }
        }

        let localPosts = Dictionary(
            ((try? context.fetch(FetchDescriptor<WalkPhotoPost>())) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for record in cloud.photoPosts {
            guard let id = UUID(uuidString: record.id) else { continue }
            if let local = localPosts[id] {
                if local.ownerUserID == nil { local.ownerUserID = userID }
            } else if let post = await makePhotoPost(id: id, data: record.data, userID: userID) {
                context.insert(post)
                importedCount += 1
            }
        }

        try? context.save()
        return importedCount
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

    // MARK: - クラウドの文書から端末の記録を作る（`SyncService.upload`で書いた項目の逆）

    private static func makeRoute(id: UUID, data: [String: Any], userID: String) -> WalkRoute? {
        guard let latitudes = data["latitudes"] as? [Double],
              let longitudes = data["longitudes"] as? [Double],
              latitudes.count == longitudes.count, latitudes.count >= 2,
              let startedAt = (data["startedAt"] as? Timestamp)?.dateValue()
        else { return nil }
        let tripVideoURL = data["tripVideoURL"] as? String
        let route = WalkRoute(
            id: id,
            coordinates: zip(latitudes, longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) },
            startedAt: startedAt,
            endedAt: (data["endedAt"] as? Timestamp)?.dateValue(),
            stepCount: data["stepCount"] as? Int,
            overlayMapID: data["overlayMapID"] as? String,
            title: data["title"] as? String,
            notes: data["notes"] as? String,
            isSharedPublicly: data["isSharedPublicly"] as? Bool ?? false,
            travelJournalTitle: data["travelJournalTitle"] as? String,
            travelJournalMarkdown: journalWithoutVideoLink(data["travelJournalMarkdown"] as? String, videoURL: tripVideoURL),
            travelJournalGeneratedAt: (data["travelJournalGeneratedAt"] as? Timestamp)?.dateValue()
        )
        route.tripVideoURL = tripVideoURL
        route.detailsUpdatedAt = (data["detailsUpdatedAt"] as? Timestamp)?.dateValue()
        route.ownerUserID = userID
        return route
    }

    /// クラウドの旅日記は末尾に動画のリンクを足して上げている（`travelJournalMarkdownWithVideoLink`）ので、取り除く。
    private static func journalWithoutVideoLink(_ markdown: String?, videoURL: String?) -> String? {
        guard let markdown, let videoURL, !videoURL.isEmpty else { return markdown }
        let suffix = "\n\n[▶ 旅の動画を見る](\(videoURL))"
        return markdown.hasSuffix(suffix) ? String(markdown.dropLast(suffix.count)) : markdown
    }

    private static func makeStamp(id: UUID, data: [String: Any], userID: String) async -> CollectedStamp? {
        guard let siteID = data["siteID"] as? String else { return nil }
        let photoURL = data["photoURL"] as? String
        let stamp = CollectedStamp(
            id: id,
            siteID: siteID,
            collectedAt: (data["collectedAt"] as? Timestamp)?.dateValue() ?? Date(),
            photoFileName: await downloadPhoto(photoURL),
            walkRouteID: (data["walkRouteID"] as? String).flatMap(UUID.init(uuidString:))
        )
        stamp.cloudPhotoURL = photoURL
        stamp.ownerUserID = userID
        return stamp
    }

    /// 投稿写真は写真が本体なので、写真を取ってこられた時だけ作る（取れなければ次の機会にやり直す）。
    private static func makePhotoPost(id: UUID, data: [String: Any], userID: String) async -> WalkPhotoPost? {
        guard let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let photoURL = data["photoURL"] as? String,
              let fileName = await downloadPhoto(photoURL)
        else { return nil }
        let post = WalkPhotoPost(
            id: id,
            photoFileName: fileName,
            postedAt: (data["postedAt"] as? Timestamp)?.dateValue() ?? Date(),
            points: data["points"] as? Int ?? WalkPhotoPost.pointsPerPost,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            walkRouteID: (data["walkRouteID"] as? String).flatMap(UUID.init(uuidString:))
        )
        post.placeName = data["placeName"] as? String
        post.userTitle = data["userTitle"] as? String
        post.storyTitle = data["storyTitle"] as? String
        post.storyBody = data["storyBody"] as? String
        post.storyUpdatedAt = (data["storyUpdatedAt"] as? Timestamp)?.dateValue()
        post.cloudPhotoURL = photoURL
        post.ownerUserID = userID
        return post
    }

    /// Storage の写真を取ってきて端末に保存し、ファイル名を返す。
    private static func downloadPhoto(_ urlString: String?) async -> String? {
        guard let urlString, let url = URL(string: urlString),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data)
        else { return nil }
        return StampPhotoStore.save(image)
    }
}
