import SwiftUI

/// 「管理者設定」（Googleカスタム検索・Google Mapsまわりの設定）をまとめた画面。
/// 「設定」画面の「アドバンス設定」→「管理者設定」から開く。
struct AdminSettingsView: View {
    @State private var customSearchAPIKey: String = SecretsConfig.googleCustomSearchAPIKey ?? ""
    @State private var customSearchEngineID: String = SecretsConfig.googleCustomSearchEngineID ?? ""
    @State private var customSearchSavedMessage: String?
    @State private var allowAddingNewMapContent: Bool = AppSettings.allowAddingNewMapContent

    var body: some View {
        Form {
            allowAddingNewMapContentSection
            customSearchSection
            googleMapsSection
        }
        .navigationTitle("管理者設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var allowAddingNewMapContentSection: some View {
        Section {
            Toggle("新しい地図を追加", isOn: $allowAddingNewMapContent)
                .onChange(of: allowAddingNewMapContent) { _, newValue in
                    AppSettings.allowAddingNewMapContent = newValue
                }
        } footer: {
            Text("オンの間だけ、古地図選択の「新しい地図を追加」と、地図タップでAIが物語を生成して新しいポイントを追加する機能が使えます。どちらもAI・Web検索のAPIを呼び出すため、意図しない利用を防ぐため既定はオフです。")
        }
    }

    private var customSearchSection: some View {
        Section {
            SecureField("AIzaSy...", text: $customSearchAPIKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("検索エンジンID（cx）", text: $customSearchEngineID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("保存する") {
                SecretsConfig.saveGoogleCustomSearchAPIKey(customSearchAPIKey)
                SecretsConfig.saveGoogleCustomSearchEngineID(customSearchEngineID)
                customSearchSavedMessage = "保存しました"
            }
            if let customSearchSavedMessage {
                Text(customSearchSavedMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Googleカスタム検索（古地図検索用）")
        } footer: {
            Text("マップ画面の「古地図を選択」から新しい古地図をWeb検索して追加する機能で使用します。両方設定するとメニューに追加項目が表示されます。APIキーはCloud Console、検索エンジンIDはProgrammable Search Engineで取得できます。")
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
}

#Preview {
    NavigationStack {
        AdminSettingsView()
    }
}
