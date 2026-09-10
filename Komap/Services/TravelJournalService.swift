import Foundation
import SwiftData

enum TravelJournalError: LocalizedError {
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

/// 生成された旅日記（見出し + Markdown本文）
struct GeneratedTravelJournal {
    let title: String
    let markdownBody: String
}

/// 1回の時間旅（`WalkRoute`）の内容から、AIに「旅のサマリー」（200字程度）を
/// 書いてもらうサービス。
///
/// 巡った御朱印スポットの詳細は、チェックポイント詳細シート（`CheckpointInfoSheet`）と
/// 同じ`CheckpointStory`キャッシュを使い、既にあればそのまま使い、無ければこのタイミングで
/// 生成してキャッシュに保存する。個々の詳細は旅日記画面の御朱印/写真ギャラリーに
/// そのまま表示する（サマリー本文には繰り返し含めない）ため、アプリ上のチェックポイント詳細・
/// 旅日記・Web上の旅日記表示のすべてで同じ内容になる。
struct TravelJournalService {
    /// テキスト生成に使うモデル名。必要に応じて変更可能。
    var model: String = "gpt-4o-mini"

    private let historyService = AIHistoryService()

    func generateJournal(
        for route: WalkRoute,
        stamps: [CollectedStamp],
        photoPosts: [WalkPhotoPost],
        modelContext: ModelContext
    ) async throws -> GeneratedTravelJournal {
        guard let apiKey = SecretsConfig.openAIAPIKey else {
            throw TravelJournalError.missingAPIKey
        }

        let checkpointDetails = try await resolveCheckpointDetails(
            for: stamps,
            overlayMap: route.overlayMap,
            modelContext: modelContext
        )

        let systemPrompt = """
        あなたは日本の歴史・地理に詳しい語り部です。ユーザーが古地図を片手に歩いた
        「時間旅」の記録（旅の名前・使った古地図・歩いた統計・感想・巡った史跡の一覧・
        投稿した写真の情報）をもとに、その旅を振り返る「旅のサマリー」を日本語で
        書いてください。個々の史跡の詳しい説明は旅日記の他の場所（御朱印・写真の一覧）で
        別途表示されるため、ここでは繰り返さず、旅全体の印象・雰囲気・見どころが伝わる
        文章を、旅情を感じられる語り口で簡潔にまとめてください。
        文字数は200字程度（多くても250字まで）に収めてください。小見出しは不要です。
        史実として確定していない場合は、伝承や一般的な当時の様子として、
        断定を避けた表現（例:「〜と伝えられています」「〜だったと考えられます」）を使ってください。
        出力は必ず次の形式のJSONのみとし、それ以外の文字は含めないでください。
        {"title": "20文字程度の旅日記タイトル", "body": "200字程度のサマリー本文"}
        """

        let userPrompt = buildUserPrompt(route: route, checkpointDetails: checkpointDetails, photoPosts: photoPosts)

        let requestBody = JournalChatRequest(
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
            throw TravelJournalError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TravelJournalError.server(message)
        }

        let decoded = try JSONDecoder().decode(JournalChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              let contentData = content.data(using: .utf8),
              let journal = try? JSONDecoder().decode(JournalPayload.self, from: contentData)
        else {
            throw TravelJournalError.invalidResponse
        }

        return GeneratedTravelJournal(title: journal.title, markdownBody: journal.body)
    }

    /// 巡った御朱印スポットそれぞれについて、既存の`CheckpointStory`があればそれを使い、
    /// 無ければ`AIHistoryService`で生成してキャッシュに保存してから返す。
    private func resolveCheckpointDetails(
        for stamps: [CollectedStamp],
        overlayMap: HistoricalOverlayMap?,
        modelContext: ModelContext
    ) async throws -> [(site: HistoricSite, title: String, body: String)] {
        var details: [(site: HistoricSite, title: String, body: String)] = []
        var seenSiteIDs: Set<String> = []

        for stamp in stamps {
            guard let site = stamp.site, !seenSiteIDs.contains(site.id) else { continue }
            seenSiteIDs.insert(site.id)

            if let existing = fetchSavedStory(siteID: site.id, modelContext: modelContext) {
                details.append((site: site, title: existing.title, body: existing.body))
                continue
            }

            do {
                let story = try await historyService.generateStory(
                    for: site.coordinate,
                    overlayMap: overlayMap,
                    placeName: site.name
                )
                let saved = CheckpointStory(siteID: site.id, title: story.title, body: story.body)
                modelContext.insert(saved)
                try? modelContext.save()
                details.append((site: site, title: story.title, body: story.body))
            } catch {
                // その場所の詳細が取得できなくても、他の場所の分で旅日記は生成できるので続行する。
                continue
            }
        }

        return details
    }

    private func fetchSavedStory(siteID: String, modelContext: ModelContext) -> CheckpointStory? {
        let descriptor = FetchDescriptor<CheckpointStory>(
            predicate: #Predicate { $0.siteID == siteID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func buildUserPrompt(
        route: WalkRoute,
        checkpointDetails: [(site: HistoricSite, title: String, body: String)],
        photoPosts: [WalkPhotoPost]
    ) -> String {
        var lines: [String] = []
        lines.append("旅の名前: \(route.title ?? "名称未設定の時間旅")")
        if let overlayMap = route.overlayMap {
            lines.append("使った古地図: \(overlayMap.title)（\(overlayMap.era)）")
            lines.append("古地図の紹介: \(overlayMap.summary)")
        }
        lines.append("開始日時: \(route.startedAt.formatted(date: .long, time: .shortened))")
        if let durationSeconds = route.durationSeconds {
            lines.append("歩いた時間: 約\(Int(durationSeconds / 60))分")
        }
        lines.append("歩いた距離: 約\(Int(route.totalDistanceMeters))メートル")
        if let notes = route.notes, !notes.isEmpty {
            lines.append("ユーザーが書いた感想: \(notes)")
        }

        if !checkpointDetails.isEmpty {
            lines.append("\n巡った史跡（訪れた順）:")
            for detail in checkpointDetails {
                lines.append("- \(detail.site.name)「\(detail.title)」: \(detail.body)")
            }
        }

        if !photoPosts.isEmpty {
            lines.append("\n道中で投稿した写真:")
            for post in photoPosts {
                let place = post.placeName ?? "場所不明の地点"
                let time = post.postedAt.formatted(date: .omitted, time: .shortened)
                if let storyTitle = post.storyTitle, let storyBody = post.storyBody {
                    lines.append("- \(time) \(place)「\(storyTitle)」: \(storyBody)")
                } else {
                    lines.append("- \(time) \(place)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - OpenAI Chat Completions の入出力モデル

private struct JournalChatRequest: Encodable {
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

private struct JournalChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct JournalPayload: Decodable {
    let title: String
    let body: String
}
