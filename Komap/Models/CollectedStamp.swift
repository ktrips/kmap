import Foundation
import SwiftData
import UIKit

/// 「スタート」でのウォーキング記録中に史跡チェックポイントへ接近して獲得した御朱印。
///
/// `siteID` は `HistoricSite.id`（`HistoricSiteCatalog`）を指す。
/// チェックイン時に添えた写真は `StampPhotoStore` に圧縮保存し、ここには
/// ファイル名のみを持つ（データベースに画像本体を持たせて肥大化させないため）。
@Model
final class CollectedStamp {
    @Attribute(.unique) var id: UUID
    var siteID: String
    var collectedAt: Date
    var photoFileName: String?
    /// 獲得時に記録中だった `WalkRoute.id`。どの徒歩セッションで獲得したかを辿るために使う。
    var walkRouteID: UUID?

    init(
        id: UUID = UUID(),
        siteID: String,
        collectedAt: Date = Date(),
        photoFileName: String? = nil,
        walkRouteID: UUID? = nil
    ) {
        self.id = id
        self.siteID = siteID
        self.collectedAt = collectedAt
        self.photoFileName = photoFileName
        self.walkRouteID = walkRouteID
    }

    var site: HistoricSite? {
        HistoricSiteCatalog.site(withID: siteID)
    }

    var photo: UIImage? {
        photoFileName.flatMap(StampPhotoStore.load)
    }

    /// 写真を差し替える。古いファイルは削除してから新しいものを保存する。
    func updatePhoto(_ image: UIImage?) {
        if let photoFileName {
            StampPhotoStore.delete(photoFileName)
        }
        photoFileName = image.flatMap(StampPhotoStore.save)
    }
}
