import CoreLocation
import Foundation
import UIKit

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
///
/// `photo`を渡すと、位置情報だけでなく実際に撮った写真の内容（何が写っているか・
/// どんな雰囲気か）も踏まえた説明文を生成する（OpenAIのVision対応モデルを使用）。
struct AIHistoryService {
    /// 生成に使うモデル名。必要に応じて変更可能。`gpt-4o-mini`は画像入力にも対応している。
    var model: String = "gpt-4o-mini"

    /// 添付する写真の長辺の上限。AIへの送信サイズを抑えつつ、内容が判別できる範囲。
    private static let maxPhotoDimension: CGFloat = 768
    private static let photoJPEGQuality: CGFloat = 0.6

    func generateStory(
        for coordinate: CLLocationCoordinate2D,
        overlayMap: HistoricalOverlayMap?,
        placeName: String? = nil,
        userTitle: String? = nil,
        photo: UIImage? = nil
    ) async throws -> GeneratedStory {
        guard let apiKey = SecretsConfig.openAIAPIKey else {
            throw AIHistoryError.missingAPIKey
        }

        let era = overlayMap?.era ?? "江戸時代"
        let placeHint = placeName ?? overlayMap?.title ?? "この付近"
        let trimmedUserTitle = userTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUserTitle = !(trimmedUserTitle?.isEmpty ?? true)
        let hasPhoto = photo != nil

        let systemPrompt: String
        if hasPhoto {
            // 写真が添付されている時は、史実の解説というより「その写真に写っているものを
            // 手がかりにした、旅の記録としての一言」を書いてもらう。実在しない歴史的事実を
            // 断定的に作り話しないよう、写真から読み取れる内容（被写体・季節感・雰囲気）を
            // 中心に、位置情報やエリアの手がかりはあくまで背景として添える程度にする。
            systemPrompt = """
            あなたは旅の記録を書き添えるのが得意な、観察眼の鋭い書き手です。ユーザーが旅の途中で
            撮った写真が1枚添付されています。写真に何が写っているか（被写体・色合い・季節感・
            雰囲気）をよく見て、位置情報やエリアの手がかり、ユーザーが写真に付けた名前（あれば）も
            参考にしながら、その一枚が持つ魅力や旅情が伝わる、短い読み物を日本語で書いてください。
            写真から読み取れない史実を断定的に創作しないでください（地名の由来など一般的に
            知られていることに触れるのは構いません）。
            出力は必ず次の形式のJSONのみとし、それ以外の文字は含めないでください。
            {"title": "15文字程度の見出し", "body": "150〜250文字程度の本文"}
            """
        } else {
            systemPrompt = """
            あなたは日本の歴史・地理に詳しい語り部です。ユーザーは現在地図上のある地点にいて、\
            その場所が昔（\(era)）どのような場所だったのかを知りたがっています。\
            与えられた緯度経度とエリアの手がかりから、その周辺の歴史的な背景・当時の街の様子・\
            伝わっている出来事や逸話を、旅情を感じられる語り口で日本語で紹介してください。\
            史実として確定していない場合は、伝承や一般的な当時の様子として、\
            断定を避けた表現（例:「〜と伝えられています」「〜だったと考えられます」）を使ってください。\
            出力は必ず次の形式のJSONのみとし、それ以外の文字は含めないでください。
            {"title": "15文字程度の見出し", "body": "200〜320文字程度の本文"}
            """
        }

        var userPromptLines = [
            "緯度: \(coordinate.latitude)",
            "経度: \(coordinate.longitude)",
            "エリアの手がかり: \(placeHint)",
            "時代: \(era)",
        ]
        if hasUserTitle, let trimmedUserTitle {
            userPromptLines.append("この写真にユーザーが付けた名前: \(trimmedUserTitle)")
        }
        let userPromptText = userPromptLines.joined(separator: "\n")

        var userContentParts: [ChatRequest.ContentPart] = [.text(userPromptText)]
        if let photo, let dataURL = Self.dataURL(for: photo) {
            userContentParts.append(.imageURL(dataURL))
        }

        let requestBody = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: .text(systemPrompt)),
                .init(role: "user", content: hasPhoto ? .parts(userContentParts) : .text(userPromptText)),
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

    /// 写真を送信サイズまで縮小・JPEG圧縮し、Vision APIが受け付ける`data:`URL文字列にする。
    private static func dataURL(for image: UIImage) -> String? {
        let longestSide = max(image.size.width, image.size.height)
        let resized: UIImage
        if longestSide > maxPhotoDimension {
            let scale = maxPhotoDimension / longestSide
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            resized = image
        }
        guard let jpegData = resized.jpegData(compressionQuality: photoJPEGQuality) else { return nil }
        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }
}

// MARK: - OpenAI Chat Completions の入出力モデル

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: MessageContent
    }

    /// OpenAI Chat Completionsの`content`は、テキストのみの場合は単純な文字列、
    /// 画像を含む場合は`{type, text}`/`{type, image_url}`の配列という2つの形を取る。
    enum MessageContent: Encodable {
        case text(String)
        case parts([ContentPart])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .parts(let parts):
                try container.encode(parts)
            }
        }
    }

    struct ContentPart: Encodable {
        let type: String
        let text: String?
        let imageURL: ImageURL?

        struct ImageURL: Encodable {
            let url: String
        }

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }

        static func text(_ text: String) -> ContentPart {
            ContentPart(type: "text", text: text, imageURL: nil)
        }

        static func imageURL(_ url: String) -> ContentPart {
            ContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: url))
        }
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
