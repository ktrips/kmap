import SwiftData
import SwiftUI

/// アカウント連携・写真の加工・外部機器連携・アドバンス設定（APIキー類）をまとめた設定画面。
struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var mapSession: MapSessionState
    @Environment(\.modelContext) private var modelContext

    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var defaultOverlayOpacity: Double = MapSessionState.defaultOverlayOpacity
    @State private var photoFilterStyle: PhotoFilterStyle = AppSettings.photoFilterStyle

    @State private var isShowingAdvancedSettings = false
    @State private var openAIKey: String = SecretsConfig.openAIAPIKey ?? ""
    @State private var savedMessage: String?
    @State private var customSearchAPIKey: String = SecretsConfig.googleCustomSearchAPIKey ?? ""
    @State private var customSearchEngineID: String = SecretsConfig.googleCustomSearchEngineID ?? ""
    @State private var customSearchSavedMessage: String?

    private let syncService = SyncService()

    /// `MARKETING_VERSION`（例: "1.0"）と`CURRENT_PROJECT_VERSION`（ビルド番号、例: "22"）から
    /// 「1.0 (22)」のような表示用文字列を作る。project.ymlのデフォルト値ではなく、
    /// 実際にアーカイブ・配布されたビルドのInfo.plistから読むため、常に実態と一致する。
    private static var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "?"
        return "\(shortVersion) (\(buildNumber))"
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                overlayOpacitySection
                photoFilterSection

                Section("このアプリについて") {
                    Text("Komap 古地図巡りは、現在の地図に古地図を重ね合わせて、歩いている場所の「昔の姿」をAIの解説とともに旅できるアプリです。同梱の古地図はサンプルの位置合わせデータです。実際の史料に基づく正確な位置合わせではありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("バージョン", value: Self.appVersionText)
                    Link(destination: URL(string: "https://github.com/ktrips/kmap#readme")!) {
                        Label("Komapの使い方", systemImage: "book")
                    }
                }

                advancedSettingsSection
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        mapSession.selectedTab = .map
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                            Text("マップに戻る")
                        }
                    }
                }
            }
            .onChange(of: authService.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    Task { await pullFromCloud() }
                }
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if !authService.isFirebaseConfigured {
                Text("Firebaseが未設定のため、Web（map.ktrips.net）との同期は利用できません。READMEの手順に沿ってFirebaseを設定してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if authService.isSignedIn {
                LabeledContent("サインイン中") {
                    Text(authService.displayName ?? "アカウント")
                }

                Button("サインアウト", role: .destructive) {
                    authService.signOut()
                }
            } else {
                Button {
                    Task { await authService.signInWithGoogle() }
                } label: {
                    if authService.isSigningIn {
                        ProgressView()
                    } else {
                        Label("Googleでサインイン", systemImage: "g.circle.fill")
                    }
                }
                .disabled(authService.isSigningIn)

                if let error = authService.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("アカウント / Web連携")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Googleでサインインすると、保存した地点・私の時空旅（歩いたルート）が新しく記録するたびにクラウドへ同期され、Webアプリで同じGoogleアカウントでログインした際に「My Trips」として見られるようになります。")

                if authService.isSignedIn {
                    Group {
                        if isSyncing {
                            Text("サインインより前に記録していたものを同期しています…")
                        } else {
                            Text("サインインより前に記録していたものは、")
                                + Text("保存済みの地点・私の時空旅をすべてクラウドに同期")
                                    .foregroundStyle(.blue)
                                    .underline()
                                + Text("してください。")
                        }
                    }
                    .onTapGesture {
                        guard !isSyncing else { return }
                        Task { await syncAllToCloud() }
                    }

                    if let syncMessage {
                        Text(syncMessage)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private var overlayOpacitySection: some View {
        Section {
            HStack(spacing: 10) {
                Text("現在")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Slider(
                    value: $defaultOverlayOpacity,
                    in: 0...1,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            mapSession.updateDefaultOverlayOpacity(defaultOverlayOpacity)
                        }
                    }
                )
                Text("古地図")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Text("\(Int(defaultOverlayOpacity * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("古地図のデフォルト濃度")
        } footer: {
            Text("マップ画面で古地図を選んだ時に最初から使われる濃度です。マップ画面下部のスライダーでその場で変えた濃度は、ここでは変わりません。")
        }
    }

    private var photoFilterSection: some View {
        Section {
            Picker("写真の加工", selection: $photoFilterStyle) {
                ForEach(PhotoFilterStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: photoFilterStyle) { _, newValue in
                AppSettings.photoFilterStyle = newValue
            }
        } header: {
            Text("写真の加工")
        } footer: {
            Text("御朱印・投稿写真を撮影・追加するたびに、選んだ加工が自動で適用されます。")
        }
    }

    @ViewBuilder
    private var advancedSettingsSection: some View {
        Section {
            DisclosureGroup("アドバンス設定を表示", isExpanded: $isShowingAdvancedSettings) {
                NavigationLink {
                    LinkedDevicesSettingsView()
                } label: {
                    Label("連携機能", systemImage: "network")
                }
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text("OpenAI APIキー")
                        .font(.subheadline.bold())
                    SecureField("sk-...", text: $openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("保存する") {
                        SecretsConfig.saveOpenAIAPIKey(openAIKey)
                        savedMessage = "保存しました"
                    }
                    if let savedMessage {
                        Text(savedMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Text("地点をタップした際にAIが昔の物語を生成するために使用します。キーはこの端末のKeychainに安全に保存され、外部には送信されません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Googleカスタム検索（古地図検索用）")
                        .font(.subheadline.bold())
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
                    Text("マップ画面の「古地図を選択」から新しい古地図をWeb検索して追加する機能で使用します。両方設定するとメニューに追加項目が表示されます。APIキーはCloud Console、検索エンジンIDはProgrammable Search Engineで取得できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Google Maps")
                        .font(.subheadline.bold())
                    LabeledContent("APIキー設定状況") {
                        Text(SecretsConfig.isGoogleMapsAPIKeyConfigured ? "設定済み" : "未設定")
                            .foregroundStyle(SecretsConfig.isGoogleMapsAPIKeyConfigured ? .green : .red)
                    }
                    Text("Google MapsのAPIキーはビルド時に Config/Secrets.xcconfig から読み込まれます。変更した場合は再ビルドが必要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("アドバンス設定")
        } footer: {
            Text("カメラ・プリンター連携、OpenAI・Googleカスタム検索・Google MapsのAPIキーなど、通常は初回セットアップ時にしか使わない項目をまとめています。")
        }
    }

    private func syncAllToCloud() async {
        guard let userID = authService.userID else { return }
        isSyncing = true
        syncMessage = nil
        do {
            let places = try modelContext.fetch(FetchDescriptor<SavedPlace>())
            for place in places {
                try await syncService.upload(place, userID: userID)
            }
            let walkRoutes = try modelContext.fetch(FetchDescriptor<WalkRoute>())
            for route in walkRoutes {
                try await syncService.upload(route, userID: userID)
            }
            syncMessage = "地点\(places.count)件・時空旅\(walkRoutes.count)件を同期しました"
        } catch {
            syncMessage = "同期に失敗しました: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    /// サインイン直後に、クラウド側にだけある地点（他の端末やWebから同期されたもの）を
    /// ローカルにも取り込む。
    private func pullFromCloud() async {
        guard let userID = authService.userID else { return }
        do {
            let localPlaces = try modelContext.fetch(FetchDescriptor<SavedPlace>())
            let localIDs = Set(localPlaces.map(\.id))

            let remotePlaces = try await syncService.fetchAll(userID: userID)
            for remote in remotePlaces {
                guard let remoteUUID = UUID(uuidString: remote.id), !localIDs.contains(remoteUUID) else { continue }
                let place = SavedPlace(
                    id: remoteUUID,
                    title: remote.title,
                    latitude: remote.latitude,
                    longitude: remote.longitude,
                    overlayMapID: remote.overlayMapID,
                    era: remote.era,
                    storyText: remote.storyText,
                    createdAt: remote.createdAt
                )
                modelContext.insert(place)
            }

            let localStamps = try modelContext.fetch(FetchDescriptor<CollectedStamp>())
            let localStampIDs = Set(localStamps.map(\.id))
            let remoteStamps = try await syncService.fetchAllStamps(userID: userID)
            for remote in remoteStamps {
                guard let remoteUUID = UUID(uuidString: remote.id), !localStampIDs.contains(remoteUUID) else { continue }
                modelContext.insert(CollectedStamp(id: remoteUUID, siteID: remote.siteID, collectedAt: remote.collectedAt))
            }
        } catch {
            syncMessage = "クラウドからの取得に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
        .modelContainer(for: SavedPlace.self, inMemory: true)
}
