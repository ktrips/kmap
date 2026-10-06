import CoreLocation
import FirebaseCore
import FirebaseFirestore
import Foundation

/// 管理者が同梱の古地図に加えたチェックポイントの変更（追加・非表示）を、クラウド（Firestore の
/// `adminCheckpoints/{チェックポイントID}`）経由で全員の端末・Webに配る。
///
/// - 追加したもの: `overlayMapID`・`name`・`summary`・`lat`・`lng`
/// - 非表示にした同梱のもの: `overlayMapID`・`hidden: true`（文書のIDは同梱のチェックポイントのID）
///
/// 読み取りは誰でも、書き込みは管理者だけ（firestore.rules）。端末では最後に読んだ内容を JSON に保存し、
/// オフラインでも、起動直後のクラウドを読む前でも表示できるようにする。
enum AdminCheckpointCloud {
    struct Entry: Codable, Equatable {
        let id: String
        let overlayMapID: String
        var name: String
        var summary: String
        var latitude: Double
        var longitude: Double
        var hidden: Bool
    }

    /// クラウドの内容が変わった時に送る通知（地図のチェックポイントを作り直すため）。
    static let didChange = Notification.Name("AdminCheckpointCloud.didChange")

    private static let collectionName = "adminCheckpoints"

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AdminCheckpoints.json")
    }

    private static var cached: [String: Entry]?

    private static func entries() -> [String: Entry] {
        if let cached { return cached }
        let list = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
        let map = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        cached = map
        return map
    }

    private static func store(_ map: [String: Entry]) {
        guard map != entries() else { return }
        cached = map
        if let data = try? JSONEncoder().encode(Array(map.values)) {
            try? data.write(to: fileURL)
        }
        OldMapCatalog.invalidateAllIncludingCustomCache()
        HistoricSiteCatalog.invalidateCache()
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    private static var collection: CollectionReference? {
        FirebaseApp.app() == nil ? nil : Firestore.firestore().collection(collectionName)
    }

    // MARK: - 反映

    /// 管理者が追加したチェックポイント（全古地図分）。
    static func extraSites() -> [HistoricSite] {
        entries().values.filter { !$0.hidden }.sorted { $0.id < $1.id }.map {
            HistoricSite(
                id: $0.id, overlayMapID: $0.overlayMapID, name: $0.name, summary: $0.summary,
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            )
        }
    }

    /// 管理者が非表示にした同梱のチェックポイントのID。
    static func hiddenSiteIDs() -> Set<String> {
        Set(entries().values.filter(\.hidden).map(\.id))
    }

    /// この古地図に、クラウドでの変更があるか。
    static func hasChanges(overlayID: String) -> Bool {
        entries().values.contains { $0.overlayMapID == overlayID }
    }

    // MARK: - 読み込み

    /// クラウドの最新の内容を読み直す（起動時・アプリに戻った時）。数十件程度の小さな一覧なので毎回全件を読む。
    static func refresh() async {
        guard let collection else { return }
        do {
            let snapshot = try await collection.getDocuments()
            var map: [String: Entry] = [:]
            for document in snapshot.documents {
                let data = document.data()
                guard let overlayMapID = data["overlayMapID"] as? String else { continue }
                let hidden = data["hidden"] as? Bool ?? false
                let latitude = data["lat"] as? Double
                let longitude = data["lng"] as? Double
                if !hidden, latitude == nil || longitude == nil { continue }
                map[document.documentID] = Entry(
                    id: document.documentID, overlayMapID: overlayMapID,
                    name: data["name"] as? String ?? "", summary: data["summary"] as? String ?? "",
                    latitude: latitude ?? 0, longitude: longitude ?? 0, hidden: hidden
                )
            }
            store(map)
        } catch {
            // 読めない時は前回の内容のまま表示を続ける。
        }
    }

    // MARK: - 管理者による編集

    /// 同梱の古地図にチェックポイントを追加する。端末の表示はすぐ変え、クラウドへは裏で書き込む
    /// （オフラインでも Firestore が後で送る）。
    static func add(toOverlayID overlayID: String, name: String, summary: String, coordinate: CLLocationCoordinate2D) {
        let entry = Entry(
            id: "\(overlayID)-x-\(UUID().uuidString)", overlayMapID: overlayID, name: name, summary: summary,
            latitude: coordinate.latitude, longitude: coordinate.longitude, hidden: false
        )
        var map = entries()
        map[entry.id] = entry
        store(map)
        write(entry)
    }

    /// チェックポイントを削除する。管理者が追加したものは取り除き、同梱のものは全員の画面で非表示にする。
    static func remove(siteID: String, overlayID: String) {
        var map = entries()
        if let existing = map[siteID], !existing.hidden {
            map[siteID] = nil
            store(map)
            collection?.document(siteID).delete()
        } else {
            let entry = Entry(
                id: siteID, overlayMapID: overlayID, name: "", summary: "", latitude: 0, longitude: 0, hidden: true
            )
            map[siteID] = entry
            store(map)
            write(entry)
        }
    }

    /// この古地図へのクラウドでの変更をすべて取り消す（同梱の元のチェックポイントに戻す）。
    static func reset(overlayID: String) {
        var map = entries()
        let ids = map.values.filter { $0.overlayMapID == overlayID }.map(\.id)
        guard !ids.isEmpty else { return }
        for id in ids {
            map[id] = nil
            collection?.document(id).delete()
        }
        store(map)
    }

    /// 以前は管理者の端末の中だけに保存していた追加・非表示（`OverlayOverrideStore`）をクラウドに移す。
    /// 管理者でサインインした時に呼ぶ。移した分は端末の保存から消す。
    static func migrateLocalOverrides() {
        guard collection != nil else { return }
        let local = OverlayOverrideStore.takeCheckpointChanges()
        guard !local.extras.isEmpty || !local.hidden.isEmpty else { return }
        var map = entries()
        for site in local.extras {
            let entry = Entry(
                id: site.id, overlayMapID: site.overlayMapID, name: site.name, summary: site.summary,
                latitude: site.coordinate.latitude, longitude: site.coordinate.longitude, hidden: false
            )
            map[entry.id] = entry
            write(entry)
        }
        for (siteID, overlayID) in local.hidden {
            let entry = Entry(id: siteID, overlayMapID: overlayID, name: "", summary: "", latitude: 0, longitude: 0, hidden: true)
            map[siteID] = entry
            write(entry)
        }
        store(map)
    }

    private static func write(_ entry: Entry) {
        var data: [String: Any] = [
            "overlayMapID": entry.overlayMapID,
            "hidden": entry.hidden,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if !entry.hidden {
            data["name"] = entry.name
            data["summary"] = entry.summary
            data["lat"] = entry.latitude
            data["lng"] = entry.longitude
        }
        collection?.document(entry.id).setData(data)
    }
}
