import Foundation
import UIKit

enum AIClientError: LocalizedError {
    case missingAPIKey(AIProvider)
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider.apiKeyLabel)が設定されていません。「設定」→「アドバンス設定」→「AI設定」から入力してください。"
        case .invalidResponse:
            return "AIからの応答を読み取れませんでした。しばらくしてから再度お試しください。"
        case .server(let message):
            if message.localizedCaseInsensitiveContains("blocked") {
                return "このAPIキーではGoogleのAI（Generative Language API）が許可されていません（\(message)）。"
                    + "Google AI Studio（aistudio.google.com）でGemini用のAPIキーを作って「AI設定」のGoogle APIキーに入れるか、"
                    + "Google Cloud Consoleでこのキーの「APIの制限」に「Generative Language API」を追加し、そのAPIを有効にしてください。"
                    + "（Google Maps用のキーは流用できないことがあります）"
            }
            if message.localizedCaseInsensitiveContains("api key") || message.localizedCaseInsensitiveContains("api_key") {
                return "APIキーが正しくないためAIを呼び出せませんでした（\(message)）。「設定」→「アドバンス設定」→「AI設定」を確認してください。"
            }
            return "AIとの通信でエラーが発生しました: \(message)"
        }
    }
}

extension SecretsConfig {
    /// 指定したAIプロバイダーのAPIキー。未設定なら`nil`。
    static func apiKey(for provider: AIProvider) -> String? {
        switch provider {
        case .openAI: return openAIAPIKey
        case .google: return googleAIAPIKey
        case .anthropic: return anthropicAPIKey
        }
    }
}

/// 「AI設定」で選んだデフォルトのAIプロバイダー（OpenAI・Google・Anthropic）に、
/// テキスト（と任意で画像1枚）を送ってJSON形式の回答を得る共通のクライアント。
/// 物語・旅日記・古地図検索などの生成処理がこれを通して、選んだプロバイダーのAPIを呼ぶ。
enum AIClient {
    /// 各プロバイダーで使うモデル。いずれも画像入力に対応した軽量モデル。
    private static func model(for provider: AIProvider) -> String {
        switch provider {
        case .openAI: return "gpt-4o-mini"
        case .google: return "gemini-2.5-flash"
        case .anthropic: return "claude-haiku-4-5-20251001"
        }
    }

    /// - Parameters:
    ///   - system: システムプロンプト（出力形式のJSON指定を含める）。
    ///   - user: ユーザー側の本文。
    ///   - jpeg: 添付する画像（JPEG）。無ければ`nil`。
    /// - Returns: 回答本文の中のJSONオブジェクト部分（前後の説明文やコードブロックは取り除く）。
    static func completeJSON(
        system: String,
        user: String,
        jpeg: Data? = nil,
        temperature: Double = 0.8
    ) async throws -> Data {
        let provider = AppSettings.aiProvider
        guard let apiKey = SecretsConfig.apiKey(for: provider) else {
            throw AIClientError.missingAPIKey(provider)
        }

        let request: URLRequest
        switch provider {
        case .openAI: request = try openAIRequest(apiKey, system, user, jpeg, temperature)
        case .google: request = try googleRequest(apiKey, system, user, jpeg, temperature)
        case .anthropic: request = try anthropicRequest(apiKey, system, user, jpeg, temperature)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AIClientError.server(errorMessage(from: data, statusCode: http.statusCode))
        }

        guard let text = extractText(from: data, provider: provider),
              let json = extractJSONObject(from: text)
        else { throw AIClientError.invalidResponse }
        return json
    }

    // MARK: - リクエストの組み立て

