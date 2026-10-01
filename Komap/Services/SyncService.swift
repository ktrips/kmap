import CoreLocation
import FirebaseCore
import FirebaseFirestore
import Foundation
import SwiftData
import UIKit

/// 保存した地点（`SavedPlace`）を、Firestore上の
/// `users/{uid}/places/{id}` コレクションへアップロード／取得する。
///
/// この同じコレクションをWebアプリ（map.ktrips.net）側からも読み込むことで、
/// 同じGoogleアカウントでサインインしたユーザーが、iOSで保存した「自分のマップ」を
/// Web上でも見られるようにしている。
struct SyncService {
    enum SyncError: LocalizedError {
        case notSignedIn
        case firebaseNotConfigured

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Webでも見られるようにするには、設定タブでGoogleサインインしてください。"
            case .firebaseNotConfigured:
                return "Firebaseが設定されていないため、クラウド同期は利用できません。"
            }
        }
    }

    private let photoStorage = PhotoStorageService()

    private var isFirebaseConfigured: Bool { FirebaseApp.app() != nil }

    private func placesCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("places")
    }

    private func stampsCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("stamps")
    }

    private func photoPostsCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("photoPosts")
    }

    private func walkRoutesCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("walkRoutes")
    }

    /// 全ユーザー共通の「みんなの時空旅」。`users/{uid}/walkRoutes`とは別に、
    /// トップレベルの`sharedTrips`へ公開したものだけを置く（サインインしていれば誰でも読める）。
    private var sharedTripsCollection: CollectionReference {
        Firestore.firestore().collection("sharedTrips")
    }

    /// ランキング表示用の公開統計（表示名・今週/通算ポイント）。本人だけが自分の文書を書ける。
    private var userPublicStatsCollection: CollectionReference {
        Firestore.firestore().collection("userPublicStats")
    }

    /// 友達申請。
    private var friendRequestsCollection: CollectionReference {
        Firestore.firestore().collection("friendRequests")
    }

    /// 承認済みの友達関係（1組1文書）。
    private var friendshipsCollection: CollectionReference {
        Firestore.firestore().collection("friendships")
    }

    private func stampPhotoStoragePath(userID: String, stampID: UUID) -> String {
        "users/\(userID)/stamps/\(stampID.uuidString).jpg"
    }

    private func photoPostStoragePath(userID: String, postID: UUID) -> String {
        "users/\(userID)/photoPosts/\(postID.uuidString).jpg"
    }

    /// 1件をアップロード（新規作成 or 上書き更新）する。
    func upload(_ place: SavedPlace, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }

        let data: [String: Any] = [
            "title": place.title,
            "latitude": place.latitude,
            "longitude": place.longitude,
            "overlayMapID": place.overlayMapID as Any? ?? NSNull(),
            "era": place.era,
            "storyText": place.storyText,
            "createdAt": Timestamp(date: place.createdAt),
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        try await placesCollection(for: userID)
            .document(place.id.uuidString)
            .setData(data, merge: true)
    }

    /// 旅の動画をクラウドへ上げ、共有用リンクを`route.tripVideoURL`に保存して時空旅も同期する。
    /// 旅日記（Webの旅日記も含む）にこのリンクが載る。
    @discardableResult
    func uploadTripVideo(_ route: WalkRoute, fileURL: URL, userID: String?) async throws -> URL {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }
        let url = try await photoStorage.uploadVideo(
            fileURL: fileURL, path: "users/\(userID)/tripVideos/\(route.id.uuidString).mp4"
        )
        route.tripVideoURL = url.absoluteString
        try await upload(route, userID: userID)
        return url
    }

    /// 削除をクラウド側にも反映する。
    func delete(placeID: UUID, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }
        try await placesCollection(for: userID).document(placeID.uuidString).delete()
    }

    /// 獲得した御朱印（`CollectedStamp`）を `users/{uid}/stamps/{id}` へアップロードする。
    /// `detail`（その御朱印スポットの説明文）を渡した時だけ、あわせて書き込む
    /// （渡さない呼び出しでは、既に同期済みの説明文をmergeで消してしまわないよう
    /// キー自体を含めない）。
    func upload(_ stamp: CollectedStamp, userID: String?, detail: String? = nil) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }

        var data: [String: Any] = [
            "siteID": stamp.siteID,
            "collectedAt": Timestamp(date: stamp.collectedAt),
            "photoURL": stamp.cloudPhotoURL as Any? ?? NSNull(),
            "walkRouteID": stamp.walkRouteID?.uuidString as Any? ?? NSNull(),
            // 公開ページ（Cloud Functions が作る写真の一覧）で使う史跡名。
            "siteName": HistoricSiteCatalog.site(withID: stamp.siteID)?.name ?? "御朱印",
            // 別の端末が、前回の同期の後に変わった分だけを読む（`CloudSync`）ための時刻。
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let detail, !detail.isEmpty {
            data["detail"] = detail
        }

        try await stampsCollection(for: userID)
            .document(stamp.id.uuidString)
            .setData(data, merge: true)
    }

    /// 御朱印に添えた写真を、スマホできれいに見える範囲まで圧縮してアップロードし、
    /// `stamp.cloudPhotoURL`に反映してからFirestoreのドキュメントも更新する。
    @discardableResult
    func uploadStampPhoto(_ stamp: CollectedStamp, userID: String?) async throws -> URL? {
        guard let userID else { throw SyncError.notSignedIn }
        guard let image = stamp.photo else { return nil }
        let url = try await photoStorage.upload(image, path: stampPhotoStoragePath(userID: userID, stampID: stamp.id))
        stamp.cloudPhotoURL = url.absoluteString
        try await upload(stamp, userID: userID)
        return url
    }

    /// 御朱印の写真をクラウドから削除する（差し替え・削除時に使う）。
    func deleteStampPhoto(_ stamp: CollectedStamp, userID: String?) async {
        guard let userID else { return }
        await photoStorage.delete(path: stampPhotoStoragePath(userID: userID, stampID: stamp.id))
    }

    /// 「みんなの時空旅」（全ユーザーの公開中の旅。自分が公開したものも含む）を、
    /// 開始日時が新しい順に取得する。マップ画面の「マイ時空旅」タブから、
    /// 他ユーザーも含めた公開済み時空旅を時系列で一覧表示するために使う。
    func fetchAllSharedTrips(limit: Int = 60) async throws -> [RemoteSharedTrip] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }

        // 旅の正本（`users/{uid}/walkRoutes`）のうち、公開中のものを全ユーザー分まとめて探す。
        let snapshot = try await Firestore.firestore().collectionGroup("walkRoutes")
            .whereField("isSharedPublicly", isEqualTo: true)
            .order(by: "startedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            var data = document.data()
            if data["ownerUserID"] == nil, let ownerUserID = document.reference.parent.parent?.documentID {
                data["ownerUserID"] = ownerUserID
            }
            return RemoteSharedTrip(id: document.documentID, data: data)
        }
    }

    /// 投稿写真（`WalkPhotoPost`）を `users/{uid}/photoPosts/{id}` へアップロードする。
    func upload(_ post: WalkPhotoPost, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }

        let data: [String: Any] = [
            "photoURL": post.cloudPhotoURL as Any? ?? NSNull(),
            "postedAt": Timestamp(date: post.postedAt),
            "points": post.points,
            "latitude": post.latitude,
            "longitude": post.longitude,
            "walkRouteID": post.walkRouteID?.uuidString as Any? ?? NSNull(),
            "placeName": post.placeName as Any? ?? NSNull(),
            "userTitle": post.userTitle as Any? ?? NSNull(),
            "storyTitle": post.storyTitle as Any? ?? NSNull(),
            "storyBody": post.storyBody as Any? ?? NSNull(),
            "storyUpdatedAt": post.storyUpdatedAt.map(Timestamp.init(date:)) as Any? ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        try await photoPostsCollection(for: userID)
            .document(post.id.uuidString)
            .setData(data, merge: true)
    }

    /// 投稿写真の画像本体を、スマホできれいに見える範囲まで圧縮してアップロードし、
    /// `post.cloudPhotoURL`に反映してからFirestoreのドキュメントも更新する。
    @discardableResult
    func uploadPhotoPostImage(_ post: WalkPhotoPost, userID: String?) async throws -> URL? {
        guard let userID else { throw SyncError.notSignedIn }
        guard let image = post.photo else { return nil }
        let url = try await photoStorage.upload(image, path: photoPostStoragePath(userID: userID, postID: post.id))
        post.cloudPhotoURL = url.absoluteString
        try await upload(post, userID: userID)
        return url
    }

    /// 投稿写真を削除する（Firestoreのドキュメント・Storageの画像本体の両方）。
    /// ローカル（SwiftData・端末上の画像ファイル）の削除は呼び出し側が別途行う。
    func deletePhotoPost(id: UUID, userID: String?) async {
        guard let userID else { return }
        await photoStorage.delete(path: photoPostStoragePath(userID: userID, postID: id))
        try? await photoPostsCollection(for: userID).document(id.uuidString).delete()
    }

    /// 保存した時間旅（`WalkRoute`）を `users/{uid}/walkRoutes/{id}` へアップロードする。
    /// Webアプリの「My Trips」で、同じGoogleアカウントの記録を見られるようにするために使う。
    /// - Parameter checkRemoteDetails: クラウド側の名前・感想の方が新しいかを確かめてから書くか。
    ///   直前に`CloudSync`で取り込み済みの時は`false`にして、1件ごとの読み込みを省く。
    func upload(_ route: WalkRoute, userID: String?, checkRemoteDetails: Bool = true) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }

        let data: [String: Any] = [
            "title": route.title as Any? ?? NSNull(),
            "notes": route.notes as Any? ?? NSNull(),
            "latitudes": route.latitudes,
            "longitudes": route.longitudes,
            "startedAt": Timestamp(date: route.startedAt),
            "endedAt": route.endedAt.map { Timestamp(date: $0) } as Any? ?? NSNull(),
            "stepCount": route.stepCount as Any? ?? NSNull(),
            "overlayMapID": route.overlayMapID as Any? ?? NSNull(),
            "totalDistanceMeters": route.totalDistanceMeters,
            "isSharedPublicly": route.isSharedPublicly,
            "travelJournalTitle": route.travelJournalTitle as Any? ?? NSNull(),
            "travelJournalMarkdown": route.travelJournalMarkdownWithVideoLink as Any? ?? NSNull(),
            "tripVideoURL": route.tripVideoURL as Any? ?? NSNull(),
            "travelJournalGeneratedAt": route.travelJournalGeneratedAt.map { Timestamp(date: $0) } as Any? ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        var payload = data
        if let detailsUpdatedAt = route.detailsUpdatedAt {
            payload["detailsUpdatedAt"] = Timestamp(date: detailsUpdatedAt)
        }

        let document = walkRoutesCollection(for: userID).document(route.id.uuidString)
        // Webで名前・感想を変えた方が新しければ、端末の古い名前・感想で上書きしない。
        if checkRemoteDetails,
           let remote = try? await document.getDocument(),
           let remoteUpdatedAt = (remote.data()?["detailsUpdatedAt"] as? Timestamp)?.dateValue(),
           remoteUpdatedAt > (route.detailsUpdatedAt ?? .distantPast) {
            payload.removeValue(forKey: "title")
            payload.removeValue(forKey: "notes")
            payload.removeValue(forKey: "detailsUpdatedAt")
        }
        try await document.setData(payload, merge: true)
    }

    /// このアカウントのクラウドにある旅・御朱印・投稿写真・物語の文書（IDと中身）。
    /// 端末の記録とクラウドを合わせる（`CloudSync`）のに使う。`changedSince`を渡すと、その時刻より後に
    /// 変わった（`updatedAt`が新しい）文書だけを読む（旅は軌跡の座標を含むので、毎回全件は読まない）。
    func fetchCloudRecords(userID: String, changedSince: Date? = nil) async throws -> CloudRecords {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        func changed(_ collection: CollectionReference) async throws -> QuerySnapshot {
            guard let changedSince else { return try await collection.getDocuments() }
            return try await collection.whereField("updatedAt", isGreaterThan: Timestamp(date: changedSince)).getDocuments()
        }
        async let routes = changed(walkRoutesCollection(for: userID))
        async let stamps = changed(stampsCollection(for: userID))
        async let posts = changed(photoPostsCollection(for: userID))
        async let places = changed(placesCollection(for: userID))
        func records(_ snapshot: QuerySnapshot) -> [String: [String: Any]] {
            Dictionary(snapshot.documents.map { ($0.documentID, $0.data()) }, uniquingKeysWith: { first, _ in first })
        }
        return try await CloudRecords(
            routes: records(routes), stamps: records(stamps), photoPosts: records(posts), places: records(places)
        )
    }

    /// 削除をクラウド側にも反映する。
    func delete(walkRouteID: UUID, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }
        try await walkRoutesCollection(for: userID).document(walkRouteID.uuidString).delete()
    }

    /// 「みんなの時空旅」への公開・非公開を切り替える。公開・非公開は旅の文書（`users/{uid}/walkRoutes/{id}`）の
    /// `isSharedPublicly`だけで決まり、御朱印・投稿写真もその旅の公開状況に従う。公開ページ用の項目（写真の一覧・
    /// 投稿者名・件数）は Cloud Functions（functions/src/sharedTrips.ts）が作る。公開する時は、旅の御朱印・
    /// 投稿写真が写真ごとクラウドにそろっているよう、先に上げておく。
    func setPubliclyShared(
        _ route: WalkRoute,
        isShared: Bool,
        userID: String?,
        stamps: [CollectedStamp] = [],
        photoPosts: [WalkPhotoPost] = [],
        checkpointDetails: [String: String] = [:]
    ) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }
        if isShared {
            await uploadTripContents(stamps: stamps, photoPosts: photoPosts, userID: userID, checkpointDetails: checkpointDetails)
        }
        route.isSharedPublicly = isShared
        try await upload(route, userID: userID)
    }

    /// 旅の御朱印・投稿写真を、写真ごとクラウドに上げる（まだ上がっていない写真があれば先に上げる）。
    /// 御朱印には説明文（旅日記と同じ内容）も添える。公開中の旅なら、Cloud Functions が公開ページに反映する。
    func uploadTripContents(
        stamps: [CollectedStamp],
        photoPosts: [WalkPhotoPost],
        userID: String,
        checkpointDetails: [String: String] = [:]
    ) async {
        for stamp in stamps {
            if stamp.cloudPhotoURL == nil, stamp.photoFileName.map(StampPhotoStore.exists) == true {
                _ = try? await uploadStampPhoto(stamp, userID: userID)
            }
            try? await upload(stamp, userID: userID, detail: checkpointDetails[stamp.siteID])
        }
        for post in photoPosts {
            if post.cloudPhotoURL == nil, StampPhotoStore.exists(post.photoFileName) {
                _ = try? await uploadPhotoPostImage(post, userID: userID)
            } else {
                try? await upload(post, userID: userID)
            }
        }
    }

    /// 巡った御朱印スポットの説明文（既にAIで生成済みの`CheckpointStory`があればその本文、
    /// 無ければ史跡カタログの`summary`）を`siteID`ごとにまとめる。旅日記と同じ内容を
    /// クラウドの御朱印（`users/{uid}/stamps`の`detail`）にも添えるために使う。新しいAI生成は行わない。
    @MainActor
    static func checkpointDetailTexts(for stamps: [CollectedStamp], in context: ModelContext) -> [String: String] {
        guard !stamps.isEmpty else { return [:] }
        let siteIDs = Set(stamps.map(\.siteID))
        let descriptor = FetchDescriptor<CheckpointStory>(
            predicate: #Predicate { siteIDs.contains($0.siteID) }
        )
        let stories = (try? context.fetch(descriptor)) ?? []
        var details = Dictionary(stories.map { ($0.siteID, $0.body) }, uniquingKeysWith: { first, _ in first })
        for siteID in siteIDs where details[siteID] == nil {
            details[siteID] = HistoricSiteCatalog.site(withID: siteID)?.summary
        }
        return details
    }

    // MARK: - いいね・コメント（Webアプリと同じ`sharedTrips/{tripId}/likes`・`/comments`を共有）

    private func likesCollection(tripID: String) -> CollectionReference {
        sharedTripsCollection.document(tripID).collection("likes")
    }

    private func commentsCollection(tripID: String) -> CollectionReference {
        sharedTripsCollection.document(tripID).collection("comments")
    }

    /// この時空旅に「いいね」したユーザーIDの一覧を取得する。
    func fetchLikeUserIDs(tripID: String) async throws -> [String] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let snapshot = try await likesCollection(tripID: tripID).getDocuments()
        return snapshot.documents.map(\.documentID)
    }

    /// 「いいね」の付け外しを行う。ドキュメントIDをuidに固定しているため、1人1いいねが自然に守られる
    /// （Webアプリの`useTripLikes`と同じ方式）。
    func setLiked(tripID: String, userID: String, liked: Bool) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let ref = likesCollection(tripID: tripID).document(userID)
        if liked {
            try await ref.setData(["likedAt": Timestamp(date: Date())])
        } else {
            try await ref.delete()
        }
    }

    /// この時空旅へのコメントを、古い順に取得する。
    func fetchComments(tripID: String) async throws -> [RemoteTripComment] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let snapshot = try await commentsCollection(tripID: tripID)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { document in
            RemoteTripComment(id: document.documentID, data: document.data())
        }
    }

    /// コメントを投稿する。
    func postComment(tripID: String, authorUserID: String, authorDisplayName: String, text: String) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty else { return }
        let data: [String: Any] = [
            "authorUserID": authorUserID,
            "authorDisplayName": authorDisplayName,
            "text": trimmed,
            "createdAt": Timestamp(date: Date()),
        ]
        try await commentsCollection(tripID: tripID).addDocument(data: data)
    }

    /// 自分が投稿したコメントを削除する。
    func deleteComment(tripID: String, commentID: String) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        try await commentsCollection(tripID: tripID).document(commentID).delete()
    }

    /// 一覧表示用に、いいね・コメントの件数だけを軽量に取得する（本文は取得しない）。
    /// Webアプリと同じコレクションを見るため、Webで付けた分もそのまま件数に含まれる。
    func fetchEngagementCounts(tripID: String) async throws -> (likeCount: Int, commentCount: Int) {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        // 件数は Cloud Functions が公開中の旅の文書に書いている（functions/src/sharedTrips.ts）。
        let snapshot = try await Firestore.firestore().collectionGroup("walkRoutes")
            .whereField("tripId", isEqualTo: tripID)
            .whereField("isSharedPublicly", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        let data = snapshot.documents.first?.data()
        return (data?["likeCount"] as? Int ?? 0, data?["commentCount"] as? Int ?? 0)
    }

    // MARK: - ランキング（userPublicStats）

    /// 自分のランキング用公開統計を更新する。「My Trips」でポイントを表示するたびに呼び、
    /// 常に最新の今週/通算ポイントがランキングへ反映されるようにする。
    func updateMyPublicStats(userID: String, displayName: String, weeklyPoints: Int, totalPoints: Int) async {
        guard isFirebaseConfigured else { return }
        let data: [String: Any] = [
            "displayName": displayName,
            "weeklyPoints": weeklyPoints,
            "totalPoints": totalPoints,
            "updatedAt": Timestamp(date: Date()),
        ]
        try? await userPublicStatsCollection.document(userID).setData(data, merge: true)
    }

    /// 今週のポイントが多い順のランキングを取得する。
    func fetchLeaderboard(limit: Int = 50) async throws -> [RemoteUserStats] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let snapshot = try await userPublicStatsCollection
            .order(by: "weeklyPoints", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { RemoteUserStats(id: $0.documentID, data: $0.data()) }
    }

    /// 表示名の前方一致でユーザーを検索する（友達招待の「ユーザー名で追加」用）。
    func searchUsers(displayNamePrefix: String, limit: Int = 20) async throws -> [RemoteUserStats] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard !displayNamePrefix.isEmpty else { return [] }
        let end = displayNamePrefix + "\u{f8ff}"
        let snapshot = try await userPublicStatsCollection
            .order(by: "displayName")
            .start(at: [displayNamePrefix])
            .end(at: [end])
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { RemoteUserStats(id: $0.documentID, data: $0.data()) }
    }

    // MARK: - 友達招待（friendRequests / friendships）

    /// 検索で見つかった相手（uid確定済み）へ友達申請を送る。
    func sendFriendRequest(fromUID: String, fromDisplayName: String, toUID: String) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let data: [String: Any] = [
            "fromUID": fromUID,
            "fromDisplayName": fromDisplayName,
            "toUID": toUID,
            "toEmail": NSNull(),
            "status": "pending",
            "createdAt": Timestamp(date: Date()),
        ]
        try await friendRequestsCollection.addDocument(data: data)
    }

    /// メールアドレス指定で友達申請を送る。相手がまだこのアプリでサインインしたことが
    /// なくても送信でき、後から`claimFriendRequestsAddressedToMe`で受け取られる。
    func sendFriendRequest(fromUID: String, fromDisplayName: String, toEmail: String) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let data: [String: Any] = [
            "fromUID": fromUID,
            "fromDisplayName": fromDisplayName,
            "toUID": NSNull(),
            "toEmail": toEmail.lowercased(),
            "status": "pending",
            "createdAt": Timestamp(date: Date()),
        ]
        try await friendRequestsCollection.addDocument(data: data)
    }

    /// サインイン時に一度呼ぶ。自分の検証済みメールアドレス宛に届いている
    /// （`toUID`がまだ確定していない）招待があれば、自分のuidを書き込んで受け取る。
    func claimFriendRequestsAddressedToMe(userID: String, email: String) async {
        guard isFirebaseConfigured else { return }
        guard let snapshot = try? await friendRequestsCollection
            .whereField("toEmail", isEqualTo: email.lowercased())
            .whereField("toUID", isEqualTo: NSNull())
            .getDocuments() else { return }
        for document in snapshot.documents {
            try? await document.reference.updateData(["toUID": userID])
        }
    }

    /// 自分が送った・受け取った友達申請の一覧を取得する。
    func fetchFriendRequests(userID: String) async throws -> [RemoteFriendRequest] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        async let incomingSnapshot = friendRequestsCollection
            .whereField("toUID", isEqualTo: userID)
            .getDocuments()
        async let outgoingSnapshot = friendRequestsCollection
            .whereField("fromUID", isEqualTo: userID)
            .getDocuments()
        let (incoming, outgoing) = try await (incomingSnapshot, outgoingSnapshot)
        var seen = Set<String>()
        return (incoming.documents + outgoing.documents).compactMap {
            RemoteFriendRequest(id: $0.documentID, data: $0.data())
        }.filter { seen.insert($0.id).inserted }
    }

    /// 届いた友達申請を承認し、友達関係（`friendships`）を作成する。
    func acceptFriendRequest(_ request: RemoteFriendRequest, myUID: String) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        try await friendRequestsCollection.document(request.id).updateData(["status": "accepted"])

        let otherUID = request.fromUID == myUID ? request.toUID : request.fromUID
        guard let otherUID else { return }
        let pairKey = [myUID, otherUID].sorted().joined(separator: "_")
        let data: [String: Any] = [
            "uids": [myUID, otherUID],
            "requestId": request.id,
            "createdAt": Timestamp(date: Date()),
        ]
        try await friendshipsCollection.document(pairKey).setData(data)
    }

    /// 届いた友達申請を却下する。
    func declineFriendRequest(_ request: RemoteFriendRequest) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        try await friendRequestsCollection.document(request.id).updateData(["status": "declined"])
    }

    /// 送った友達申請を取り消す。
    func cancelFriendRequest(_ request: RemoteFriendRequest) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        try await friendRequestsCollection.document(request.id).updateData(["status": "cancelled"])
    }

    /// 自分の友達（uidの配列）を取得する。
    func fetchFriendUIDs(userID: String) async throws -> [String] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        let snapshot = try await friendshipsCollection
            .whereField("uids", arrayContains: userID)
            .getDocuments()
        return snapshot.documents.compactMap { document -> String? in
            guard let uids = document.data()["uids"] as? [String] else { return nil }
            return uids.first { $0 != userID }
        }
    }
}

