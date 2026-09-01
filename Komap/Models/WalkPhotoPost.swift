import CoreLocation
import Foundation
import SwiftData
import UIKit

/// ウォーキング記録中に、史跡チェックポイントとは関係なく自由なタイミングで
/// 投稿した写真。投稿するたびに固定ポイントを獲得する。
///
/// 御朱印の写真と同様、画像本体は`StampPhotoStore`にJPEGとして保存し、
/// ここにはファイル名のみを持つ。
@Model
final class WalkPhotoPost {
    @Attribute(.unique) var id: UUID
    var photoFileName: String
    var postedAt: Date
    var points: Int
    var latitude: Double
    var longitude: Double
    /// 投稿時に記録中だった `WalkRoute.id`。
    var walkRouteID: UUID?
    /// 逆ジオコーディングで取得した場所の名称。一度取得したら保存し、再取得しない。
    var placeName: String?
    /// AIが生成したその場所の物語（見出し）。一度取得したら保存し、再取得しない。
    var storyTitle: String?
    /// AIが生成したその場所の物語（本文）。一度取得したら保存し、再取得しない。
    var storyBody: String?
    /// Firebase Storageへアップロード済みの画像URL。未アップロードなら`nil`。
    var cloudPhotoURL: String?

    /// 1回の投稿で獲得できるポイント。
    static let pointsPerPost = 10

    init(
        id: UUID = UUID(),
        photoFileName: String,
        postedAt: Date = Date(),
        points: Int = WalkPhotoPost.pointsPerPost,
        coordinate: CLLocationCoordinate2D,
        walkRouteID: UUID? = nil
    ) {
        self.id = id
        self.photoFileName = photoFileName
        self.postedAt = postedAt
        self.points = points
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.walkRouteID = walkRouteID
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var photo: UIImage? {
        StampPhotoStore.load(photoFileName)
    }
}
