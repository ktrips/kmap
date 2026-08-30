import CoreLocation
import Foundation

enum AIHistoryError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAIのAPIキーが設定されていません。「設定」タブから入力してください。"
        case .invalidResponse:
            return "AIからの応答を読み取れませんでした。しばらくしてから再度お試しください。"
        case .server(let message):
            return "AIとの通信でエラーが発生しました: \(message)"
        }
    }
}

/// 生成されたAIの物語（見出し + 本文）
struct GeneratedStory {
    let title: String
    let body: String
}

/// 指定した座標・時代に基づいて、OpenAI APIに「昔の出来事や物語」を生成してもらうサービス。
struct AIHistoryService {
    /// テキスト生成に使うモデル名。必要に応じて変更可能。
    var model: String = "gpt-4o-mini"

    func generateStory(
        for coordinate: CLLocationCoordinate2D,
        overlayMap: HistoricalOverlayMap?,
        placeName: String? = nil
    ) async throws -> GeneratedStory {
        guard let apiKey = SecretsConfig.openAIAPIKey else {
            throw AIHistoryError.missingAPIKey
        }

        let era = overlayMap?.era ?? "江戸時代"
        let placeHint = placeName ?? overlayMap?.title ?? "この付近"

        let systemPrompt = """
        あなたは日本の歴史・地理に詳しい語り部です。ユーザーは現在地図上のある地点にいて、\
        その場所が昔（\(era)）どのような場所だったのかを知りたがっています。\
        与えられた緯度経度とエリアの手がかりから、その周辺の歴史的な背景・当時の街の様子・\
        伝わっている出来事や逸話を、旅情を感じられる語り口で日本語で紹介してください。\
        史実として確定していない場合は、伝承や一般的な当時の様子として、\
        断定を避けた表現（例:「〜と伝えられています」「〜だったと考えられます」）を使ってください。\
        出力は必ず次の形式のJSONのみとし、それ以外の文字は含めないでください。
        {"title": "15文字程度の見出し", "body": "200〜320文字程度の本文"}
        """

        let userPrompt = """
        緯度: \(coordinate.latitude)
        経度: \(coordinate.longitude)
        エリアの手がかり: \(placeHint)
        時代: \(era)
        """

        let requestBody = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt),
            ],
            temperature: 0.8,
            responseFormat: .init(type: "json_object")
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIHistoryError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIHistoryError.server(message)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              let contentData = content.data(using: .utf8),
              let story = try? JSONDecoder().decode(StoryPayload.self, from: contentData)
        else {
            throw AIHistoryError.invalidResponse
        }

        return GeneratedStory(title: story.title, body: story.body)
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

private struct StoryPayload: Decodable {
    let title: String
    let body: String
}