/// 「みんなの時空旅」の写真1枚分（`sharedTrips/{id}`の`stampPhotos`/`postPhotos`の1要素）。
struct RemoteSharedPhoto: Identifiable {
    var id: String { url }
    let url: String
    let label: String
    let detail: String
}

/// Firestoreの`sharedTrips/{id}`（「みんなの時空旅」に公開された1件）を読み取る軽量DTO。
/// `WalkRoute`のようにSwiftDataへ保存はせず、一覧・詳細の表示にその場で使うだけのもの。
struct RemoteSharedTrip: Identifiable {
    let id: String
    let ownerUserID: String
    let ownerDisplayName: String?
    let title: String?
    let notes: String?
    let startedAt: Date
    let endedAt: Date?
    let stepCount: Int?
    let overlayMapID: String?
    let totalDistanceMeters: Double
    let stampPhotos: [RemoteSharedPhoto]
    let postPhotos: [RemoteSharedPhoto]
    let travelJournalTitle: String?
    let travelJournalMarkdown: String?

    /// 一覧の行に使う、最初に見つかった写真（投稿写真を優先し、無ければ御朱印の写真）。
    var thumbnailURL: URL? {
        (postPhotos.first ?? stampPhotos.first).flatMap { URL(string: $0.url) }
    }

