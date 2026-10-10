import PhotosUI
import SwiftData
import SwiftUI

/// 御朱印を獲得した直後、または御朱印帳から後で開いた時に、
/// その史跡の写真を追加・変更でき、場所の詳細も見られるシート。
struct StampCheckInSheet: View {
    let site: HistoricSite
    @Bindable var stamp: CollectedStamp

    init(site: HistoricSite, stamp: CollectedStamp) {
        self.site = site
        self.stamp = stamp
        let siteID = site.id
        _savedStories = Query(filter: #Predicate<CheckpointStory> { $0.siteID == siteID })
    }

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var plusStore: PlusStore
    /// Komap Plus の比較ページを開く理由（写真の追加・場所の詳細）。
    @State private var plusPaywallReason: PlusFeature?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingPhoto = false
    @State private var isShowingCamera = false
    @State private var isConfirmingDelete = false
    /// クラウド（Webでも見られるようにするため）へのアップロードに失敗した時のメッセージ。
    /// 失敗しても端末には保存されているが、原因がわかるよう表示しておく。
    @State private var photoSyncErrorMessage: String?
    @State private var isPrintingToLinkedPrinter = false
    @State private var printMessage: String?
    /// `AppSettings.cameraLinkHost`と同じキーを`@AppStorage`で直接監視し、
    /// 「設定」画面での変更がこのシートにも即座に反映されるようにする
    /// （`MapScreen`側の同様の対応と揃えている）。
    @AppStorage("cameraLinkHost") private var cameraLinkHostRaw: String = ""

    /// この史跡の説明（チェックイン・写真の追加の時点で`PointStoryAutoGenerator`が作って保存したもの）。
    @Query private var savedStories: [CheckpointStory]
    @ObservedObject private var pointStoryGenerator = PointStoryAutoGenerator.shared
    @State private var storyErrorMessage: String?

    private var story: CheckpointStory? { savedStories.first }
    private var isLoadingStory: Bool { pointStoryGenerator.generatingSiteIDs.contains(site.id) }
    private let syncService = SyncService()

    private var isCameraLinkConfigured: Bool {
        !cameraLinkHostRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var overlayMap: HistoricalOverlayMap? {
        OldMapCatalog.overlay(withID: site.overlayMapID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        if let crest = CrestBadgeCatalog.badge(for: site.id) {
                            Image(systemName: crest.symbolName)
                                .font(.system(size: 40))
                                .foregroundStyle(crest.tint)
                        } else {
                            Image(systemName: "seal.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                        }
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

                    PhotoDetailActionRow(
                        date: stamp.collectedAt,
                        hasPhoto: stamp.photo != nil,
                        isBusy: isLoadingPhoto,
                        showsLinkedCamera: isCameraLinkConfigured,
                        showsPrint: stamp.photo != nil && AppSettings.printerLinkHost != nil,
                        isPrinting: isPrintingToLinkedPrinter,
                        showsRemoveActions: stamp.photo != nil,
                        isPhotoLocked: !plusStore.isPlus,
                        onChange: {
                            if plusStore.isPlus { isShowingCamera = true } else { plusPaywallReason = .photo }
                        },
                        onLinkedCamera: {
                            if plusStore.isPlus {
                                Task { await captureFromLinkedCamera() }
                            } else {
                                plusPaywallReason = .photo
                            }
                        },
                        onPrint: { Task { await printToLinkedPrinter() } },
                        onDelete: { isConfirmingDelete = true }
                    )

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
            .photoChangePicker(isPresented: $isShowingCamera) { image in
                isLoadingPhoto = false
                applyPhotoUpdate(image)
            }
            .confirmationDialog(
                "この写真を削除しますか？",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) { applyPhotoUpdate(nil) }
                Button("キャンセル", role: .cancel) {}
            }
        }
        .task {
            await loadStoryIfNeeded()
        }
        .sheet(item: $plusPaywallReason) { reason in
            PlusComparisonView(reason: reason)
        }
        .onChange(of: plusStore.isPlus) { _, isPlus in
            if isPlus { Task { await loadStoryIfNeeded() } }
        }
    }

    /// 場所の詳細（由来やエピソード）をAIで補足する。
    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("この場所の詳細", systemImage: "text.book.closed.fill")
                .font(.headline)
                .foregroundStyle(.brown)

            if let story {
                VStack(alignment: .leading, spacing: 8) {
                    Text(story.title)
                        .font(.subheadline.bold())
                    Text(story.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .opacity(isLoadingStory ? 0.5 : 1)
            } else if isStoryLocked {
                lockedStoryView
            } else if isLoadingStory {
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 無料の3か所を使い切っていて、この場所の詳細は Plus でないと読めないか。
    private var isStoryLocked: Bool {
        !plusStore.canUse(.placeDetail, itemID: site.id)
    }

    private var lockedStoryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("場所の詳細は、無料で\(PlusFeature.placeDetail.freeLimit)か所まで読めます。Komap Plus なら、どの場所でも昔の出来事を読めます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                plusPaywallReason = .placeDetail
            } label: {
                Label("Plus で詳しく見る", systemImage: "lock.open.fill")
            }
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
        // 新しい写真の内容に合わせて、この場所の説明も作り直す（手で直した説明はそのまま）。
        PointStoryAutoGenerator.shared.stampChanged(
            stamp, photoChanged: true, context: modelContext, userID: authService.userID, isPlus: plusStore.isPlus
        )

        if let image {
            Task { await PrinterLinkService().printStampPhotoIfEnabled(image) }
        }

        guard let userID = authService.userID else { return }
        guard let image else {
            // 写真を消した時は、クラウドの御朱印の写真URLも空にする（公開中の旅なら、Cloud Functions が反映する）。
            Task { try? await syncService.upload(stamp, userID: userID) }
            return
        }
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

    /// 保存済みの説明が無ければ、AIで作って保存する（写真を追加・変更済みなら、その内容も踏まえた説明にする）。
    private func loadStoryIfNeeded(force: Bool = false) async {
        guard force || story == nil else { return }
        guard !isStoryLocked else { return }
        storyErrorMessage = nil
        do {
            try await pointStoryGenerator.generateCheckpointStory(
                for: stamp,
                overwrite: force,
                context: modelContext,
                userID: authService.userID,
                isPlus: plusStore.isPlus
            )
            plusStore.recordFreeUse(.placeDetail, itemID: site.id)
        } catch {
            storyErrorMessage = error.localizedDescription
        }
    }
}
