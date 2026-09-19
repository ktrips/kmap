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
            return "OpenAIのAPIキーが必要です。「設定」タブから入力してください。"
        case .invalidResponse:
            return "検索結果を読み取れませんでした。しばらくしてから再度お試しください。"
        case .noImageFound:
            return "条件に合う古地図の画像が見つかりませんでした。検索内容を変えて再度お試しください。"
        case .server(let message):
            if message.localizedCaseInsensitiveContains("api key") {
                return "APIキーが正しくないため検索できませんでした（\(message)）。"
                    + "「設定」→「アドバンス設定」→「AI設定」のOpenAI APIキーを確認してください。"
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
}

/// ユーザーが入力した地域の説明から、AI（OpenAI）でおおよその位置範囲・古地図の
/// タイトルや時代を推定しつつ、国立国会図書館デジタルコレクションとWikimedia Commons
/// （どちらもAPIキー不要）でそれらしい古地図の画像を探して組み合わせ、古地図候補を1件作る。
struct OldMapSearchService {
    var model: String = "gpt-4o-mini"

    func search(query: String) async throws -> OldMapSearchResult {
        guard SecretsConfig.openAIAPIKey != nil else { throw OldMapSearchError.missingAPIKey }

        async let boundsTask = estimateBounds(query: query)
        async let imageURLTask = searchImageURL(query: query)

        let bounds = try await boundsTask
        let imageURL = try await imageURLTask
        let image = try await downloadImage(from: imageURL)

        return OldMapSearchResult(
            title: bounds.title,
            era: bounds.era,
            summary: bounds.summary,
            southWest: bounds.southWest,
            northEast: bounds.northEast,
            image: image
        )
    }

    // MARK: - AIによる位置・タイトルの推定

    private func estimateBounds(query: String) async throws -> (
        title: String, era: String, summary: String,
        southWest: CLLocationCoordinate2D, northEast: CLLocationCoordinate2D
    ) {
        guard let apiKey = SecretsConfig.openAIAPIKey else { throw OldMapSearchError.missingAPIKey }

        let systemPrompt = """
        あなたは日本の地理・歴史に詳しいアシスタントです。ユーザーが説明する地域について、\
        おおよその緯度経度の範囲（南西の角・北東の角）と、その地域にふさわしい古地図の\
        タイトル・時代表現・短い紹介文を推定してください。位置はあくまで概算で構いません。\
        出力は必ず次の形式のJSONのみとし、それ以外の文字は含めないでください。
        {"title": "古地図のタイトル（20文字程度）", "era": "時代表現（例: 明治時代（1890年代）", \
        "summary": "60文字程度の紹介文", "southWestLat": 数値, "southWestLng": 数値, \
        "northEastLat": 数値, "northEastLng": 数値}
        """

        let requestBody = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: query),
            ],
            temperature: 0.3,
            responseFormat: .init(type: "json_object")
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw OldMapSearchError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OldMapSearchError.server(Self.apiErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              let contentData = content.data(using: .utf8),
              let payload = try? JSONDecoder().decode(BoundsPayload.self, from: contentData)
        else {
            throw OldMapSearchError.invalidResponse
        }

        return (
            payload.title,
            payload.era,
            payload.summary,
            CLLocationCoordinate2D(latitude: payload.southWestLat, longitude: payload.southWestLng),
            CLLocationCoordinate2D(latitude: payload.northEastLat, longitude: payload.northEastLng)
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

    /// OpenAI・Google Custom Searchはどちらもエラー時に`{"error": {"message": "..."}}`
    /// 形式のJSONを返す。生のJSON（`google.rpc.LocalizedMessage`等を含む長い構造体）を
    /// そのままエラーメッセージとして見せると読みにくいため、`message`だけを取り出す。
    /// 取り出せない場合は、返ってきた本文をそのまま使う（最後の手段としてHTTPステータスのみ）。
    private static func apiErrorMessage(from data: Data, statusCode: Int) -> String {
        struct ErrorEnvelope: Decodable {
            struct ErrorBody: Decodable {
                let message: String?
            }
            let error: ErrorBody?
        }
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data),
           let message = envelope.error?.message, !message.isEmpty {
            return message
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }
        return "HTTP \(statusCode)"
    }
}

// MARK: - OpenAI Chat Completions の入出力モデル

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct BoundsPayload: Decodable {
    let title: String
    let era: String
    let summary: String
    let southWestLat: Double
    let southWestLng: Double
    let northEastLat: Double
    let northEastLng: Double
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
