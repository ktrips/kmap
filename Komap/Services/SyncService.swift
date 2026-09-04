import FirebaseCore
import FirebaseFirestore
import Foundation
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

    private func stampPhotoStoragePath(userID: String, stampID: UUID) -> String {
        "users/\(userID)/stamps/\(stampID.uuidString).jpg"
    }

    private func photoPostStoragePath(userID: String, postID: UUID) -> String {
        "users/\(userID)/photoPosts/\(postID.uuidString).jpg"
    }

    private func sharedPhotoStoragePath(tripID: UUID, photoID: UUID) -> String {
        "sharedPhotos/\(tripID.uuidString)/\(photoID.uuidString).jpg"
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
        ]

        try await placesCollection(for: userID)
            .document(place.id.uuidString)
            .setData(data, merge: true)
    }

    /// サインイン後などに、クラウド側の一覧を取得する（ローカルへの反映は呼び出し側で行う）。
    func fetchAll(userID: String) async throws -> [RemotePlace] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }

        let snapshot = try await placesCollection(for: userID)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            RemotePlace(id: document.documentID, data: document.data())
        }
    }

    /// 削除をクラウド側にも反映する。
    func delete(placeID: UUID, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }
        try await placesCollection(for: userID).document(placeID.uuidString).delete()
    }

    /// 獲得した御朱印（`CollectedStamp`）を `users/{uid}/stamps/{id}` へアップロードする。
    func upload(_ stamp: CollectedStamp, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }

        let data: [String: Any] = [
            "siteID": stamp.siteID,
            "collectedAt": Timestamp(date: stamp.collectedAt),
            "photoURL": stamp.cloudPhotoURL as Any? ?? NSNull(),
            "walkRouteID": stamp.walkRouteID?.uuidString as Any? ?? NSNull(),
        ]

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

    /// サインイン後などに、クラウド側の御朱印一覧を取得する（ローカルへの反映は呼び出し側で行う）。
    func fetchAllStamps(userID: String) async throws -> [RemoteStamp] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }

        let snapshot = try await stampsCollection(for: userID)
            .order(by: "collectedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            RemoteStamp(id: document.documentID, data: document.data())
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

    /// 保存した時間旅（`WalkRoute`）を `users/{uid}/walkRoutes/{id}` へアップロードする。
    /// Webアプリの「My Trips」で、同じGoogleアカウントの記録を見られるようにするために使う。
    func upload(_ route: WalkRoute, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }

        let data: [String: Any] = [
            "title": route.title as Any? ?? NSNull(),
            "latitudes": route.latitudes,
            "longitudes": route.longitudes,
            "startedAt": Timestamp(date: route.startedAt),
            "endedAt": route.endedAt.map { Timestamp(date: $0) } as Any? ?? NSNull(),
            "stepCount": route.stepCount as Any? ?? NSNull(),
            "overlayMapID": route.overlayMapID as Any? ?? NSNull(),
            "totalDistanceMeters": route.totalDistanceMeters,
            "isSharedPublicly": route.isSharedPublicly,
        ]

        try await walkRoutesCollection(for: userID)
            .document(route.id.uuidString)
            .setData(data, merge: true)
    }

    /// 削除をクラウド側にも反映する。
    func delete(walkRouteID: UUID, userID: String?) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }
        try await walkRoutesCollection(for: userID).document(walkRouteID.uuidString).delete()
    }

    /// 「みんなの時空旅」への公開・非公開を切り替える。公開する場合は`sharedTrips/{id}`に
    /// コピーを置き（自分の御朱印・投稿写真は`sharedPhotos/{tripId}/**`へ画像もコピーする）、
    /// 非公開にする場合はそのドキュメントを削除する。
    func setPubliclyShared(
        _ route: WalkRoute,
        isShared: Bool,
        userID: String?,
        ownerDisplayName: String?,
        stamps: [CollectedStamp] = [],
        photoPosts: [WalkPhotoPost] = []
    ) async throws {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }
        guard let userID else { throw SyncError.notSignedIn }

        if isShared {
            // 御朱印（史跡チェックポイント）の写真と、自由投稿の写真は、Web側でも
            // 分けて表示できるよう、それぞれ紐づく史跡名・地点名を添えて公開する。
            var stampPhotos: [[String: Any]] = []
            for stamp in stamps where stamp.photo != nil {
                let sourcePath = stampPhotoStoragePath(userID: userID, stampID: stamp.id)
                let destPath = sharedPhotoStoragePath(tripID: route.id, photoID: stamp.id)
                if let url = try? await photoStorage.copyToShared(from: sourcePath, to: destPath) {
                    let siteName = HistoricSiteCatalog.site(withID: stamp.siteID)?.name ?? "御朱印"
                    stampPhotos.append(["url": url.absoluteString, "siteName": siteName])
                }
            }
            var postPhotos: [[String: Any]] = []
            for post in photoPosts where post.photo != nil {
                let sourcePath = photoPostStoragePath(userID: userID, postID: post.id)
                let destPath = sharedPhotoStoragePath(tripID: route.id, photoID: post.id)
                if let url = try? await photoStorage.copyToShared(from: sourcePath, to: destPath) {
                    postPhotos.append(["url": url.absoluteString, "placeName": post.placeName ?? ""])
                }
            }

            // プライバシーのため、公開する名前はGoogleの表示名の先頭6文字だけにする。
            let truncatedOwnerDisplayName = ownerDisplayName.map { String($0.prefix(6)) }

            let data: [String: Any] = [
                "ownerUserID": userID,
                "ownerDisplayName": truncatedOwnerDisplayName as Any? ?? NSNull(),
                "title": route.title as Any? ?? NSNull(),
                "latitudes": route.latitudes,
                "longitudes": route.longitudes,
                "startedAt": Timestamp(date: route.startedAt),
                "endedAt": route.endedAt.map { Timestamp(date: $0) } as Any? ?? NSNull(),
                "stepCount": route.stepCount as Any? ?? NSNull(),
                "overlayMapID": route.overlayMapID as Any? ?? NSNull(),
                "totalDistanceMeters": route.totalDistanceMeters,
                "stampPhotos": stampPhotos,
                "postPhotos": postPhotos,
            ]
            try await sharedTripsCollection.document(route.id.uuidString).setData(data, merge: true)
        } else {
            try await sharedTripsCollection.document(route.id.uuidString).delete()
        }
    }

    /// 「みんなの時空旅」に公開されている、全ユーザー分の時空旅を取得する。
    func fetchAllSharedTrips() async throws -> [RemoteSharedTrip] {
        guard isFirebaseConfigured else { throw SyncError.firebaseNotConfigured }

        let snapshot = try await sharedTripsCollection
            .order(by: "startedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            RemoteSharedTrip(id: document.documentID, data: document.data())
        }
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
        async let likeAggregate = likesCollection(tripID: tripID).count.getAggregation(source: .server)
        async let commentAggregate = commentsCollection(tripID: tripID).count.getAggregation(source: .server)
        let (likes, comments) = try await (likeAggregate, commentAggregate)
        return (likes.count.intValue, comments.count.intValue)
    }
}

