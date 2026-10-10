import Foundation
import SwiftData

/// 個人の古地図を同梱の古地図に置き換えた時など、カタログで廃止したID（`mergedIntoID`）を
/// 端末の記録から置き換え先のIDへ付け替える。何度呼んでもよい（付け替える物が無ければ何もしない）。
///
/// - 旅の古地図（`WalkRoute.overlayMapID`）・御朱印のチェックポイント（`CollectedStamp.siteID`）・
///   チェックポイントの説明（`CheckpointStory.siteID`）を付け替え、サインイン中ならクラウドにも上げ直す
///   （公開中の旅なら、Cloud Functions が公開ページの御朱印の一覧も作り直す）。
/// - 置き換えた個人の古地図（`CustomOverlayMapStore`）は、ポイントと画像ごと端末から消す。
@MainActor
enum CatalogMigration {
    static func migrateReplacedIDs(context: ModelContext, userID: String?, syncService: SyncService) async {
        let mapIDs = OldMapCatalog.mergedIntoID
        let siteIDs = HistoricSiteCatalog.mergedIntoID

        for overlay in CustomOverlayMapStore.all() where mapIDs[overlay.id] != nil {
            CustomOverlayMapStore.deleteOverlay(id: overlay.id)
        }

        let routes = ((try? context.fetch(FetchDescriptor<WalkRoute>())) ?? []).filter { route in
            route.overlayMapID.map { mapIDs[$0] != nil } ?? false
        }
        for route in routes {
            route.overlayMapID = route.overlayMapID.flatMap { mapIDs[$0] }
        }

        let stamps = ((try? context.fetch(FetchDescriptor<CollectedStamp>())) ?? []).filter { siteIDs[$0.siteID] != nil }
        for stamp in stamps {
            stamp.siteID = siteIDs[stamp.siteID] ?? stamp.siteID
        }

        let stories = (try? context.fetch(FetchDescriptor<CheckpointStory>())) ?? []
        let storySiteIDs = Set(stories.map(\.siteID))
        var changedStories = false
        for story in stories {
            guard let newID = siteIDs[story.siteID] else { continue }
            changedStories = true
            // 置き換え先の説明が既にあればそちらを残す（`siteID`は重複できない）。
            if storySiteIDs.contains(newID) {
                context.delete(story)
            } else {
                story.siteID = newID
            }
        }

        guard !routes.isEmpty || !stamps.isEmpty || changedStories else { return }
        try? context.save()

        guard let userID else { return }
        for stamp in stamps {
            try? await syncService.upload(stamp, userID: userID)
        }
        for route in routes {
            try? await syncService.upload(route, userID: userID)
        }
    }
}
