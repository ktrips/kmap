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
            return "OpenAIとGoogleカスタム検索のAPIキーが両方とも必要です。「設定」タブから入力してください。"
        case .invalidResponse:
            return "検索結果を読み取れませんでした。しばらくしてから再度お試しください。"
        case .noImageFound:
            return "条件に合う古地図の画像が見つかりませんでした。検索内容を変えて再度お試しください。"
        case .server(let message):
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
/// タイトルや時代を推定しつつ、Googleカスタム検索でそれらしい古地図の画像を探して
/// 組み合わせ、古地図候補を1件作る。
struct OldMapSearchService {
    var model: String = "gpt-4o-mini"

    func search(query: String) async throws -> OldMapSearchResult {
        guard SecretsConfig.openAIAPIKey != nil else { throw OldMapSearchError.missingAPIKey }
        guard SecretsConfig.googleCustomSearchAPIKey != nil, SecretsConfig.googleCustomSearchEngineID != nil else {
            throw OldMapSearchError.missingAPIKey
        }

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
            throw OldMapSearchError.server(String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)")
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

    // MARK: - Googleカスタム検索での画像検索

    private func searchImageURL(query: String) async throws -> URL {
        guard let apiKey = SecretsConfig.googleCustomSearchAPIKey,
              let engineID = SecretsConfig.googleCustomSearchEngineID
        else {
            throw OldMapSearchError.missingAPIKey
        }

        var components = URLComponents(string: "https://www.googleapis.com/customsearch/v1")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: engineID),
            URLQueryItem(name: "q", value: "\(query) 古地図"),
            URLQueryItem(name: "searchType", value: "image"),
            URLQueryItem(name: "num", value: "1"),
            URLQueryItem(name: "safe", value: "active"),
        ]
        guard let url = components.url else { throw OldMapSearchError.invalidResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else { throw OldMapSearchError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OldMapSearchError.server(String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(CustomSearchResponse.self, from: data)
        guard let link = decoded.items?.first?.link, let imageURL = URL(string: link) else {
            throw OldMapSearchError.noImageFound
        }
        return imageURL
    }

    private func downloadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else { throw OldMapSearchError.noImageFound }
        return image
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

// MARK: - Google Custom Search JSON API の入出力モデル

private struct CustomSearchResponse: Decodable {
    struct Item: Decodable {
        let link: String
    }
    let items: [Item]?
}