    var overlayMap: HistoricalOverlayMap? {
        OldMapCatalog.resolve(id: overlayMapID)
    }

    init?(id: String, data: [String: Any]) {
        guard let startedAtTimestamp = data["startedAt"] as? Timestamp else { return nil }
        self.id = id
        self.ownerUserID = data["ownerUserID"] as? String ?? ""
        self.ownerDisplayName = data["ownerDisplayName"] as? String
        self.title = data["title"] as? String
        self.notes = data["notes"] as? String
        self.startedAt = startedAtTimestamp.dateValue()
        self.endedAt = (data["endedAt"] as? Timestamp)?.dateValue()
        self.stepCount = data["stepCount"] as? Int
        self.overlayMapID = data["overlayMapID"] as? String
        self.totalDistanceMeters = data["totalDistanceMeters"] as? Double ?? 0
        self.stampPhotos = Self.parsePhotos(data["stampPhotos"], labelKey: "siteName")
        self.postPhotos = Self.parsePhotos(data["postPhotos"], labelKey: "placeName")
        self.travelJournalTitle = data["travelJournalTitle"] as? String
        self.travelJournalMarkdown = data["travelJournalMarkdown"] as? String
        self.likeCount = data["likeCount"] as? Int
        self.commentCount = data["commentCount"] as? Int
        if let lat = (data["latitudes"] as? [Double])?.first, let lon = (data["longitudes"] as? [Double])?.first {
            self.startCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            self.startCoordinate = nil
        }
    }

