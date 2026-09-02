import PhotosUI
import SwiftUI

/// 御朱印を獲得した直後、または御朱印帳から後で開いた時に、
/// その史跡の写真を追加・変更でき、場所の詳細も見られるシート。
struct StampCheckInSheet: View {
    let site: HistoricSite
    @Bindable var stamp: CollectedStamp

    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isShowingCamera = false
    /// クラウド（Webでも見られるようにするため）へのアップロードに失敗した時のメッセージ。
    /// 失敗しても端末には保存されているが、原因がわかるよう表示しておく。
    @State private var photoSyncErrorMessage: String?

    @State private var isLoadingStory = true
    @State private var story: GeneratedStory?
    @State private var storyErrorMessage: String?

    private let historyService = AIHistoryService()
    private let syncService = SyncService()

    private var overlayMap: HistoricalOverlayMap? {
        OldMapCatalog.allIncludingCustom.first { $0.id == site.overlayMapID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                        Text(site.name)
                            .font(.title2.bold())
                        Text(site.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let photo = stamp.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    photoButtons

                    if stamp.photo != nil {
                        Button("写真を削除", role: .destructive) {
                            applyPhotoUpdate(nil)
                        }
                    }

                    if let photoSyncErrorMessage {
                        Text(photoSyncErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Divider()

                    detailSection
                }
                .padding()
            }
            .navigationTitle("チェックイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: photosPickerItem) { _, newItem in
                loadPickedPhoto(newItem)
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraCaptureView(
                    onCapture: { image in
                        isShowingCamera = false
                        applyPhotoUpdate(image)
                    },
                    onCancel: { isShowingCamera = false }
                )
                .ignoresSafeArea()
            }
        }
        .task {
            await loadStoryIfNeeded()
        }
    }

    private var photoButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                if isLoadingPhoto {
                    ProgressView()
                } else {
                    Label(stamp.photo == nil ? "写真を追加" : "写真を変更", systemImage: "photo.on.rectangle")
                }
            }
            .disabled(isLoadingPhoto)

            Button {
                isShowingCamera = true
            } label: {
                Label("カメラで撮る", systemImage: "camera.fill")
            }
            .disabled(isLoadingPhoto)
        }
    }

    /// 場所の詳細（由来やエピソード）をAIで補足する。
    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("この場所の詳細", systemImage: "text.book.closed.fill")
                .font(.headline)
                .foregroundStyle(.brown)

            if isLoadingStory {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("AIが昔の出来事を紐解いています…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let storyErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(storyErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("もう一度試す") {
                        Task { await loadStoryIfNeeded(force: true) }
                    }
                }
            } else if let story {
                VStack(alignment: .leading, spacing: 8) {
                    Text(story.title)
                        .font(.subheadline.bold())
                    Text(story.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingPhoto = true
        Task {
            defer { isLoadingPhoto = false }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else { return }
            applyPhotoUpdate(uiImage)
        }
    }

    /// 写真を差し替え、Firebaseが設定済みでサインイン中ならクラウドにも
    /// （スマホできれいに見える範囲まで圧縮して）アップロードする。
    private func applyPhotoUpdate(_ image: UIImage?) {
        let previousStamp = stamp
        Task { await syncService.deleteStampPhoto(previousStamp, userID: authService.userID) }
        stamp.updatePhoto(image)
        try? modelContext.save()
        photoSyncErrorMessage = nil

        guard image != nil, let userID = authService.userID else { return }
        Task {
            do {
                try await syncService.uploadStampPhoto(stamp, userID: userID)
                try? modelContext.save()
            } catch {
                // 端末には保存済みだが、Webでも見られるようにするアップロードには失敗した。
                photoSyncErrorMessage = "写真をWebでも見られるようにする処理に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private func loadStoryIfNeeded(force: Bool = false) async {
        guard force || story == nil else { return }
        isLoadingStory = true
        storyErrorMessage = nil
        do {
            story = try await historyService.generateStory(
                for: site.coordinate,
                overlayMap: overlayMap,
                placeName: site.name
            )
        } catch {
            storyErrorMessage = error.localizedDescription
        }
        isLoadingStory = false
    }
}
