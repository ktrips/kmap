import CoreLocation
import FirebaseFirestore
import Foundation
import SwiftData
import UIKit

/// 端末の記録（旅・御朱印・投稿写真・保存した物語）を、クラウド（`users/{uid}/…`）と合わせる。
///
/// 正本はクラウドで、端末のデータは電波が無くても使うための控え。同じGoogleアカウントなら、iOS・Web・他のスマホで
/// 同じ記録が見える。起動・サインイン・「マイ時空旅」を開いた時に呼ぶ（`sync`）。
///
/// - クラウドにあって端末に無い記録は取り込む（写真は Storage から取ってくる）。
/// - 両方にある記録は、名前・感想は新しい方（`detailsUpdatedAt`）を残し、公開の印などはクラウドに合わせる。
///   持ち主の分からない端末の記録（`ownerUserID`を持つ前に保存したもの）は、このアカウントのものにする。
/// - 端末にだけある記録は、一度もクラウドで見ていない（＝まだ上がっていない）なら上げる。前回までの同期でクラウドに
///   あった（＝他の端末・Webで消された）なら、全件を読む同期の時に端末からも消す。
///
/// 旅は軌跡の座標を含むので、毎回全件は読まない。普段は前回の同期の後に変わった文書（`updatedAt`が新しいもの）だけを
/// 読み、全件を読む（削除を見分ける）のは1日に1回か、「設定」の「すべてクラウドに同期」を押した時だけ。
@MainActor
enum CloudSync {
    /// 直近に同期した時刻（アカウントごと）。画面を開くたびに読み直さないよう、短い間は省く。
    private static var lastSyncedAt: [String: Date] = [:]
    private static let minimumInterval: TimeInterval = 60
    /// 全件を読む（削除を見分ける）間隔。
    private static let fullSyncInterval: TimeInterval = 24 * 60 * 60
    /// 端末とサーバーの時計のずれや、書き込みの遅れで取りこぼさないよう、前回の時刻より少し前から読む。
    private static let changedSinceMargin: TimeInterval = 5 * 60

