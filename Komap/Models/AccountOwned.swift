import Foundation

/// 保存したアカウント（`ownerUserID`）を持つ記録。旅・御朱印・投稿写真。
/// 一覧や集計には、今サインインしているアカウントのものだけを出す
/// （サインインしていない間は、サインインせずに保存したもの＝`ownerUserID`が`nil`のものだけ）。
protocol AccountOwned {
    var ownerUserID: String? { get }
}

extension WalkRoute: AccountOwned {}
extension CollectedStamp: AccountOwned {}
extension WalkPhotoPost: AccountOwned {}

extension Array where Element: AccountOwned {
    /// `userID`のアカウントで保存したものだけ（`userID`が`nil`なら、サインインせずに保存したものだけ）。
    func owned(by userID: String?) -> [Element] {
        filter { $0.ownerUserID == userID }
    }
}
