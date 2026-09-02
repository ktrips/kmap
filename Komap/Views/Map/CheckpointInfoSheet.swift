import SwiftData
import SwiftUI

/// チェックポイント（史跡・御朱印の場所）マーカー上の小さなアイコンボタンをタップした時に
/// 表示する、その地域にまつわる情報シート。
///
/// `StorySheetView`と異なり「自分のマップに保存する」操作は持たない。
/// チェックポイントは誰の地図上でも同じ位置に表示される共有のポイントなので、
/// ここではその場所にまつわる情報をさりげなく見せるだけにとどめる。
///
/// 一度AIが生成した物語は`CheckpointStory`として端末に保存し、次に同じ
/// チェックポイントを開いた時はそれを表示するだけにする（AIへ何度も
/// 問い合わせないようにするため）。ユーザーが「AIで更新する」を選んだ時だけ
/// 作り直し、「編集する」で手動で書き換えることもできる。
struct CheckpointInfoSheet: View {
    let site: HistoricSite
    let overlayMap: HistoricalOverlayMap?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isLoading = true
    @State private var storyTitle: String = ""
    @State private var storyBody: String = ""
    @State private var isManuallyEdited = false
    @State private var errorMessage: String?
    @State private var isEditing = false

    private let service = AIHistoryService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if isLoading {
                        loadingView
                    } else if let errorMessage {
                        errorView(errorMessage)
                    } else {
                        storyView
                    }
                }
                .padding()
            }
            .navigationTitle(site.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                if !isLoading && errorMessage == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                isEditing = true
                            } label: {
                                Label("編集する", systemImage: "pencil")
                            }
                            Button {
                                Task { await regenerate() }
                            } label: {
                                Label("AIで更新する", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .task {
            await loadStory()
        }
        .sheet(isPresented: $isEditing) {
            CheckpointStoryEditView(title: storyTitle, bodyText: storyBody) { newTitle, newBody in
                save(title: newTitle, body: newBody, isManuallyEdited: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(overlayMap?.era ?? "江戸時代", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.bold())
                .foregroundStyle(.brown)
            Text(site.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("AIが昔の出来事を紐解いています…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .foregroundStyle(.red)
            Button("もう一度試す") {
                Task { await loadStory() }
            }
        }
    }

    private var storyView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(storyTitle)
                .font(.title3.bold())
            Text(storyBody)
                .font(.body)
                .lineSpacing(4)
            if isManuallyEdited {
                Label("手動で編集済み", systemImage: "pencil.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 保存済みの物語があればそれを使い、無ければAIに生成してもらってから保存する。
    private func loadStory() async {
        isLoading = true
        errorMessage = nil

        if let existing = fetchSavedStory() {
            storyTitle = existing.title
            storyBody = existing.body
            isManuallyEdited = existing.isManuallyEdited
            isLoading = false
            return
        }

        do {
            let story = try await service.generateStory(
                for: site.coordinate,
                overlayMap: overlayMap,
                placeName: site.name
            )
            save(title: story.title, body: story.body, isManuallyEdited: false)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// 「AIで更新する」が選ばれた時だけ、保存済みの内容があっても作り直す。
    private func regenerate() async {
        isLoading = true
        errorMessage = nil
        do {
            let story = try await service.generateStory(
                for: site.coordinate,
                overlayMap: overlayMap,
                placeName: site.name
            )
            save(title: story.title, body: story.body, isManuallyEdited: false)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchSavedStory() -> CheckpointStory? {
        let siteID = site.id
        let descriptor = FetchDescriptor<CheckpointStory>(
            predicate: #Predicate { $0.siteID == siteID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func save(title newTitle: String, body newBody: String, isManuallyEdited manuallyEdited: Bool) {
        storyTitle = newTitle
        storyBody = newBody
        isManuallyEdited = manuallyEdited

        if let existing = fetchSavedStory() {
            existing.title = newTitle
            existing.body = newBody
            existing.isManuallyEdited = manuallyEdited
            existing.updatedAt = Date()
        } else {
            let story = CheckpointStory(
                siteID: site.id,
                title: newTitle,
                body: newBody,
                isManuallyEdited: manuallyEdited
            )
            modelContext.insert(story)
        }
    }
}

/// チェックポイントの物語を手動で書き換えるための、シンプルな編集フォーム。
private struct CheckpointStoryEditView: View {
    @State var title: String
    @State var bodyText: String
    var onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("タイトル", text: $title)
                }
                Section("本文") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("編集する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(title, bodyText)
                        dismiss()
                    }
                    .disabled(title.isEmpty || bodyText.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CheckpointInfoSheet(
        site: HistoricSiteCatalog.all[0],
        overlayMap: OldMapCatalog.edoCastle
    )
    .modelContainer(for: [CheckpointStory.self], inMemory: true)
}
