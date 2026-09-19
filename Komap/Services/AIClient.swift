import Foundation

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
            headers: ["x-goog-api-key": key],
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
}
