import CoreLocation
import FirebaseCore
import FirebaseFirestore
import Foundation
import UIKit

/// クラウドで公開されている、誰かが作った古地図1件分（`sharedOverlayMaps/{id}`）。
struct RemoteOverlayMap: Identifiable {
    let id: String
    let ownerUserID: String
    let ownerDisplayName: String?
    let title: String
    let era: String
    let summary: String
    let southWest: CLLocationCoordinate2D
    let northEast: CLLocationCoordinate2D
    let imageURL: URL
    let checkpoints: [GeneratedCheckpoint]
    let updatedAt: Date?

    init?(id: String, data: [String: Any]) {
        guard let ownerUserID = data["ownerUserID"] as? String,
              let title = data["title"] as? String,
              let south = data["southWestLat"] as? Double, let west = data["southWestLng"] as? Double,
              let north = data["northEastLat"] as? Double, let east = data["northEastLng"] as? Double,
              let urlString = data["imageURL"] as? String, let imageURL = URL(string: urlString)
        else { return nil }
        self.id = id
        self.ownerUserID = ownerUserID
        self.ownerDisplayName = data["ownerDisplayName"] as? String
        self.title = title
        self.era = data["era"] as? String ?? ""
        self.summary = data["summary"] as? String ?? ""
        self.southWest = CLLocationCoordinate2D(latitude: south, longitude: west)
        self.northEast = CLLocationCoordinate2D(latitude: north, longitude: east)
        self.imageURL = imageURL
        self.checkpoints = (data["checkpoints"] as? [[String: Any]] ?? []).compactMap { item in
            guard let name = item["name"] as? String,
                  let lat = item["lat"] as? Double, let lng = item["lng"] as? Double
            else { return nil }
            return GeneratedCheckpoint(
                name: name,
                summary: item["summary"] as? String ?? "",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
            )
        }
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }
}

/// 追加した古地図を、全ユーザー共通の`sharedOverlayMaps`へ公開・取り下げしたり、
/// 公開されている古地図を一覧・取り込みしたりする。
///
/// 画像はStorageの`sharedOverlayMaps/{ownerUID}/{mapID}.jpg`（読み取りは誰でも可、
/// 書き込みは本人のみ）、それ以外の情報はFirestoreの`sharedOverlayMaps/{mapID}`に置く。
struct OverlayMapShareService {
    enum ShareError: LocalizedError {
        case notSignedIn
        case firebaseNotConfigured
        case imageUnavailable
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "古地図を公開・取り込みするには、設定タブでGoogleサインインしてください。"
            case .firebaseNotConfigured: return "Firebaseが設定されていないため、クラウドの機能は利用できません。"
            case .imageUnavailable: return "この古地図の画像を読み込めませんでした。"
            case .downloadFailed: return "古地図の画像をダウンロードできませんでした。"
            }
        }
    }

    private let photoStorage = PhotoStorageService()

    private var collection: CollectionReference {
        Firestore.firestore().collection("sharedOverlayMaps")
    }

    private func imagePath(userID: String, mapID: String) -> String {
        "sharedOverlayMaps/\(userID)/\(mapID).jpg"
    }

    private func requireFirebase() throws {
        guard FirebaseApp.app() != nil else { throw ShareError.firebaseNotConfigured }
    }

    /// 端末に保存している古地図（画像・範囲・ポイント）を公開する。既に公開済みなら内容を更新する。
    func publish(mapID: String, userID: String?, ownerDisplayName: String?) async throws {
        try requireFirebase()
        guard let userID else { throw ShareError.notSignedIn }
        guard let overlay = CustomOverlayMapStore.all().first(where: { $0.id == mapID }),
              let image = overlay.image
        else { throw ShareError.imageUnavailable }

        let url = try await photoStorage.upload(image, path: imagePath(userID: userID, mapID: mapID))
        let checkpoints = HistoricSiteCatalog.sites(forOverlayID: mapID).map { site -> [String: Any] in
            ["name": site.name, "summary": site.summary, "lat": site.coordinate.latitude, "lng": site.coordinate.longitude]
        }
        let data: [String: Any] = [
            "ownerUserID": userID,
            // プライバシーのため、公開する名前は表示名の先頭6文字だけにする（みんなの時空旅と同じ）。
            "ownerDisplayName": ownerDisplayName.map { String($0.prefix(6)) } as Any? ?? NSNull(),
            "title": overlay.title,
            "era": overlay.era,
            "summary": overlay.summary,
            "southWestLat": overlay.southWest.latitude,
            "southWestLng": overlay.southWest.longitude,
            "northEastLat": overlay.northEast.latitude,
            "northEastLng": overlay.northEast.longitude,
            "imageURL": url.absoluteString,
            "checkpoints": checkpoints,
            "updatedAt": Timestamp(date: Date()),
        ]
        try await collection.document(mapID).setData(data)
    }

    /// 公開を取り下げる（Firestoreの文書とStorageの画像の両方を削除する）。
    func unpublish(mapID: String, userID: String?) async {
        guard FirebaseApp.app() != nil, let userID else { return }
        try? await collection.document(mapID).delete()
        await photoStorage.delete(path: imagePath(userID: userID, mapID: mapID))
    }

    /// 公開されている古地図を、更新が新しい順に取得する。
    func fetchPublicMaps(limit: Int = 60) async throws -> [RemoteOverlayMap] {
        try requireFirebase()
        let snapshot = try await collection
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { RemoteOverlayMap(id: $0.documentID, data: $0.data()) }
    }

    /// 公開されている古地図を、画像・ポイントごと自分の端末に取り込む（自分だけの新しい古地図になる）。
    func importMap(_ remote: RemoteOverlayMap) async throws -> HistoricalOverlayMap? {
        let (data, response) = try await URLSession.shared.data(from: remote.imageURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data) else {
            throw ShareError.downloadFailed
        }
        return CustomOverlayMapStore.add(
            title: remote.title,
            era: remote.era,
            summary: remote.summary,
            image: image,
            southWest: remote.southWest,
            northEast: remote.northEast,
            checkpoints: remote.checkpoints
        )
    }
}