    /// 歩き始めた地点（リージョンの振り分けに使う）。
    let startCoordinate: CLLocationCoordinate2D?
    /// いいね・コメントの件数（Cloud Functionsが書く）。まだ無い旅は`nil`で、その時は集計クエリで数える。
    let likeCount: Int?
    let commentCount: Int?

    /// この旅のリージョン。使った古地図があればその古地図の、無ければ歩き始めた地点のリージョン。
    var region: MapRegion {
        if let overlayMap { return OldMapCatalog.region(of: overlayMap) }
        if let startCoordinate { return MapRegion(containing: startCoordinate) }
        return .japan
    }

    private static func parsePhotos(_ raw: Any?, labelKey: String) -> [RemoteSharedPhoto] {
        guard let array = raw as? [[String: Any]] else { return [] }
        return array.compactMap { entry in
            guard let url = entry["url"] as? String, !url.isEmpty else { return nil }
            let label = (entry[labelKey] as? String) ?? ""
            let detail = (entry["detail"] as? String) ?? ""
            return RemoteSharedPhoto(url: url, label: label, detail: detail)
        }
    }
}

/// 「みんなの時空旅」への1件のコメント（`sharedTrips/{tripId}/comments/{id}`）。
struct RemoteTripComment: Identifiable {
    let id: String
    let authorUserID: String
    let authorDisplayName: String
    let text: String
    let createdAt: Date

