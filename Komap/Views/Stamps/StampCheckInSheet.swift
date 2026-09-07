import PhotosUI
import SwiftData
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
    @State private var isPrintingToLinkedPrinter = false
    @State private var printMessage: String?
    /// `AppSettings.cameraLinkHost`と同じキーを`@AppStorage`で直接監視し、
    /// 「設定」画面での変更がこのシートにも即座に反映されるようにする
    /// （`MapScreen`側の同様の対応と揃えている）。
    @AppStorage("cameraLinkHost") private var cameraLinkHostRaw: String = ""

    @State private var isLoadingStory = true
    @State private var story: GeneratedStory?
    @State private var storyErrorMessage: String?

    private let historyService = AIHistoryService()
    private let syncService = SyncService()

    private var isCameraLinkConfigured: Bool {
        !cameraLinkHostRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

                    if stamp.photo != nil && AppSettings.printerLinkHost != nil {
                        Button {
                            Task { await printToLinkedPrinter() }
                        } label: {
                            if isPrintingToLinkedPrinter {
                                ProgressView()
                            } else {
                                Label("連携プリント", systemImage: "printer.fill")
                            }
                        }
                        .disabled(isPrintingToLinkedPrinter)
                    }

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

                    if let printMessage {
                        Text(printMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

            if isCameraLinkConfigured {
                Button {
                    Task { await captureFromLinkedCamera() }
                } label: {
                    Label("連携カメラで撮る", systemImage: "network")
                }
                .disabled(isLoadingPhoto)
            }
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

    /// 「連携プリント」ボタンから、この御朱印の写真をその場で連携プリンターへ転送する。
    private func printToLinkedPrinter() async {
        guard let photo = stamp.photo else { return }
        isPrintingToLinkedPrinter = true
        printMessage = nil
        defer { isPrintingToLinkedPrinter = false }
        do {
            try await PrinterLinkService().printOnDemand(photo, cloudURL: stamp.cloudPhotoURL.flatMap(URL.init))
            printMessage = "連携プリンターへ送信しました"
        } catch {
            printMessage = error.localizedDescription
        }
    }

    /// 連携カメラのURLに写真を撮ってもらい、この御朱印の写真として取り込む。
    private func captureFromLinkedCamera() async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            let image = try await CameraLinkService().fetchLatestPhoto()
            applyPhotoUpdate(image)
        } catch {
            photoSyncErrorMessage = error.localizedDescription
        }
    }

    /// 写真を差し替える。「設定」で選んだ加工を適用し、連携プリンターが設定されていれば
    /// そちらへも転送してから、Firebaseが設定済みでサインイン中ならクラウドにも
    /// （スマホできれいに見える範囲まで圧縮して）アップロードする。
    private func applyPhotoUpdate(_ rawImage: UIImage?) {
        let image = rawImage.map { AppSettings.photoFilterStyle.apply(to: $0) }
        let previousStamp = stamp
        Task { await syncService.deleteStampPhoto(previousStamp, userID: authService.userID) }
        stamp.updatePhoto(image)
        try? modelContext.save()
        photoSyncErrorMessage = nil

        if let image {
            Task { await PrinterLinkService().printStampPhotoIfEnabled(image) }
        }

        guard let userID = authService.userID else { return }
        guard let image else {
            // 写真を削除した場合も、クラウド側の削除が終わってから公開データに反映する。
            Task {
                await resyncSharedTripIfNeeded()
            }
            return
        }
        Task {
            do {
                try await syncService.uploadStampPhoto(stamp, userID: userID)
                try? modelContext.save()
                await resyncSharedTripIfNeeded()
            } catch {
                // 端末には保存済みだが、Webでも見られるようにするアップロードには失敗した。
                photoSyncErrorMessage = "写真をWebでも見られるようにする処理に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    /// この御朱印が属する時間旅が既に「みんなの時空旅」に公開済みなら、
    /// 今追加・変更した写真を公開データにも反映する。
    private func resyncSharedTripIfNeeded() async {
        guard let walkRouteID = stamp.walkRouteID else { return }
        let routeDescriptor = FetchDescriptor<WalkRoute>(predicate: #Predicate { $0.id == walkRouteID })
        guard let route = try? modelContext.fetch(routeDescriptor).first, route.isSharedPublicly else { return }

        let stampsDescriptor = FetchDescriptor<CollectedStamp>(predicate: #Predicate { $0.walkRouteID == walkRouteID })
        let postsDescriptor = FetchDescriptor<WalkPhotoPost>(predicate: #Predicate { $0.walkRouteID == walkRouteID })
        let stamps = (try? modelContext.fetch(stampsDescriptor)) ?? []
        let photoPosts = (try? modelContext.fetch(postsDescriptor)) ?? []

        await syncService.resyncSharedTripIfNeeded(
            route,
            userID: authService.userID,
            ownerDisplayName: authService.displayName,
            stamps: stamps,
            photoPosts: photoPosts
        )
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
