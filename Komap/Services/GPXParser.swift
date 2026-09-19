import CoreLocation
import Foundation

/// GPXファイル（`<trkpt>`／`<rtept>`要素）から座標列と開始・終了日時を取り出す、
/// 軽量なパーサー。「後から旅を追加」機能（`GPXImportSheet`）で、スマートウォッチや
/// 他アプリで記録したGPXの軌跡を`WalkRoute`として取り込むために使う。
enum GPXParser {
    struct ParsedTrack {
        let coordinates: [CLLocationCoordinate2D]
        /// GPXに`<time>`があれば、その最小・最大値。無ければ`nil`（呼び出し側で今日時にする）。
        let startedAt: Date?
        let endedAt: Date?
    }

    enum GPXParserError: LocalizedError {
        case invalidFormat
        case tooFewPoints

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "GPXファイルを読み取れませんでした。ファイルの形式を確認してください。"
            case .tooFewPoints: return "GPXファイルの軌跡データが少なすぎます（2地点以上が必要です）。"
            }
        }
    }

    static func parse(data: Data) throws -> ParsedTrack {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw GPXParserError.invalidFormat }
        guard delegate.coordinates.count >= 2 else { throw GPXParserError.tooFewPoints }

        let times = delegate.times.compactMap { $0 }
        return ParsedTrack(
            coordinates: delegate.coordinates,
            startedAt: times.min(),
            endedAt: times.max()
        )
    }

    /// `<trkpt lat="" lon="">`（子要素に`<time>`があれば併せて）を集める`XMLParser`デリゲート。
    private final class Delegate: NSObject, XMLParserDelegate {
        var coordinates: [CLLocationCoordinate2D] = []
        /// `coordinates`と添字が対応する、各地点の日時（無ければ`nil`）。
        var times: [Date?] = []

        private var currentElement = ""
        private var isInsideTrackPoint = false
        private var pendingLatitude: Double?
        private var pendingLongitude: Double?
        private var currentTimeText = ""

        private static let isoFormatterWithFraction: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
        private static let isoFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()

        private static func date(from text: String) -> Date? {
            isoFormatterWithFraction.date(from: text) ?? isoFormatter.date(from: text)
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            currentElement = elementName
            if elementName == "trkpt" || elementName == "rtept" {
                isInsideTrackPoint = true
                pendingLatitude = attributeDict["lat"].flatMap(Double.init)
                pendingLongitude = attributeDict["lon"].flatMap(Double.init)
                currentTimeText = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInsideTrackPoint, currentElement == "time" else { return }
            currentTimeText += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            if elementName == "trkpt" || elementName == "rtept" {
                if let lat = pendingLatitude, let lon = pendingLongitude {
                    coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    let trimmed = currentTimeText.trimmingCharacters(in: .whitespacesAndNewlines)
                    times.append(trimmed.isEmpty ? nil : Self.date(from: trimmed))
                }
                isInsideTrackPoint = false
                pendingLatitude = nil
                pendingLongitude = nil
                currentTimeText = ""
            }
            currentElement = ""
        }
    }
}
