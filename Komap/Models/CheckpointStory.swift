import Foundation
import SwiftData

/// 史跡チェックポイント1件分の「昔の出来事」の物語を、一度AIで生成したら
/// 端末に保存しておくためのモデル。
///
/// チェックポイントは全ユーザー共通の固定ポイントのため、同じ場所を何度開いても
/// 毎回AIへ問い合わせるのはAPI利用料・待ち時間の無駄になる。ここに保存しておき、
/// 既にあればそれを表示し、ユーザーが明示的に「更新する」を選んだ時だけ
/// 作り直す。ユーザー自身が内容を編集した場合は`isManuallyEdited`を立てておき、
/// 上書きされたことが分かるようにする。
@Model
final class CheckpointStory {
    /// `HistoricSite.id`と対応する（1史跡につき1件）。
    @Attribute(.unique) var siteID: String
    var title: String
    var body: String
    var updatedAt: Date
    /// ユーザーが手動で編集したかどうか（AIによる自動生成のままではないことを示す）。
    var isManuallyEdited: Bool

    init(
        siteID: String,
        title: String,
        body: String,
        updatedAt: Date = Date(),
        isManuallyEdited: Bool = false
    ) {
        self.siteID = siteID
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
        self.isManuallyEdited = isManuallyEdited
    }
}
