import SwiftUI

/// 「みんなの時空旅」右上の「友達を招待」から開く、友達招待・招待状況の管理シート。
/// メールアドレス指定（相手が未サインインでもよい）、またはユーザー名（表示名）の
/// 前方一致検索のどちらでも友達申請を送れる。届いた申請の承認・却下もここで行う。
struct InviteFriendSheet: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var queryText = ""
    @State private var searchResults: [RemoteUserStats] = []
    @State private var isSearching = false
    @State private var requests: [RemoteFriendRequest] = []
    @State private var isLoadingRequests = true
    @State private var statusMessage: String?
    @State private var sentToUIDs: Set<String> = []

    private let syncService = SyncService()

    private var isEmailQuery: Bool {
        queryText.contains("@")
    }

    private var incomingPending: [RemoteFriendRequest] {
        guard let myUID = authService.userID else { return [] }
        return requests.filter { $0.toUID == myUID && $0.status == .pending }
    }

    private var outgoingPending: [RemoteFriendRequest] {
        guard let myUID = authService.userID else { return [] }
        return requests.filter { $0.fromUID == myUID && $0.status == .pending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("メールアドレス、またはユーザー名", text: $queryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: queryText) { _, newValue in
                            Task { await search(newValue) }
                        }

                    if isEmailQuery {
                        Button {
                            Task { await sendByEmail() }
                        } label: {
                            Label("このメールアドレスに招待を送る", systemImage: "envelope")
                        }
                        .disabled(!isLikelyEmail(queryText))
                    } else if isSearching {
                        HStack {
                            ProgressView()
                            Text("検索中…")
                                .foregroundStyle(.secondary)
                        }
                    } else if !queryText.isEmpty && searchResults.isEmpty {
                        Text("該当するユーザー名が見つかりませんでした。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(searchResults) { user in
                        searchResultRow(user)
                    }
                } header: {
                    Text("友達を招待")
                } footer: {
                    Text("メールアドレスで招待すると、相手がまだこのアプリでサインインしていなくても、後でサインインした時に招待が届きます。")
                }

                if !incomingPending.isEmpty {
                    Section("届いている招待") {
                        ForEach(incomingPending) { request in
                            incomingRequestRow(request)
                        }
                    }
                }

                if !outgoingPending.isEmpty {
                    Section("送った招待") {
                        ForEach(outgoingPending) { request in
                            outgoingRequestRow(request)
                        }
                    }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("友達を招待")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await loadRequests()
            }
        }
    }

    private func searchResultRow(_ user: RemoteUserStats) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline.bold())
                Text("通算 \(user.totalPoints) pt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if sentToUIDs.contains(user.id) {
                Text("申請済み")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if user.id == authService.userID {
                Text("自分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("申請") {
                    Task { await send(toUID: user.id) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private func incomingRequestRow(_ request: RemoteFriendRequest) -> some View {
        HStack {
            Text(request.fromDisplayName)
                .font(.subheadline.bold())
            Spacer()
            Button("承認") {
                Task { await accept(request) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button("却下") {
                Task { await decline(request) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func outgoingRequestRow(_ request: RemoteFriendRequest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.toEmail ?? "ユーザーへ申請中")
                    .font(.subheadline)
                Text("返事を待っています")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("取消") {
                Task { await cancel(request) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func isLikelyEmail(_ text: String) -> Bool {
        text.contains("@") && text.contains(".") && !text.hasPrefix("@") && !text.hasSuffix("@")
    }

    private func search(_ text: String) async {
        guard !text.isEmpty, !text.contains("@") else {
            searchResults = []
            return
        }
        isSearching = true
        searchResults = (try? await syncService.searchUsers(displayNamePrefix: text)) ?? []
        isSearching = false
    }

    private func loadRequests() async {
        isLoadingRequests = true
        if let myUID = authService.userID {
            requests = (try? await syncService.fetchFriendRequests(userID: myUID)) ?? []
        }
        isLoadingRequests = false
    }

    private func send(toUID: String) async {
        guard let myUID = authService.userID else { return }
        let displayName = authService.displayName ?? "ユーザー"
        do {
            try await syncService.sendFriendRequest(fromUID: myUID, fromDisplayName: displayName, toUID: toUID)
            sentToUIDs.insert(toUID)
            statusMessage = "招待を送りました。"
        } catch {
            statusMessage = "招待を送れませんでした: \(error.localizedDescription)"
        }
    }

    private func sendByEmail() async {
        guard let myUID = authService.userID, isLikelyEmail(queryText) else { return }
        let displayName = authService.displayName ?? "ユーザー"
        do {
            try await syncService.sendFriendRequest(fromUID: myUID, fromDisplayName: displayName, toEmail: queryText)
            statusMessage = "\(queryText) に招待を送りました。"
            queryText = ""
            await loadRequests()
        } catch {
            statusMessage = "招待を送れませんでした: \(error.localizedDescription)"
        }
    }

    private func accept(_ request: RemoteFriendRequest) async {
        guard let myUID = authService.userID else { return }
        do {
            try await syncService.acceptFriendRequest(request, myUID: myUID)
            await loadRequests()
        } catch {
            statusMessage = "承認できませんでした: \(error.localizedDescription)"
        }
    }

    private func decline(_ request: RemoteFriendRequest) async {
        try? await syncService.declineFriendRequest(request)
        await loadRequests()
    }

    private func cancel(_ request: RemoteFriendRequest) async {
        try? await syncService.cancelFriendRequest(request)
        await loadRequests()
    }
}

#Preview {
    InviteFriendSheet()
        .environmentObject(AuthService())
}
