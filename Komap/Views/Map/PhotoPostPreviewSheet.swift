import CoreLocation
import SwiftData
import SwiftUI

/// 地図上の写真ピンをタップした時に開く、その場所で投稿した写真・獲得ポイント・
/// 場所の名前とAIによる解説のプレビュー。
///
/// 同じ時空旅（`walkRouteID`）に投稿した写真が複数あれば、左右にフリックして
/// 前後の写真へ移動できる（`TabView`のページング）。`@Query`で同じ`walkRouteID`の
/// 投稿を直接監視しているため、このシートの中で削除しても一覧が自動的に更新される。
struct PhotoPostPreviewSheet: View {
    @Query private var posts: [WalkPhotoPost]
    @State private var selectedPostID: UUID
    @Environment(\.dismiss) private var dismiss

    init(post: WalkPhotoPost) {
        _selectedPostID = State(initialValue: post.id)
        if let walkRouteID = post.walkRouteID {
            _posts = Query(
                filter: #Predicate<WalkPhotoPost> { $0.walkRouteID == walkRouteID },
                sort: \WalkPhotoPost.postedAt
            )
        } else {
            let postID = post.id
            _posts = Query(filter: #Predicate<WalkPhotoPost> { $0.id == postID })
        }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPostID) {
                ForEach(posts) { post in
                    PhotoPostPageView(post: post) {
                        handleDeleted(currentCount: posts.count)
                    }
                    .tag(post.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: posts.count > 1 ? .always : .never))
            .navigationTitle("投稿した写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onChange(of: posts) { _, newPosts in
            // 削除等で今表示しているページが無くなった場合、隣の写真に留まれるよう
            // 選択中IDを補正する（`TabView`は選択中の`tag`が消えると空白になるため）。
            guard !newPosts.contains(where: { $0.id == selectedPostID }) else { return }
            if let first = newPosts.first {
                selectedPostID = first.id
            }
        }
    }

    private func handleDeleted(currentCount: Int) {
        if currentCount <= 1 {
            dismiss()
        }
    }
}

/// 1件分の投稿写真の中身（画像・獲得ポイント・連携プリント・場所の解説・
/// 削除／非公開の操作）。`PhotoPostPreviewSheet`の各ページとして使う
/// （`MyTimeTripView`の`PhotoPostGallerySheet`からも、複数の時空旅をまたいだ
/// 一覧をページ送りするために再利用する）。
struct PhotoPostPageView: View {
    @Bindable var post: WalkPhotoPost
    var onDelete: () -> Void

    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    /// 場所の名前・AIの説明を作っている間（投稿した時点から自動で作っている分も含む）。
    @ObservedObject private var pointStoryGenerator = PointStoryAutoGenerator.shared
    private var isLoadingInfo: Bool { pointStoryGenerator.generatingPostIDs.contains(post.id) }
    @State private var infoErrorMessage: String?
    @State private var isPrintingToLinkedPrinter = false
    @State private var printMessage: String?
    @State private var isConfirmingDelete = false
    @State private var editableUserTitle: String = ""
    @State private var isEditingTitle = false
    @FocusState private var isTitleFieldFocused: Bool
    @State private var isShowingPhotoChange = false
    @State private var isChangingPhoto = false
    @State private var isShowingPlus = false
    @EnvironmentObject private var plusStore: PlusStore

    private let syncService = SyncService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let photo = post.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                PhotoDetailActionRow(
                    date: post.postedAt,
                    hasPhoto: true,
                    isBusy: isChangingPhoto,
                    showsLinkedCamera: AppSettings.cameraLinkHost != nil,
                    showsPrint: post.photo != nil && AppSettings.printerLinkHost != nil,
                    isPrinting: isPrintingToLinkedPrinter,
                    showsRemoveActions: true,
                    isPhotoLocked: !plusStore.isPlus,
                    onChange: {
                        if plusStore.isPlus { isShowingPhotoChange = true } else { isShowingPlus = true }
                    },
                    onLinkedCamera: {
                        if plusStore.isPlus {
                            Task { await changePhotoFromLinkedCamera() }
                        } else {
                            isShowingPlus = true
                        }
                    },
                    onPrint: { Task { await printToLinkedPrinter() } },
                    onDelete: { isConfirmingDelete = true }
                )

