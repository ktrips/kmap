import SwiftData
import SwiftUI

/// OpenAIのAPIキー入力・Googleサインイン・古地図データなど、アプリの設定を行う画面。
struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext

    @State private var openAIKey: String = SecretsConfig.openAIAPIKey ?? ""
    @State private var savedMessage: String?
    @State private var customSearchAPIKey: String = SecretsConfig.googleCustomSearchAPIKey ?? ""
    @State private var customSearchEngineID: String = SecretsConfig.googleCustomSearchEngineID ?? ""
    @State private var customSearchSavedMessage: String?
    @State private var isSyncing = false
    @State private var syncMessage: String?

    private let syncService = SyncService()

    var body: some View {
        NavigationStack {
            Form {
                accountSection

                Section {
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
                } header: {
                    Text("OpenAI APIキー")
                } footer: {
                    Text("地点をタップした際にAIが昔の物語を生成するために使用します。キーはこの端末のKeychainに安全に保存され、外部には送信されません。")
                }

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

                Section("Google Maps") {
                    LabeledContent("APIキー設定状況") {
                        Text(SecretsConfig.isGoogleMapsAPIKeyConfigured ? "設定済み" : "未設定")
                            .foregroundStyle(SecretsConfig.isGoogleMapsAPIKeyConfigured ? .green : .red)
                    }
                    Text("Google MapsのAPIキーはビルド時に Config/Secrets.xcconfig から読み込まれます。変更した場合は再ビルドが必要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("このアプリについて") {
                    Text("Komap 古地図巡りは、現在の地図に古地図を重ね合わせて、歩いている場所の「昔の姿」をAIの解説とともに旅できるアプリです。同梱の古地図はサンプルの位置合わせデータです。実際の史料に基づく正確な位置合わせではありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
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
                Button {
                    Task { await syncAllToCloud() }
                } label: {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Label("保存済みの地点・私の時空旅をすべてクラウドに同期", systemImage: "icloud.and.arrow.up")
                    }
                }
                .disabled(isSyncing)

                if let syncMessage {
                    Text(syncMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
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
            Text("Googleでサインインすると、保存した地点・私の時空旅（歩いたルート）が新しく記録するたびにクラウドへ同期され、Webアプリで同じGoogleアカウントでログインした際に「My Trips」として見られるようになります。サインインより前に記録していたものは、上のボタンでまとめて同期してください。")
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
