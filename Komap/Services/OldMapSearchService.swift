import CoreLocation
import Foundation
import UIKit

enum OldMapSearchError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case noImageFound
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "\(AppSettings.aiProvider.apiKeyLabel)が必要です。「設定」→「アドバンス設定」→「AI設定」から入力してください。"
        case .invalidResponse:
            return "検索結果を読み取れませんでした。しばらくしてから再度お試しください。"
        case .noImageFound:
            return "条件に合う古地図の画像が見つかりませんでした。検索内容を変えて再度お試しください。"
        case .server(let message):
            if message.localizedCaseInsensitiveContains("api key") {
                return "APIキーが正しくないため検索できませんでした（\(message)）。"
                    + "「設定」→「アドバンス設定」→「AI設定」の\(AppSettings.aiProvider.apiKeyLabel)を確認してください。"
            }
            return "検索でエラーが発生しました: \(message)"
        }
    }
}

/// 「古地図を検索」機能で見つかった候補。
struct OldMapSearchResult {
    let title: String
    let era: String
    let summary: String
    let southWest: CLLocationCoordinate2D
    let northEast: CLLocationCoordinate2D
    let image: UIImage
    /// 画像が見つからずAIが作った時・ファンタジー地図の時などに見せる補足の案内。
    var notice: String?
    /// 画像が見つからなかった時・ファンタジー地図の時に、AIが条件に合わせて作ったチェックポイント。
    var checkpoints: [GeneratedCheckpoint] = []
}

/// 検索・作成する地図の範囲の限定（緯度経度の矩形）。
struct OldMapSearchBounds {
    let southWest: CLLocationCoordinate2D
    let northEast: CLLocationCoordinate2D

    /// 中心から東西南北に`radiusKm`kmの範囲。
    static func around(_ center: CLLocationCoordinate2D, radiusKm: Double) -> OldMapSearchBounds {
        let latDelta = radiusKm / 111.32
        let lngDelta = radiusKm / (111.32 * max(cos(center.latitude * .pi / 180), 0.01))
        return OldMapSearchBounds(
            southWest: CLLocationCoordinate2D(latitude: center.latitude - latDelta, longitude: center.longitude - lngDelta),
            northEast: CLLocationCoordinate2D(latitude: center.latitude + latDelta, longitude: center.longitude + lngDelta)
        )
    }

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (southWest.latitude + northEast.latitude) / 2,
            longitude: (southWest.longitude + northEast.longitude) / 2
        )
    }
}

/// 「古地図を検索」画面の範囲の選択肢。
enum OldMapSearchArea: String, CaseIterable, Identifiable {
    case currentView, within5km, within10km

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentView: return "現在の範囲"
        case .within5km: return "周囲5km"
        case .within10km: return "周囲10km"
        }
    }

    /// 検索を始めた時の地図の表示範囲`visible`から、限定する範囲を求める。表示範囲が分からない時は`nil`（限定しない）。
    func bounds(visible: OldMapSearchBounds?) -> OldMapSearchBounds? {
        guard let visible else { return nil }
        switch self {
        case .currentView: return visible
        case .within5km: return .around(visible.center, radiusKm: 5)
        case .within10km: return .around(visible.center, radiusKm: 10)
        }
    }
}

/// AIが生成したチェックポイント1件分。
struct GeneratedCheckpoint {
    let name: String
    let summary: String
    let coordinate: CLLocationCoordinate2D
}

/// ユーザーが入力した地域の説明から、AI（OpenAI）でおおよその位置範囲・古地図の
/// タイトルや時代を推定しつつ、国立国会図書館デジタルコレクションとWikimedia Commons
/// （どちらもAPIキー不要）でそれらしい古地図の画像を探して組み合わせ、古地図候補を1件作る。
struct OldMapSearchService {
    /// - Parameters:
    ///   - limitedTo: 指定すると、作る地図の範囲とチェックポイントをこの範囲の中に収める。
    ///   - fantasy: `true`の時は実在の古地図を探さず、その地域を舞台にしたファンタジー地図を
    ///     AIで作る（画像生成に対応したプロバイダーなら画像も生成する）。
    func search(query: String, limitedTo limit: OldMapSearchBounds? = nil, fantasy: Bool = false) async throws -> OldMapSearchResult {
        guard SecretsConfig.apiKey(for: AppSettings.aiProvider) != nil else { throw OldMapSearchError.missingAPIKey }

        if fantasy {
            return try await makeFantasyMap(query: query, limit: limit)
        }

        async let boundsTask = estimateBounds(query: query, limit: limit, fantasy: false)
        async let imageURLTask = searchImageURL(query: query)

        let bounds = try await boundsTask
        do {
            let imageURL = try await imageURLTask
            let image = try await downloadImage(from: imageURL)
            return OldMapSearchResult(
                title: bounds.title, era: bounds.era, summary: bounds.summary,
                southWest: bounds.southWest, northEast: bounds.northEast, image: image
            )
        } catch {
            // 古地図の画像が見つからない（または取得できない）場合は、条件に合わせて
            // AIが推定した範囲と、AIが選んだ5つのチェックポイントで地図情報を作る。
            return OldMapSearchResult(
                title: bounds.title, era: bounds.era, summary: bounds.summary,
                southWest: bounds.southWest, northEast: bounds.northEast,
                image: Self.makeGeneratedLayerImage(title: bounds.title, era: bounds.era),
                notice: "条件に合う古地図の画像が見つからなかったため、AIが条件に合わせて地図レイヤーとチェックポイントを作りました。範囲や位置は概算です。",
                checkpoints: bounds.checkpoints
            )
        }
    }