/// Firestoreから読み取った1件分のデータ（`SavedPlace` への変換用の軽量DTO）。
struct RemotePlace {
    let id: String
    let title: String
    let latitude: Double
    let longitude: Double
    let overlayMapID: String?
    let era: String
    let storyText: String
    let createdAt: Date

    init?(id: String, data: [String: Any]) {
        guard let title = data["title"] as? String,
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let era = data["era"] as? String,
              let storyText = data["storyText"] as? String
        else { return nil }

        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.overlayMapID = data["overlayMapID"] as? String
        self.era = era
        self.storyText = storyText
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}

/// Firestoreから読み取った御朱印1件分のデータ（`CollectedStamp` への変換用の軽量DTO）。
struct RemoteStamp {
    let id: String
    let siteID: String
    let collectedAt: Date
    let photoURL: String?

    init?(id: String, data: [String: Any]) {
        guard let siteID = data["siteID"] as? String else { return nil }
        self.id = id
        self.siteID = siteID
        self.collectedAt = (data["collectedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.photoURL = data["photoURL"] as? String
    }
}

/// 「みんなの時空旅」の御朱印・投稿写真1枚分（URLと、史跡名／地点名のラベル）。
struct RemoteSharedPhoto {
    let url: String
    let label: String
}

/// 「みんなの時空旅」（`sharedTrips/{id}`）から読み取った、他ユーザーを含む時空旅1件分のデータ。
struct RemoteSharedTrip: Identifiable, Hashable {
    static func == (lhs: RemoteSharedTrip, rhs: RemoteSharedTrip) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let ownerUserID: String
    let ownerDisplayName: String?
    let title: String?
    let latitudes: [Double]
    let longitudes: [Double]
    let startedAt: Date
    let endedAt: Date?
    let stepCount: Int?
    let overlayMapID: String?
    let totalDistanceMeters: Double
    let stampPhotos: [RemoteSharedPhoto]
    let postPhotos: [RemoteSharedPhoto]

    init?(id: String, data: [String: Any]) {
        guard let ownerUserID = data["ownerUserID"] as? String else { return nil }
        self.id = id
        self.ownerUserID = ownerUserID
        self.ownerDisplayName = data["ownerDisplayName"] as? String
        self.title = data["title"] as? String
        self.latitudes = data["latitudes"] as? [Double] ?? []
        self.longitudes = data["longitudes"] as? [Double] ?? []
        self.startedAt = (data["startedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.endedAt = (data["endedAt"] as? Timestamp)?.dateValue()
        self.stepCount = data["stepCount"] as? Int
        self.overlayMapID = data["overlayMapID"] as? String
        self.totalDistanceMeters = data["totalDistanceMeters"] as? Double ?? 0
        self.stampPhotos = (data["stampPhotos"] as? [[String: Any]] ?? []).compactMap { dict in
            guard let url = dict["url"] as? String else { return nil }
            return RemoteSharedPhoto(url: url, label: dict["siteName"] as? String ?? "")
        }
        self.postPhotos = (data["postPhotos"] as? [[String: Any]] ?? []).compactMap { dict in
            guard let url = dict["url"] as? String else { return nil }
            return RemoteSharedPhoto(url: url, label: dict["placeName"] as? String ?? "")
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
