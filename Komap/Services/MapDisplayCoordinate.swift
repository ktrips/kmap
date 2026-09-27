import CoreLocation
import Foundation

/// 地図に描く時だけ使う座標の変換（中国本土の GCJ-02）。
///
/// 中国本土では、Google マップの道路・地名の地図が独自の座標系（GCJ-02）でずらして描かれている。
/// 一方、GPS（CoreLocation）の現在地・古地図・チェックポイントの座標は世界測地系（WGS84）のため、
/// そのまま描くと背景の道路と数百mずれて見える。地図に置く直前にこの変換を通して背景に合わせる。
///
/// - Important: データ（御朱印の判定・保存する軌跡・距離の計算）は WGS84 のまま扱い、
///   変換するのは地図に描く時だけにする。地図をタップした位置・表示範囲など、地図から受け取る座標は
///   `fromDisplay`で WGS84 に戻す。中国本土の外（香港・マカオ・台湾・日本・韓国・インドなど）では何もしない。
enum MapDisplayCoordinate {
    static func toDisplay(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard isInMainlandChina(coordinate) else { return coordinate }
        let offset = gcjOffset(coordinate)
        return CLLocationCoordinate2D(latitude: coordinate.latitude + offset.lat, longitude: coordinate.longitude + offset.lon)
    }

    /// 地図上の座標（GCJ-02 の場合がある）を WGS84 に戻す（繰り返し計算で逆変換する）。
    static func fromDisplay(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard isInMainlandChina(coordinate) else { return coordinate }
        var guess = coordinate
        for _ in 0..<4 {
            let shifted = toDisplay(guess)
            guess = CLLocationCoordinate2D(
                latitude: guess.latitude - (shifted.latitude - coordinate.latitude),
                longitude: guess.longitude - (shifted.longitude - coordinate.longitude)
            )
        }
        return guess
    }

    /// 中国本土かどうか（国境をおおまかになぞった多角形。香港・マカオは除く）。
    static func isInMainlandChina(_ c: CLLocationCoordinate2D) -> Bool {
        let lat = c.latitude, lon = c.longitude
        // ほとんどの呼び出し（日本・欧米）は、ここで多角形の判定をせずに抜ける。
        guard (18...54).contains(lat), (73...135).contains(lon) else { return false }
        if (22.15...22.57).contains(lat) && (113.82...114.45).contains(lon) { return false } // 香港
        if (22.10...22.22).contains(lat) && (113.52...113.60).contains(lon) { return false } // マカオ
        var inside = false
        var j = chinaBorder.count - 1
        for i in 0..<chinaBorder.count {
            let (xi, yi) = chinaBorder[i]
            let (xj, yj) = chinaBorder[j]
            if (yi > lat) != (yj > lat), lon < (xj - xi) * (lat - yi) / (yj - yi) + xi {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// 中国本土の国境・海岸線をおおまかになぞった多角形（経度, 緯度）。国境付近の数十km程度は
    /// 正確ではないが、都市を判定するには十分な精度。
    private static let chinaBorder: [(Double, Double)] = [
        (73.5, 39.5), (75.0, 40.5), (80.0, 42.5), (82.5, 45.0), (85.0, 47.5), (87.5, 49.2), (90.0, 47.8),
        (95.0, 45.0), (97.0, 42.8), (105.0, 41.8), (111.5, 43.5), (116.0, 46.5), (119.5, 49.5), (121.5, 53.4),
        (126.0, 52.8), (131.0, 48.0), (134.8, 48.2), (131.0, 44.5), (131.0, 42.8), (129.5, 42.3), (126.0, 40.3),
        (124.2, 39.8), (122.0, 39.0), (122.5, 37.5), (123.0, 35.0), (122.5, 31.5), (122.0, 29.0), (120.5, 26.0),
        (118.0, 24.3), (117.0, 23.2), (111.0, 21.0), (108.5, 21.5), (106.5, 22.4), (105.5, 23.3), (103.5, 22.6),
        (101.7, 21.2), (100.0, 21.5), (99.2, 22.2), (98.7, 24.1), (97.5, 24.8), (98.6, 27.5), (97.4, 28.3),
        (96.0, 29.4), (94.0, 29.3), (92.0, 27.8), (90.0, 28.2), (88.9, 27.3), (88.0, 27.9), (86.0, 27.9),
        (84.0, 28.6), (81.5, 30.2), (79.5, 30.9), (79.0, 32.4), (78.4, 34.0), (79.5, 35.6), (77.8, 35.5),
        (76.0, 36.9), (74.6, 37.2),
    ]

    /// WGS84 → GCJ-02 のずれ（度）。公開されている一般的な変換式。
    private static func gcjOffset(_ c: CLLocationCoordinate2D) -> (lat: Double, lon: Double) {
        let a = 6_378_245.0
        let ee = 0.006_693_421_622_965_943
        let x = c.longitude - 105.0
        let y = c.latitude - 35.0
        var dLat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        dLat += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        dLat += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        dLat += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        var dLon = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        dLon += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        dLon += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        dLon += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        let radLat = c.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return (dLat, dLon)
    }
}
