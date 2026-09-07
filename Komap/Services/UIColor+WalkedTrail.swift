import UIKit

extension UIColor {
    /// GPSで歩いた道の縁取り。濃い色で細く描き、古地図の上でも通った場所がはっきり分かるようにする。
    static let walkedTrailBorder = UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 0.85)
    /// 縁取りの内側を塗る、明るく薄い色。縁取りの上から少し狭い幅で重ねることで、
    /// 中央だけ薄い色になり「縁は濃く・中は薄く」という見た目になる。
    static let walkedTrailFill = UIColor(red: 0.95, green: 0.87, blue: 0.72, alpha: 0.5)

    /// 記録中（歩いている最中）に、過去の（保存済みの）軌跡を薄く見せるための色。
    /// 今まさに歩いている軌跡（`walkedTrailBorder`/`walkedTrailFill`のまま）が
    /// 目立つよう、過去の軌跡だけ透明度を大きく下げる。
    static let walkedTrailBorderFaded = UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 0.16)
    static let walkedTrailFillFaded = UIColor(red: 0.95, green: 0.87, blue: 0.72, alpha: 0.09)

    /// 今まさに記録中の軌跡だけに使う、ひときわ濃く鮮やかな朱色。保存済みルートと
    /// 同じ色だと「今歩き進めている」実感が薄いため、記録中のライブ軌跡だけは
    /// これで塗り、古地図の上でもくっきり目立つようにする。
    static let liveWalkedTrailBorder = UIColor(red: 0.85, green: 0.16, blue: 0.02, alpha: 1.0)
    static let liveWalkedTrailFill = UIColor(red: 1.0, green: 0.62, blue: 0.18, alpha: 0.9)
}