    private static func makeRequest(_ url: URL, headers: [String: String], body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Googleへのリクエストのヘッダー。キーに「iOSアプリ」の制限が付いている場合に必要になる
    /// バンドルIDも添える（制限が無いキーでは無視される）。
    private static func googleHeaders(_ key: String) -> [String: String] {
        var headers = ["x-goog-api-key": key]
        if let bundleID = Bundle.main.bundleIdentifier {
            headers["X-Ios-Bundle-Identifier"] = bundleID
        }
        return headers
    }

    private static func openAIRequest(_ key: String, _ system: String, _ user: String, _ jpeg: Data?, _ temperature: Double) throws -> URLRequest {
        var userContent: Any = user
        if let jpeg {
            userContent = [
                ["type": "text", "text": user],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]],
            ]
        }
        return try makeRequest(
            URL(string: "https://api.openai.com/v1/chat/completions")!,
            headers: ["Authorization": "Bearer \(key)"],
            body: [
                "model": model(for: .openAI),
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": userContent],
                ],
                "temperature": temperature,
                "response_format": ["type": "json_object"],
            ]
        )
    }

    private static func googleRequest(_ key: String, _ system: String, _ user: String, _ jpeg: Data?, _ temperature: Double) throws -> URLRequest {
        var parts: [[String: Any]] = [["text": user]]
        if let jpeg {
            parts.append(["inlineData": ["mimeType": "image/jpeg", "data": jpeg.base64EncodedString()]])
        }
        return try makeRequest(
            URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model(for: .google)):generateContent")!,
            headers: googleHeaders(key),
            body: [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["role": "user", "parts": parts]],
                "generationConfig": ["temperature": temperature, "responseMimeType": "application/json"],
            ]
        )
    }

    private static func anthropicRequest(_ key: String, _ system: String, _ user: String, _ jpeg: Data?, _ temperature: Double) throws -> URLRequest {
        var content: [[String: Any]] = []
        if let jpeg {
            content.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()],
            ])
        }
        content.append(["type": "text", "text": user])
        return try makeRequest(
            URL(string: "https://api.anthropic.com/v1/messages")!,
            headers: ["x-api-key": key, "anthropic-version": "2023-06-01"],
            body: [
                "model": model(for: .anthropic),
                "max_tokens": 2048,
                "temperature": min(temperature, 1),
                "system": system,
                "messages": [["role": "user", "content": content]],
            ]
        )
    }

    // MARK: - レスポンスの読み取り

    private static func extractText(from data: Data, provider: AIProvider) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        switch provider {
        case .openAI:
            let choices = root["choices"] as? [[String: Any]]
            return (choices?.first?["message"] as? [String: Any])?["content"] as? String
        case .google:
            let candidates = root["candidates"] as? [[String: Any]]
            let parts = (candidates?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]
            return parts?.compactMap { $0["text"] as? String }.joined()
        case .anthropic:
            let content = root["content"] as? [[String: Any]]
            return content?.compactMap { $0["text"] as? String }.joined()
        }
    }

    /// 回答本文から、最初の`{`〜最後の`}`までのJSONオブジェクトを取り出す
    /// （JSONモードの無いプロバイダーがコードブロックや前置きを付けても読めるようにする）。
    private static func extractJSONObject(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        return String(text[start...end]).data(using: .utf8)
    }

    /// 各社共通の`{"error": {"message": "..."}}`形式から`message`だけを取り出す。
    private static func errorMessage(from data: Data, statusCode: Int) -> String {
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = root["error"] as? [String: Any],
           let message = error["message"] as? String, !message.isEmpty {
            return message
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty { return raw }
        return "HTTP \(statusCode)"
    }

    // MARK: - 画像の生成

    /// デフォルトのAIプロバイダーに画像を1枚生成してもらう（正方形）。
    /// OpenAI・Googleに対応。Anthropicは画像生成APIが無いためエラーにする。
    ///
    /// `referenceImage`を渡すと、その画像をもとに指示どおり描き直した画像を得る
    /// （既存の地図の見た目を保ったまま、より綺麗にする時などに使う）。
    static func generateImage(prompt: String, referenceImage: UIImage? = nil) async throws -> UIImage {
        let provider = AppSettings.aiProvider
        guard let apiKey = SecretsConfig.apiKey(for: provider) else {
            throw AIClientError.missingAPIKey(provider)
        }

        let request: URLRequest
        switch provider {
        case .openAI:
            if let referenceImage, let png = referenceImage.pngData() {
                request = multipartImageEditRequest(apiKey: apiKey, prompt: prompt, png: png)
            } else {
                request = try makeRequest(
                    URL(string: "https://api.openai.com/v1/images/generations")!,
                    headers: ["Authorization": "Bearer \(apiKey)"],
                    body: ["model": "gpt-image-1", "prompt": prompt, "size": "1024x1024", "quality": "low", "n": 1]
                )
            }
        case .google:
            var parts: [[String: Any]] = [["text": prompt]]
            if let referenceImage, let png = referenceImage.pngData() {
                parts.append(["inlineData": ["mimeType": "image/png", "data": png.base64EncodedString()]])
            }
            request = try makeRequest(
                URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent")!,
                headers: googleHeaders(apiKey),
                body: [
                    "contents": [["parts": parts]],
                    "generationConfig": ["responseModalities": ["IMAGE"]],
                ]
            )
        case .anthropic:
            throw AIClientError.server("Anthropicは画像を生成できません（画像の生成にはOpenAIまたはGoogleを選んでください）")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AIClientError.server(errorMessage(from: data, statusCode: http.statusCode))
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.invalidResponse
        }
        var base64: String?
        switch provider {
        case .openAI:
            base64 = ((root["data"] as? [[String: Any]])?.first)?["b64_json"] as? String
        case .google:
            let candidates = root["candidates"] as? [[String: Any]]
            let parts = (candidates?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]
            for part in parts ?? [] {
                let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any]
                if let value = inline?["data"] as? String { base64 = value; break }
            }
        case .anthropic:
            break
        }
        guard let base64, let imageData = Data(base64Encoded: base64), let image = UIImage(data: imageData) else {
            throw AIClientError.invalidResponse
        }
        return image
    }

    /// OpenAIの画像編集API（`/v1/images/edits`）用の`multipart/form-data`リクエスト。
    private static func multipartImageEditRequest(apiKey: String, prompt: String, png: Data) -> URLRequest {
        let boundary = "komap-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("model", "gpt-image-1")
        field("prompt", prompt)
        field("size", "1024x1024")
        field("quality", "medium")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"map.png\"\r\nContent-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(png)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }
}