                if let printMessage {
                    Text(printMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // ポイントの名前。最初は位置情報の場所の名前で、鉛筆を押すと自分で名前を付けられる。
                // 名前を付けても、元の位置情報の場所はその下に残して表示する。
                if isEditingTitle {
                    HStack(spacing: 8) {
                        TextField(post.placeName ?? "このポイントの名前", text: $editableUserTitle)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .focused($isTitleFieldFocused)
                            .onAppear { isTitleFieldFocused = true }
                            .onSubmit { finishEditingTitle() }
                        Button("完了") { finishEditingTitle() }
                            .font(.subheadline.bold())
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(post.displayTitle ?? (isLoadingInfo ? "場所を調べています…" : "名前のないポイント"))
                            .font(.title3.bold())
                            .foregroundStyle(post.displayTitle == nil ? .secondary : .primary)
                        Button {
                            editableUserTitle = post.userTitle ?? post.placeName ?? ""
                            isEditingTitle = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("ポイントの名前を変える")
                    }
                }

                if let placeName = post.placeName {
                    Label(placeName, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let title = post.storyTitle, let body = post.storyBody {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.headline)
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await regenerateStory() }
                    } label: {
                        if isLoadingInfo {
                            ProgressView()
                        } else {
                            Label("AIの説明を作り直す", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                    .disabled(isLoadingInfo)
                } else if isLoadingInfo {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("この場所の情報を調べています…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let infoErrorMessage {
                    Text(infoErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog(
            "この写真を削除しますか？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) { deletePost() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("獲得したポイントも含めて取り消され、元に戻せません。")
        }
        .sheet(isPresented: $isShowingPlus) {
            PlusComparisonView(reason: .photo)
        }
        .photoChangePicker(isPresented: $isShowingPhotoChange) { image in
            Task { await changePhoto(to: image) }
        }
        // 名前の入力欄から離れた時・シートを閉じた時も、入力した名前を確定する。
        .onChange(of: isTitleFieldFocused) { _, isFocused in
            if !isFocused, isEditingTitle { finishEditingTitle() }
        }
        .onDisappear {
            if isEditingTitle { commitUserTitleIfChanged() }
        }
        .task {
            editableUserTitle = post.userTitle ?? ""
            await loadInfoIfNeeded()
        }
    }

    /// 連携カメラで撮った最新の写真に差し替える。
    private func changePhotoFromLinkedCamera() async {
        isChangingPhoto = true
        do {
            let image = try await CameraLinkService().fetchLatestPhoto()
            isChangingPhoto = false
            await changePhoto(to: image)
        } catch {
            isChangingPhoto = false
            printMessage = error.localizedDescription
        }
    }

    /// 写真を差し替える。「設定」で選んだ加工を適用し、連携プリンターが設定されていれば
    /// そちらへも転送してから、サインイン中ならクラウドにも上げ直す（公開中の旅なら、Cloud Functions が反映する）。
    private func changePhoto(to rawImage: UIImage) async {
        isChangingPhoto = true
        defer { isChangingPhoto = false }
        let image = AppSettings.photoFilterStyle.apply(to: rawImage)
        post.updatePhoto(image)
        try? modelContext.save()
        Task { await PrinterLinkService().printPhotoPostIfEnabled(image) }

        // 新しい写真の内容に合わせて、この場所の説明も作り直す。
        Task { await regenerateStory() }

        guard let userID = authService.userID else { return }
        try? await syncService.uploadPhotoPostImage(post, userID: userID)
        try? modelContext.save()
    }

    /// 「連携プリント」ボタンから、この投稿写真をその場で連携プリンターへ転送する。
    private func printToLinkedPrinter() async {
        guard let photo = post.photo else { return }
        isPrintingToLinkedPrinter = true
        printMessage = nil
        defer { isPrintingToLinkedPrinter = false }
        do {
            try await PrinterLinkService().printOnDemand(photo, cloudURL: post.cloudPhotoURL.flatMap(URL.init))
            printMessage = "連携プリンターへ送信しました"
        } catch {
            printMessage = error.localizedDescription
        }
    }

    /// この写真を削除する。端末に保存済みの画像ファイル・SwiftDataのレコードに加え、
    /// クラウド（Firestore・Storage）側のコピーも削除する（公開中の旅なら、Cloud Functions が反映する）。
    private func deletePost() {
        let postID = post.id
        let userID = authService.userID
        StampPhotoStore.delete(post.photoFileName)
        modelContext.delete(post)
        try? modelContext.save()
        onDelete()
        Task { await syncService.deletePhotoPost(id: postID, userID: userID) }
    }

    /// 場所の名前・AIの解説は一度取得したら`post`に保存し、以後は再取得しない
    /// （投稿した時点で`PointStoryAutoGenerator`が作っていれば、ここでは何もしない）。
    private func loadInfoIfNeeded() async {
        await generateInfo(regenerate: false)
    }

    private func generateInfo(regenerate: Bool) async {
        infoErrorMessage = nil
        do {
            try await pointStoryGenerator.generatePostInfo(
                for: post,
                regenerate: regenerate,
                context: modelContext,
                userID: authService.userID,
                isPlus: plusStore.isPlus
            )
        } catch {
            infoErrorMessage = error.localizedDescription
        }
    }

    /// 「名前」欄の編集を確定し、変わっていればAIの説明も作り直す
    /// （付けた名前を手がかりに、より興味深い説明文になるようにするため）。
    private func finishEditingTitle() {
        isEditingTitle = false
        isTitleFieldFocused = false
        commitUserTitleIfChanged()
    }

    private func commitUserTitleIfChanged() {
        let trimmed = editableUserTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // 空にした時・位置情報の場所の名前のままの時は、自分で付けた名前は無し（場所の名前を使う）。
        let newValue = (trimmed.isEmpty || trimmed == post.placeName) ? nil : trimmed
        guard newValue != post.userTitle else { return }
        post.userTitle = newValue
        try? modelContext.save()
        Task {
            await regenerateStory()
        }
    }

    /// 名前・写真・位置情報から、AIの説明文を改めて生成し直す。
    private func regenerateStory() async {
        await generateInfo(regenerate: true)
    }
}
