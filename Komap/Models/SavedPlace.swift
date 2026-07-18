import CoreLocation
import Foundation
import SwiftData

/// ユーザーが「自分のマップ」として保存した地点。
///
/// 位置・その地点に紐づく古地図の時代・AIが生成した物語を保持する。
/// これらの積み重ねがユーザー自身の「時間旅行の記録」になる。
@Model
final class SavedPlace {
    @Attribute(.unique) var id: UUID
    /// 地点のタイトル（AIが生成した見出し、またはユーザーが編集したもの）
    var title: String
    var latitude: Double
    var longitude: Double
    /// この地点を訪れた時に選んでいた古地図のID（HistoricalOverlayMap.id）。未選択なら nil。
    var overlayMapID: String?
    /// AIプロンプトに使った時代表現（表示用にもそのまま使う）
    var era: String
    /// AIが生成した物語本文
    var storyText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        latitude: Double,
        longitude: Double,
        overlayMapID: String?,
        era: String,
        storyText: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.overlayMapID = overlayMapID
        self.era = era
        self.storyText = storyText
        self.createdAt = createdAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
