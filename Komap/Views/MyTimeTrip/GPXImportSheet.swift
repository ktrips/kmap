import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 「マイ時空旅」の「後から旅を追加」から開く、GPXファイルの取り込みシート。
/// GPSでリアルタイムに記録する通常の「スタート」フローとは別に、スマートウォッチや
/// 他アプリで記録済みのGPXファイルの軌跡を、選んだ古地図と組み合わせて
/// `WalkRoute`として後から追加できるようにする。
struct GPXImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService

    @State private var selectedOverlayID: String = OldMapCatalog.defaultOverlay.id
    @State private var isPresentingFileImporter = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importedFileName: String?

    private let syncService = SyncService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("古地図", selection: $selectedOverlayID) {
                        ForEach(OldMapCatalog.all) { overlay in
                            Text(overlay.title).tag(overlay.id)
                        }
                    }
                } header: {
                    Text("使った古地図")
                } footer: {
                    Text("その時に歩いていた（歩いていたことにしたい）古地図を選んでください。")
                }

                Section {
                    Button {
                        isPresentingFileImporter = true
                    } label: {
                        if isImporting {
                            HStack {
                                ProgressView()
                                Text("読み込み中…")
                            }
                        } else {
                            Label(importedFileName ?? "GPXファイルを選ぶ", systemImage: "doc.badge.plus")
                        }
                    }
                    .disabled(isImporting)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("GPXファイル")
                } footer: {
                    Text("スマートウォッチや他のアプリで記録したGPXファイル（.gpx）を選ぶと、軌跡を読み取ってすぐに時空旅として追加されます。GPXに日時の記録があれば、その開始・終了日時をそのまま使います。")
                }
            }
            .navigationTitle("後から旅を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isPresentingFileImporter,
                allowedContentTypes: [gpxContentType],
                onCompletion: handleFileImport
            )
        }
    }

    private var gpxContentType: UTType {
        UTType(filenameExtension: "gpx") ?? .xml
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = "ファイルを開けませんでした: \(error.localizedDescription)"
        case .success(let url):
            importedFileName = url.lastPathComponent
            importGPX(from: url)
        }
    }

    private func importGPX(from url: URL) {
        errorMessage = nil
        isImporting = true
        Task {
            defer { isImporting = false }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let parsed = try GPXParser.parse(data: data)
                await save(parsed)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "GPXファイルを読み取れませんでした: \(error.localizedDescription)"
            }
        }
    }

    private func save(_ parsed: GPXParser.ParsedTrack) async {
        let startedAt = parsed.startedAt ?? Date()
        let endedAt = parsed.endedAt ?? startedAt
        let route = WalkRoute(
            coordinates: parsed.coordinates,
            startedAt: startedAt,
            endedAt: endedAt,
            overlayMapID: selectedOverlayID,
            overlayOpacity: MapSessionState.defaultOverlayOpacity
        )
        modelContext.insert(route)
        try? modelContext.save()

        if let userID = authService.userID {
            try? await syncService.upload(route, userID: userID)
        }

        dismiss()
    }
}

#Preview {
    GPXImportSheet()
        .environmentObject(AuthService())
        .modelContainer(for: [WalkRoute.self], inMemory: true)
}
