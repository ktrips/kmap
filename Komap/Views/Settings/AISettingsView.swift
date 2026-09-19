import SwiftUI

/// 「AI設定」（物語生成に使うAIプロバイダーとAPIキー）をまとめた画面。
/// 「設定」画面の「アドバンス設定」→「AI設定」から開く。
///
/// - Note: 実際に物語・旅日記を生成する処理（`AIHistoryService`／`TravelJournalService`）は
///   現時点ではOpenAIのみに対応している。Google・AnthropicのAPIキーとデフォルト
///   プロバイダーの選択はここで保存できるが、生成処理側の切り替えは別途対応が必要。
struct AISettingsView: View {
    @State private var aiProvider: AIProvider = AppSettings.aiProvider
    @State private var openAIKey: String = SecretsConfig.openAIAPIKey ?? ""
    @State private var openAISavedMessage: String?
    @State private var googleAIKey: String = SecretsConfig.googleAIAPIKey ?? ""
    @State private var googleAISavedMessage: String?
    @State private var anthropicKey: String = SecretsConfig.anthropicAPIKey ?? ""
    @State private var anthropicSavedMessage: String?

    var body: some View {
        Form {
            providerSection
            apiKeySection(
                title: "OpenAI APIキー",
                placeholder: "sk-...",
                key: $openAIKey,
                savedMessage: $openAISavedMessage,
                footer: "地点をタップした際にAIが昔の物語を生成するために使用します。",
                onSave: { SecretsConfig.saveOpenAIAPIKey(openAIKey) }
            )
            apiKeySection(
                title: "Google APIキー",
                placeholder: "AIzaSy...",
                key: $googleAIKey,
                savedMessage: $googleAISavedMessage,
                footer: "デフォルトのAIプロバイダーで「Google」を選んだ場合に使用します。",
                onSave: { SecretsConfig.saveGoogleAIAPIKey(googleAIKey) }
            )
            apiKeySection(
                title: "Anthropic APIキー",
                placeholder: "sk-ant-...",
                key: $anthropicKey,
                savedMessage: $anthropicSavedMessage,
                footer: "デフォルトのAIプロバイダーで「Anthropic」を選んだ場合に使用します。",
                onSave: { SecretsConfig.saveAnthropicAPIKey(anthropicKey) }
            )
        }
        .navigationTitle("AI設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var providerSection: some View {
        Section {
            Picker("デフォルトのAIプロバイダー", selection: $aiProvider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            .onChange(of: aiProvider) { _, newValue in
                AppSettings.aiProvider = newValue
            }
        } footer: {
            Text("物語・旅日記の生成に使うAIプロバイダーです。既定はOpenAIです。")
        }
    }

    @ViewBuilder
    private func apiKeySection(
        title: String,
        placeholder: String,
        key: Binding<String>,
        savedMessage: Binding<String?>,
        footer: String,
        onSave: @escaping () -> Void
    ) -> some View {
        Section {
            SecureField(placeholder, text: key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("保存する") {
                onSave()
                savedMessage.wrappedValue = "保存しました"
            }
            if let message = savedMessage.wrappedValue {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
