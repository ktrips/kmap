import SwiftUI

/// みんなが公開した古地図の一覧。「追加する」で、画像・ポイントごと自分の古地図として取り込む。
struct SharedOverlayMapsView: View {
    /// 取り込んだ古地図を渡す（呼び出し側で、その地図を選択して閉じる等に使う）。
    var onImported: (HistoricalOverlayMap) -> Void

    @EnvironmentObject private var authService: AuthService
    @State private var maps: [RemoteOverlayMap] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var importingID: String?

    private let service = OverlayMapShareService()

    var body: some View {
        List {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("読み込み中…").foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else if maps.isEmpty {
                Text("まだ公開されている古地図はありません。").foregroundStyle(.secondary)
            }

            ForEach(maps) { remote in
                row(remote)
            }
        }
        .navigationTitle("みんなの古地図")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func row(_ remote: RemoteOverlayMap) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: remote.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Rectangle().fill(.quaternary).aspectRatio(1, contentMode: .fit).overlay(ProgressView())
            }
            .frame(maxHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(remote.title).font(.headline)
            Text(remote.era).font(.caption.bold()).foregroundStyle(.brown)
            if !remote.summary.isEmpty {
                Text(remote.summary).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("チェックポイント \(remote.checkpoints.count)件\(remote.ownerDisplayName.map { "・\($0)" } ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if remote.ownerUserID == authService.userID {
                    Text("自分の地図").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await importMap(remote) }
                    } label: {
                        if importingID == remote.id {
                            ProgressView()
                        } else {
                            Label("追加する", systemImage: "plus.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(importingID != nil)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            maps = try await service.fetchPublicMaps()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func importMap(_ remote: RemoteOverlayMap) async {
        importingID = remote.id
        defer { importingID = nil }
        do {
            if let overlay = try await service.importMap(remote) {
                onImported(overlay)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
