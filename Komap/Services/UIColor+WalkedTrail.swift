import UIKit

extension UIColor {
    /// GPSで歩いた道の周りに広くうっすらとにじませる、ぼかしのような光暈。
    static let walkedTrailGlow = UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 0.12)
    /// GPSで歩いた道の縁取り。濃い色で描き、古地図の上でも通った場所がはっきり分かるようにする。
    static let walkedTrailBorder = UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 0.8)
    /// 縁取りの内側を、下の古地図が透けて見えるよう50%の不透明度で塗る色。
    /// 秘密の地図を少しずつ見せていくような、控えめな見え方にする。
    static let walkedTrailFill = UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 0.5)
}
