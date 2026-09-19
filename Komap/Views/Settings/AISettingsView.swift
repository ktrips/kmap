import SwiftUI

/// 「AI設定」（物語生成に使うAIプロバイダーとAPIキー、新しい地図の追加、Google Mapsの設定状況）をまとめた画面。
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
    @State private var allowAddingNewMapContent: Bool = AppSettings.allowAddingNewMapContent

    var body: some View {
        Form {
            providerSection
            allowAddingNewMapContentSection
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
            googleMapsSection
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
            Text("物語・旅日記の生成に使うAIプロバイダーです。既定はOpenAIです。ポイントの説明や旅日記などを作る時、ここで選んだプロバイダーのAPIキーが必要と案内します。")
        }
    }

    private var allowAddingNewMapContentSection: some View {
        Section {
            Toggle("新しい地図を追加", isOn: $allowAddingNewMapContent)
                .onChange(of: allowAddingNewMapContent) { _, newValue in
                    AppSettings.allowAddingNewMapContent = newValue
                }
        } footer: {
            Text("オンの間だけ、古地図選択の「新しい地図を追加」が使えます。古地図の検索・作成には、デフォルトのAIプロバイダー（\(aiProvider.title)）のAPIキーが必要です（画像は国立国会図書館とWikimedia Commonsから探すため、検索用のキーは不要です）。AIのAPIを呼び出すため、意図しない利用を防ぐため既定はオフです。追加した古地図のポイントの追加・削除は、一覧の各古地図の右にある編集ボタンから行えます。")
        }
    }

    private var googleMapsSection: some View {
        Section {
            LabeledContent("APIキー設定状況") {
                Text(SecretsConfig.isGoogleMapsAPIKeyConfigured ? "設定済み" : "未設定")
                    .foregroundStyle(SecretsConfig.isGoogleMapsAPIKeyConfigured ? .green : .red)
            }
        } header: {
            Text("Google Maps")
        } footer: {
            Text("Google MapsのAPIキーはビルド時に Config/Secrets.xcconfig から読み込まれます。変更した場合は再ビルドが必要です。")
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