    /// - Parameters:
    ///   - force: 直近に同期したばかりでも同期する。
    ///   - full: 全件を読み、他の端末・Webで消された記録も端末から消す（1日以上たっていれば自動で全件）。
    /// - Returns: 端末に新しく取り込んだ件数。クラウドを読めなかった時は`nil`。
    @discardableResult
    static func sync(
        userID: String,
        context: ModelContext,
        syncService: SyncService = SyncService(),
        force: Bool = false,
        full: Bool = false
    ) async -> Int? {
        if !force, let last = lastSyncedAt[userID], Date().timeIntervalSince(last) < minimumInterval { return 0 }
        let defaults = UserDefaults.standard
        let lastFullKey = "cloudSync.lastFull.\(userID)", lastChangedKey = "cloudSync.lastChanged.\(userID)"
        let lastFull = defaults.object(forKey: lastFullKey) as? Date
        let isFull = full || lastFull.map { Date().timeIntervalSince($0) > fullSyncInterval } ?? true
        let changedSince = isFull ? nil : (defaults.object(forKey: lastChangedKey) as? Date ?? lastFull)?
            .addingTimeInterval(-changedSinceMargin)
        let startedAt = Date()
        guard let cloud = try? await syncService.fetchCloudRecords(userID: userID, changedSince: changedSince) else { return nil }
        lastSyncedAt[userID] = startedAt
        var imported = 0

        // 旅
        var seenRoutes = SeenIDs(userID: userID, kind: "routes")
        for route in localRecords(WalkRoute.self, context: context, userID: userID) {
            let key = route.id.uuidString
            if let data = cloud.routes[key] {
                route.ownerUserID = userID
                if merge(route, with: data) { try? await syncService.upload(route, userID: userID, checkRemoteDetails: false) }
            } else if route.ownerUserID == userID {
                if seenRoutes.contains(key) {
                    if isFull { context.delete(route) }
                } else if (try? await syncService.upload(route, userID: userID, checkRemoteDetails: false)) != nil {
                    seenRoutes.insert(key)
                }
            }
        }
        let localRouteIDs = allIDs(WalkRoute.self, \.id, context)
        for (key, data) in cloud.routes where !localRouteIDs.contains(key) {
            if let id = UUID(uuidString: key), let route = makeRoute(id: id, data: data, userID: userID) {
                context.insert(route)
                imported += 1
            }
        }
        seenRoutes.formUnion(cloud.routes.keys)

        // 御朱印
        var seenStamps = SeenIDs(userID: userID, kind: "stamps")
        for stamp in localRecords(CollectedStamp.self, context: context, userID: userID) {
            let key = stamp.id.uuidString
            if cloud.stamps[key] != nil {
                stamp.ownerUserID = userID
            } else if stamp.ownerUserID == userID {
                if seenStamps.contains(key) {
                    if isFull {
                        stamp.updatePhoto(nil)
                        context.delete(stamp)
                    }
                } else {
                    await syncService.uploadTripContents(stamps: [stamp], photoPosts: [], userID: userID)
                    seenStamps.insert(key)
                }
            }
        }
        let localStampIDs = allIDs(CollectedStamp.self, \.id, context)
        for (key, data) in cloud.stamps where !localStampIDs.contains(key) {
            if let id = UUID(uuidString: key), let stamp = await makeStamp(id: id, data: data, userID: userID) {
                context.insert(stamp)
                imported += 1
            }
        }
        seenStamps.formUnion(cloud.stamps.keys)

        // 投稿写真
        var seenPosts = SeenIDs(userID: userID, kind: "photoPosts")
        for post in localRecords(WalkPhotoPost.self, context: context, userID: userID) {
            let key = post.id.uuidString
            if cloud.photoPosts[key] != nil {
                post.ownerUserID = userID
            } else if post.ownerUserID == userID {
                if seenPosts.contains(key) {
                    if isFull {
                        StampPhotoStore.delete(post.photoFileName)
                        context.delete(post)
                    }
                } else {
                    await syncService.uploadTripContents(stamps: [], photoPosts: [post], userID: userID)
                    seenPosts.insert(key)
                }
            }
        }
        let localPostIDs = allIDs(WalkPhotoPost.self, \.id, context)
        for (key, data) in cloud.photoPosts where !localPostIDs.contains(key) {
            if let id = UUID(uuidString: key), let post = await makePhotoPost(id: id, data: data, userID: userID) {
                context.insert(post)
                imported += 1
            }
        }
        seenPosts.formUnion(cloud.photoPosts.keys)

        // 保存した物語
        var seenPlaces = SeenIDs(userID: userID, kind: "places")
        for place in localRecords(SavedPlace.self, context: context, userID: userID) {
            let key = place.id.uuidString
            if cloud.places[key] != nil {
                place.ownerUserID = userID
            } else if place.ownerUserID == userID {
                if seenPlaces.contains(key) {
                    if isFull { context.delete(place) }
                } else if (try? await syncService.upload(place, userID: userID)) != nil {
                    seenPlaces.insert(key)
                }
            }
        }
        let localPlaceIDs = allIDs(SavedPlace.self, \.id, context)
        for (key, data) in cloud.places where !localPlaceIDs.contains(key) {
            if let id = UUID(uuidString: key), let place = makePlace(id: id, data: data, userID: userID) {
                context.insert(place)
                imported += 1
            }
        }
        seenPlaces.formUnion(cloud.places.keys)

        try? context.save()
        [seenRoutes, seenStamps, seenPosts, seenPlaces].forEach { $0.save() }
        defaults.set(startedAt, forKey: lastChangedKey)
        if isFull { defaults.set(startedAt, forKey: lastFullKey) }
        return imported
    }

    /// サインインする前に保存した記録（持ち主のいないもの）を、`userID`のアカウントのものにする。
    /// 「設定」の「すべてクラウドに同期」を押した時だけ使う（本人が自分の記録だと示した時）。次の`sync`で上がる。
    static func adoptUnownedRecords(userID: String, context: ModelContext) {
        for route in localRecords(WalkRoute.self, context: context, userID: nil) { route.ownerUserID = userID }
        for stamp in localRecords(CollectedStamp.self, context: context, userID: nil) { stamp.ownerUserID = userID }
        for post in localRecords(WalkPhotoPost.self, context: context, userID: nil) { post.ownerUserID = userID }
        for place in localRecords(SavedPlace.self, context: context, userID: nil) { place.ownerUserID = userID }
        try? context.save()
    }

    // MARK: - 端末の記録

    /// このアカウントの記録と、持ち主の分からない記録（`userID`が`nil`なら持ち主の分からない記録だけ）。
    private static func localRecords<T: PersistentModel & AccountOwned>(_ type: T.Type, context: ModelContext, userID: String?) -> [T] {
        ((try? context.fetch(FetchDescriptor<T>())) ?? []).filter { $0.ownerUserID == nil || $0.ownerUserID == userID }
    }

