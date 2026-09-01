import FirebaseCore
import FirebaseFirestore
import Foundation

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

    private var isFirebaseConfigured: Bool { FirebaseApp.app() != nil }

    private func placesCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("places")
    }

    private func stampsCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("stamps")
    }

    private func walkRoutesCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("walkRoutes")
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
        ]

        try await stampsCollection(for: userID)
            .document(stamp.id.uuidString)
            .setData(data, merge: true)
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

    init?(id: String, data: [String: Any]) {
        guard let siteID = data["siteID"] as? String else { return nil }
        self.id = id
        self.siteID = siteID
        self.collectedAt = (data["collectedAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}