    init?(id: String, data: [String: Any]) {
        guard let authorUserID = data["authorUserID"] as? String,
              let text = data["text"] as? String
        else { return nil }
        self.id = id
        self.authorUserID = authorUserID
        self.authorDisplayName = data["authorDisplayName"] as? String ?? "名無し"
        self.text = text
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}

/// 「みんなの時空旅」ランキング用、`userPublicStats/{uid}`から読み取った軽量DTO。
struct RemoteUserStats: Identifiable {
    /// Firestore文書ID＝uid。
    let id: String
    let displayName: String
    let weeklyPoints: Int
    let totalPoints: Int

    init?(id: String, data: [String: Any]) {
        guard let displayName = data["displayName"] as? String else { return nil }
        self.id = id
        self.displayName = displayName
        self.weeklyPoints = (data["weeklyPoints"] as? Int) ?? 0
        self.totalPoints = (data["totalPoints"] as? Int) ?? 0
    }
}

/// 友達申請1件（`friendRequests/{id}`）。
struct RemoteFriendRequest: Identifiable {
    enum Status: String {
        case pending, accepted, declined, cancelled
    }

    let id: String
    let fromUID: String
    let fromDisplayName: String
    /// 受信側のuid。メールアドレス指定の招待で相手が未サインインの間は`nil`。
    let toUID: String?
    /// メールアドレス指定の招待の宛先（小文字化済み）。ユーザー名指定の招待では`nil`。
    let toEmail: String?
    let status: Status
    let createdAt: Date

    init?(id: String, data: [String: Any]) {
        guard let fromUID = data["fromUID"] as? String,
              let statusRaw = data["status"] as? String,
              let status = Status(rawValue: statusRaw)
        else { return nil }
        self.id = id
        self.fromUID = fromUID
        self.fromDisplayName = (data["fromDisplayName"] as? String) ?? "ユーザー"
        self.toUID = data["toUID"] as? String
        self.toEmail = data["toEmail"] as? String
        self.status = status
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}

/// クラウドの記録（文書ID → 中身）。`SyncService.fetchCloudRecords`の結果。
struct CloudRecords {
    let routes: [String: [String: Any]]
    let stamps: [String: [String: Any]]
    let photoPosts: [String: [String: Any]]
    let places: [String: [String: Any]]
}