    /// 端末にある記録のID（どのアカウントのものでも）。クラウドの記録を二重に作らないため。
    private static func allIDs<T: PersistentModel>(_ type: T.Type, _ id: KeyPath<T, UUID>, _ context: ModelContext) -> Set<String> {
        Set(((try? context.fetch(FetchDescriptor<T>())) ?? []).map { $0[keyPath: id].uuidString })
    }

    /// 前回までの同期でクラウドにあった記録のID（アカウント・種類ごと）。クラウドから消えた記録を見分けるのに使う。
    private struct SeenIDs {
        let key: String
        var ids: Set<String>

        init(userID: String, kind: String) {
            key = "cloudSync.seen.\(userID).\(kind)"
            ids = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        }

        func contains(_ id: String) -> Bool { ids.contains(id) }
        mutating func insert(_ id: String) { ids.insert(id) }
        mutating func formUnion<S: Sequence>(_ other: S) where S.Element == String { ids.formUnion(other) }
        func save() { UserDefaults.standard.set(Array(ids), forKey: key) }
    }

    // MARK: - クラウドの文書と端末の記録を合わせる（`SyncService.upload`で書いた項目の逆）

    /// 両方にある旅を合わせる。名前・感想は新しい方を残し、公開の印・旅日記・動画はクラウドに合わせる。
    /// - Returns: 端末の名前・感想の方が新しく、クラウドへ上げ直す必要があるか。
    private static func merge(_ route: WalkRoute, with data: [String: Any]) -> Bool {
        route.isSharedPublicly = data["isSharedPublicly"] as? Bool ?? false
        if let title = data["travelJournalTitle"] as? String { route.travelJournalTitle = title }
        if let video = data["tripVideoURL"] as? String { route.tripVideoURL = video }
        if let markdown = data["travelJournalMarkdown"] as? String {
            route.travelJournalMarkdown = journalWithoutVideoLink(markdown, videoURL: route.tripVideoURL)
        }

        let remoteTitle = normalized(data["title"] as? String)
        let remoteNotes = normalized(data["notes"] as? String)
        let remoteUpdatedAt = (data["detailsUpdatedAt"] as? Timestamp)?.dateValue()
        let differs = remoteTitle != normalized(route.title) || remoteNotes != normalized(route.notes)
        let remoteIsNewer: Bool
        switch (remoteUpdatedAt, route.detailsUpdatedAt) {
        case let (remote?, local?): remoteIsNewer = remote > local
        case (_?, nil): remoteIsNewer = true
        // どちらにも日時が無い（この仕組みの前にWebで変えた）時は、iOSの変更はその都度上げているので、クラウドを正とする。
        case (nil, nil): remoteIsNewer = differs
        case (nil, _?): remoteIsNewer = false
        }
        if remoteIsNewer {
            route.title = remoteTitle
            route.notes = remoteNotes
            route.detailsUpdatedAt = remoteUpdatedAt ?? route.detailsUpdatedAt
            return false
        }
        return differs
    }

    private static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func makeRoute(id: UUID, data: [String: Any], userID: String) -> WalkRoute? {
        guard let latitudes = data["latitudes"] as? [Double],
              let longitudes = data["longitudes"] as? [Double],
              latitudes.count == longitudes.count, latitudes.count >= 2,
              let startedAt = (data["startedAt"] as? Timestamp)?.dateValue()
        else { return nil }
        let route = WalkRoute(
            id: id,
            coordinates: zip(latitudes, longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) },
            startedAt: startedAt,
            endedAt: (data["endedAt"] as? Timestamp)?.dateValue(),
            stepCount: data["stepCount"] as? Int,
            overlayMapID: data["overlayMapID"] as? String,
            travelJournalGeneratedAt: (data["travelJournalGeneratedAt"] as? Timestamp)?.dateValue()
        )
        route.ownerUserID = userID
        _ = merge(route, with: data)
        return route
    }

    /// クラウドの旅日記は末尾に動画のリンクを足して上げている（`travelJournalMarkdownWithVideoLink`）ので、取り除く。
    private static func journalWithoutVideoLink(_ markdown: String, videoURL: String?) -> String {
        guard let videoURL, !videoURL.isEmpty else { return markdown }
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

    private static func makePlace(id: UUID, data: [String: Any], userID: String) -> SavedPlace? {
        guard let title = data["title"] as? String,
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let era = data["era"] as? String,
              let storyText = data["storyText"] as? String
        else { return nil }
        let place = SavedPlace(
            id: id,
            title: title,
            latitude: latitude,
            longitude: longitude,
            overlayMapID: data["overlayMapID"] as? String,
            era: era,
            storyText: storyText,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
        place.ownerUserID = userID
        return place
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
