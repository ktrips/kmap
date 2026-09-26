import Foundation

/// 時空旅の一覧・詳細・旅日記・共有カードで共通に使う表示用の書式
/// （以前は同じ処理が画面ごとに書かれていた）。Web側の`web/src/lib/format.ts`と同じ表記にそろえる。
enum TripFormat {
    /// 「YYYY/M/D HH:MI」形式の日時表記。
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter
    }()

    /// 「3.6 km」「850 m」のような距離の表記。
    static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    /// 「1時間5分」「49分」のような歩いた時間の表記。時間が分からなければ`nil`。
    static func duration(_ seconds: TimeInterval?) -> String? {
        guard let seconds else { return nil }
        let totalMinutes = Int(seconds / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)時間\(totalMinutes % 60)分"
        }
        return "\(max(totalMinutes, 1))分"
    }
}
