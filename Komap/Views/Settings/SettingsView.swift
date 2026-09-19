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
    @State private var defaultOverlayMapID: String? = OldMapCatalog.defaultOverlay.id
    @State private var photoFilterStyle: PhotoFilterStyle = AppSettings.photoFilterStyle
    @State private var currentLocationIconStyle: CurrentLocationIconStyle = AppSettings.currentLocationIconStyle
    @State private var autoPauseWhenStationary: Bool = AppSettings.autoPauseWhenStationary
    @State private var stationaryAutoPauseMinutes: Int = AppSettings.stationaryAutoPauseMinutes


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
                recordingSafetySection
                currentLocationIconSection
                photoFilterSection

                Section {
                    Text("Komap 古地図巡りは、現在の地図に古地図を重ね合わせて、歩いている場所の「昔の姿」をAIの解説とともに旅できるアプリです。古地図はサンプルの位置合わせデータです。実際の史料に基づく正確な位置合わせではありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link(destination: URL(string: "https://github.com/ktrips/kmap#readme")!) {
                        Label("Komapの使い方", systemImage: "book")
                    }
                    Link(destination: URL(string: "https://link.amazon/B006awnVi")!) {
                        Label("Komapの作り方 Kindle本", systemImage: "book.closed")
                    }
                } header: {
                    HStack {
                        Text("このアプリについて")
                        Spacer()
                        Text("（バージョン \(Self.appVersionText)）")
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
                HStack {
                    Text("サインイン中：\(authService.displayName ?? "アカウント")")
                        .font(.subheadline)
                    Spacer()
                    Button("サインアウト", role: .destructive) {
                        authService.signOut()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
                Text("Googleでサインインすると、保存した地点・私の時空旅（歩いたルート）がクラウドへ同期され、Googleアカウントでログインした際に見られるようになります。")

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
            Picker("最初に表示する古地図", selection: $defaultOverlayMapID) {
                ForEach(OldMapCatalog.all) { overlay in
                    Text(overlay.title).tag(overlay.id as String?)
                }
            }
            .onChange(of: defaultOverlayMapID) { _, newValue in
                AppSettings.defaultOverlayMapID = newValue
            }

            HStack(spacing: 10) {
                Slider(
                    value: $defaultOverlayOpacity,
                    in: 0...1,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            mapSession.updateDefaultOverlayOpacity(defaultOverlayOpacity)
                        }
                    }
                )
                Text("\(Int(defaultOverlayOpacity * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        } header: {
            Text("古地図のデフォルト")
        } footer: {
            Text("マップ画面下部のスライダーでその場で変えた濃度は、ここでは変わりません。")
        }
    }

    private var recordingSafetySection: some View {
        Section {
            Toggle("動きがない時に自動で一時停止", isOn: $autoPauseWhenStationary)
                .onChange(of: autoPauseWhenStationary) { _, newValue in
                    AppSettings.autoPauseWhenStationary = newValue
                }
            if autoPauseWhenStationary {
                Picker("一時停止までの時間", selection: $stationaryAutoPauseMinutes) {
                    ForEach([1, 5, 10, 20], id: \.self) { minutes in
                        Text("\(minutes)分").tag(minutes)
                    }
                }
                .onChange(of: stationaryAutoPauseMinutes) { _, newValue in
                    AppSettings.stationaryAutoPauseMinutes = newValue
                }
            }
        } header: {
            Text("記録の自動制御")
        } footer: {
            Text("気づかずGPSが回りっぱなしにならないよう、動きがなくなると自動で一時停止し（動き出すと再開）、8時間で自動終了します。")
        }
    }

    private var currentLocationIconSection: some View {
        Section {
            HStack(spacing: 18) {
                ForEach(CurrentLocationIconStyle.allCases) { style in
                    Button {
                        currentLocationIconStyle = style
                        AppSettings.currentLocationIconStyle = style
                    } label: {
                        VStack(spacing: 6) {
                            Image(uiImage: style.icon(emphasized: false))
                                .padding(6)
                                .background(
                                    Circle().stroke(
                                        currentLocationIconStyle == style ? Color.accentColor : Color.clear,
                                        lineWidth: 2
                                    )
                                )
                            Text(style.title)
                                .font(.caption2)
                                .foregroundStyle(currentLocationIconStyle == style ? .primary : .secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        } header: {
            Text("現在地マークの見た目")
        } footer: {
            Text("歩いている時、地図上の自分の位置に表示するマークです。御朱印のマーカーは朱色のピンのため見分けられます。")
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
            Text("写真を撮影・追加するたびに、選んだ加工が自動で適用されます。")
        }
    }

    private var advancedSettingsSection: some View {
        Section {
            NavigationLink {
                AISettingsView()
            } label: {
                Label("AI設定", systemImage: "sparkles")
            }

            NavigationLink {
                LinkedDevicesSettingsView()
            } label: {
                Label("連携機能", systemImage: "network")
            }

            NavigationLink {
                AdminSettingsView()
            } label: {
                Label("管理者設定", systemImage: "gearshape.2")
            }
        } header: {
            Text("アドバンス設定")
        } footer: {
            Text("AI設定（OpenAI・Google・Anthropic）、カメラ・プリンター連携、管理者設定（Googleカスタム検索・Google Maps）など。")
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