    /// ファンタジー地図を作る。範囲・名前・チェックポイントはAIのテキスト回答から、
    /// 地図の絵はプロバイダーの画像生成から得る（画像生成できない時は方眼の紙のレイヤーで代用）。
    private func makeFantasyMap(query: String, limit: OldMapSearchBounds?) async throws -> OldMapSearchResult {
        let bounds = try await estimateBounds(query: query, limit: limit, fantasy: true)
        let prompt = """
        A top-down fantasy world map illustration on aged parchment, hand-drawn adventure map style, \
        inspired by the area described as "\(query)". Show rivers, forests, mountains, roads, villages, \
        a castle and towers. Fill the entire square frame edge to edge, no border, no text, no letters, no legend.
        """
        do {
            let generated = try await AIClient.generateImage(prompt: prompt)
            return OldMapSearchResult(
                title: bounds.title, era: bounds.era, summary: bounds.summary,
                southWest: bounds.southWest, northEast: bounds.northEast,
                image: Self.squareImage(generated),
                notice: "AIがこの地域を舞台にしたファンタジー地図を生成しました。実在の地図とは異なる架空の世界です。範囲や位置は概算です。",
                checkpoints: bounds.checkpoints
            )
        } catch {
            return OldMapSearchResult(
                title: bounds.title, era: bounds.era, summary: bounds.summary,
                southWest: bounds.southWest, northEast: bounds.northEast,
                image: Self.makeGeneratedLayerImage(title: bounds.title, era: bounds.era),
                notice: "ファンタジー地図の画像を生成できなかったため、方眼の地図レイヤーで代用しました（\(error.localizedDescription)）。名前とチェックポイントはAIが作った架空のものです。",
                checkpoints: bounds.checkpoints
            )
        }
    }

