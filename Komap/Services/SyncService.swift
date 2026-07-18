import FirebaseCore
import FirebaseFirestore
import Foundation

/// 保存した地点（`SavedPlace`）を、Firestore上の
/// `users/{uid}/places/{id}` コレクションへアップロード／取得する。
///
/// この同じコレクションをWebアプリ（map.ktrips.net）側からも読み込むことで、
/// 同じApple IDでサインインしたユーザーが、iOSで保存した「自分のマップ」を
/// Web上でも見られるようにしている。
struct SyncService {
    enum SyncError: LocalizedError {
        case notSignedIn
        case firebaseNotConfigured

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Webでも見られるようにするには、設定タブでAppleサインインしてください。"
            case .firebaseNotConfigured:
                return "Firebaseが設定されていないため、クラウド同期は利用できません。"
            }
        }
    }

    private var isFirebaseConfigured: Bool { FirebaseApp.app() != nil }

    private func placesCollection(for userID: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userID).collection("places")
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