    /// `GMSGroundOverlay`が確実に描画できるよう、1024×1024pxの正方形に描き直す。
    private static func squareImage(_ image: UIImage) -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 画像が無い時の地図レイヤー。下の地図が透けて見えるよう半透明にした、
    /// 古地図風のセピア色の紙に方眼を引いた画像。
    /// - Important: `HistoricalOverlayMap`の注意書きのとおり、1024×1024pxの正方形にしている。
    private static func makeGeneratedLayerImage(title: String, era: String) -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            UIColor(red: 0.85, green: 0.72, blue: 0.5, alpha: 0.35).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 0.35).setStroke()
            cg.setLineWidth(2)
            for i in stride(from: 0, through: 1024, by: 128) {
                cg.move(to: CGPoint(x: i, y: 0)); cg.addLine(to: CGPoint(x: i, y: 1024))
                cg.move(to: CGPoint(x: 0, y: i)); cg.addLine(to: CGPoint(x: 1024, y: i))
            }
            cg.strokePath()

            cg.setLineWidth(12)
            cg.stroke(CGRect(x: 6, y: 6, width: 1012, height: 1012))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .bold),
                .foregroundColor: UIColor(red: 0.35, green: 0.22, blue: 0.1, alpha: 0.75),
                .paragraphStyle: paragraph,
            ]
            "\(title)\n\(era)".draw(in: CGRect(x: 40, y: 40, width: 944, height: 120), withAttributes: attributes)
        }
    }

    // MARK: - AIによる位置・タイトルの推定

    private func estimateBounds(query: String, limit: OldMapSearchBounds?, fantasy: Bool) async throws -> (
        title: String, era: String, summary: String,
        southWest: CLLocationCoordinate2D, northEast: CLLocationCoordinate2D,
        checkpoints: [GeneratedCheckpoint]
    ) {
        var systemPrompt: String
        if fantasy {
            systemPrompt = """
            あなたは想像力豊かなファンタジー世界の地図作家です。ユーザーが説明する実在の地域を舞台に、\
            その地形や地名の雰囲気を生かした架空のファンタジー世界の地図を作ります。\
            おおよその緯度経度の範囲（南西の角・北東の角）と、その世界にふさわしい地図の\
            タイトル・時代表現（例: 「剣と魔法の時代」）・短い紹介文を考えてください。\
            出力は必ず次の形式のJSONのみとし、それ以外の文字は含めないでください。
            {"title": "地図のタイトル（20文字程度）", "era": "時代表現", \
            "summary": "60文字程度の紹介文", "southWestLat": 数値, "southWestLng": 数値, \
            "northEastLat": 数値, "northEastLng": 数値, \
            "checkpoints": [{"name": "ファンタジー世界の城・塔・森・村などの名前", "summary": "40文字程度の説明", \
            "lat": 数値, "lng": 数値}]}
            checkpointsには、その地域の実際の名所などの位置に重ねた架空の場所を必ず5件、上の範囲の内側に入る\
            緯度経度で含めてください。
            """
        } else {
            systemPrompt = """
            あなたは日本の地理・歴史に詳しいアシスタントです。ユーザーが説明する地域について、\
            おおよその緯度経度の範囲（南西の角・北東の角）と、その地域にふさわしい古地図の\
            タイトル・時代表現・短い紹介文を推定してください。位置はあくまで概算で構いません。\
            出力は必ず次の形式のJSONのみとし、それ以外の文字は含めないでください。
            {"title": "古地図のタイトル（20文字程度）", "era": "時代表現（例: 明治時代（1890年代）", \
            "summary": "60文字程度の紹介文", "southWestLat": 数値, "southWestLng": 数値, \
            "northEastLat": 数値, "northEastLng": 数値, \
            "checkpoints": [{"name": "その地域にある史跡・名所の名前", "summary": "40文字程度の説明", \
            "lat": 数値, "lng": 数値}]}
            checkpointsには、ユーザーの説明に合った実在の史跡・名所を必ず5件、上の範囲の内側に入る\
            緯度経度で含めてください。
            """
        }
        if let limit {
            systemPrompt += """

            重要: 範囲（南西・北東）もcheckpointsの位置も、必ず次の範囲の内側に収めてください。\
            南西(緯度\(limit.southWest.latitude), 経度\(limit.southWest.longitude))、\
            北東(緯度\(limit.northEast.latitude), 経度\(limit.northEast.longitude))。
            """
        }

        let payloadData: Data
        do {
            payloadData = try await AIClient.completeJSON(system: systemPrompt, user: query, temperature: 0.3)
        } catch let error as AIClientError {
            switch error {
            case .missingAPIKey: throw OldMapSearchError.missingAPIKey
            case .invalidResponse: throw OldMapSearchError.invalidResponse
            case .server(let message): throw OldMapSearchError.server(message)
            }
        }
        guard let payload = try? JSONDecoder().decode(BoundsPayload.self, from: payloadData) else {
            throw OldMapSearchError.invalidResponse
        }

        // AIが南北・東西を取り違えても範囲の作成で落ちないよう、min/maxで整える。
        var south = min(payload.southWestLat, payload.northEastLat)
        var north = max(payload.southWestLat, payload.northEastLat)
        var west = min(payload.southWestLng, payload.northEastLng)
        var east = max(payload.southWestLng, payload.northEastLng)
        // 範囲の限定がある時は、AIの答えがはみ出していても限定範囲の内側に収める
        // （重なりが無い・つぶれてしまう場合は、限定範囲そのものを使う）。
        if let limit {
            south = max(south, limit.southWest.latitude)
            north = min(north, limit.northEast.latitude)
            west = max(west, limit.southWest.longitude)
            east = min(east, limit.northEast.longitude)
            if south >= north || west >= east {
                south = limit.southWest.latitude
                north = limit.northEast.latitude
                west = limit.southWest.longitude
                east = limit.northEast.longitude
            }
        }
        let checkpoints = (payload.checkpoints ?? [])
            .filter { (south...north).contains($0.lat) && (west...east).contains($0.lng) }
            .prefix(5)
            .map {
                GeneratedCheckpoint(
                    name: $0.name, summary: $0.summary,
                    coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                )
            }

        return (
            payload.title,
            payload.era,
            payload.summary,
            CLLocationCoordinate2D(latitude: south, longitude: west),
            CLLocationCoordinate2D(latitude: north, longitude: east),
            Array(checkpoints)
        )
    }

    // MARK: - 画像検索（国立国会図書館 → Wikimedia Commons）

    /// 国立国会図書館デジタルコレクション、次にWikimedia Commons（どちらもAPIキー不要）の
    /// 順で古地図の画像を探す。日本の古地図は国会図書館の方が見つかりやすい。
    private func searchImageURL(query: String) async throws -> URL {
        if let url = try? await searchNDL(query: query) { return url }
        for term in ["\(query) 古地図", "\(query) old map", query] {
            if let url = try await searchCommons(term: term) { return url }
        }
        throw OldMapSearchError.noImageFound
    }

    /// 国立国会図書館サーチ（OpenSearch）でデジタルコレクションの地図・絵図を探し、
    /// 画像が公開されている最初の1件をIIIF経由の画像URLにして返す。
    /// 図書館・国内限定などで画像を見られない資料も多いため、IIIFマニフェストが
    /// 取れるものまで順に確認する。
    private func searchNDL(query: String) async throws -> URL? {
        var checked = Set<String>()
        for suffix in ["古地図", "絵図", "地図"] {
            var components = URLComponents(string: "https://ndlsearch.ndl.go.jp/api/opensearch")!
            components.queryItems = [
                URLQueryItem(name: "any", value: "\(query) \(suffix)"),
                URLQueryItem(name: "dpid", value: "ndl-dl"),
                URLQueryItem(name: "cnt", value: "10"),
            ]
            guard let url = components.url else { continue }
            var request = URLRequest(url: url)
            request.setValue("Komap/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let xml = String(data: data, encoding: .utf8)
            else { continue }

            // 各<item>内の「dl.ndl.go.jp/pid/数字」がデジタルコレクションの資料ID。
            let pids = xml.components(separatedBy: "<item>").dropFirst().compactMap { item -> String? in
                guard let range = item.range(of: #"dl\.ndl\.go\.jp/pid/(\d+)"#, options: .regularExpression)
                else { return nil }
                return String(item[range].split(separator: "/").last ?? "")
            }
            for pid in pids where checked.insert(pid).inserted {
                if let imageURL = await ndlImageURL(pid: pid) { return imageURL }
            }
        }
        return nil
    }

    private func ndlImageURL(pid: String) async -> URL? {
        guard let manifestURL = URL(string: "https://www.dl.ndl.go.jp/api/iiif/\(pid)/manifest.json") else { return nil }
        var request = URLRequest(url: manifestURL)
        request.setValue("Komap/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sequences = json["sequences"] as? [[String: Any]],
              let canvases = sequences.first?["canvases"] as? [[String: Any]],
              let images = canvases.first?["images"] as? [[String: Any]],
              let resource = images.first?["resource"] as? [String: Any],
              let service = resource["service"] as? [String: Any],
              let serviceID = service["@id"] as? String
        else { return nil }
        return URL(string: "\(serviceID)/full/2000,/0/default.jpg")
    }

    private func searchCommons(term: String) async throws -> URL? {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "filetype:bitmap \(term)"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "5"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|mime"),
            URLQueryItem(name: "iiurlwidth", value: "2000"),
        ]
        guard let url = components.url else { throw OldMapSearchError.invalidResponse }

        var request = URLRequest(url: url)
        // Wikimediaはユーザーエージェントの無いリクエストを拒否することがある。
        request.setValue("Komap/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw OldMapSearchError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OldMapSearchError.server("HTTP \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(CommonsResponse.self, from: data)
        let pages = (decoded.query?.pages.values).map { Array($0) } ?? []
        // 検索順（index）に並べ、JPEG/PNGの画像だけを採用する。
        let sorted = pages.sorted { ($0.index ?? .max) < ($1.index ?? .max) }
        for page in sorted {
            guard let info = page.imageinfo?.first,
                  info.mime == "image/jpeg" || info.mime == "image/png",
                  let link = info.thumburl ?? info.url,
                  let imageURL = URL(string: link)
            else { continue }
            return imageURL
        }
        return nil
    }

    private func downloadImage(from url: URL) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.setValue("Komap/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let image = UIImage(data: data) else { throw OldMapSearchError.noImageFound }
        return image
    }
}

private struct BoundsPayload: Decodable {
    let title: String
    let era: String
    let summary: String
    let southWestLat: Double
    let southWestLng: Double
    let northEastLat: Double
    let northEastLng: Double
    struct Checkpoint: Decodable {
        let name: String
        let summary: String
        let lat: Double
        let lng: Double
    }
    let checkpoints: [Checkpoint]?
}

// MARK: - Wikimedia Commons API の出力モデル

private struct CommonsResponse: Decodable {
    struct Query: Decodable {
        let pages: [String: Page]
    }
    struct Page: Decodable {
        struct ImageInfo: Decodable {
            let url: String?
            let thumburl: String?
            let mime: String?
        }
        let index: Int?
        let imageinfo: [ImageInfo]?
    }
    let query: Query?
}
