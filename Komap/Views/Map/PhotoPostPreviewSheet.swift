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
/// 削除／非公開の操作）。`PhotoPostPreviewSheet`の各ページとして使う。
private struct PhotoPostPageView: View {
    @Bindable var post: WalkPhotoPost
    var onDelete: () -> Void

    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @State private var isLoadingInfo = false
    @State private var infoErrorMessage: String?
    @State private var isPrintingToLinkedPrinter = false
    @State private var printMessage: String?
    @State private var isConfirmingDelete = false
    @State private var isUpdatingVisibility = false

    private let geocoder = CLGeocoder()
    private let historyService = AIHistoryService()
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

                Label("+\(post.points) pt 獲得", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))

                Text(post.postedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                actionButtons

                if let printMessage {
                    Text(printMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let placeName = post.placeName {
                    Label(placeName, systemImage: "mappin.and.ellipse")
                        .font(.subheadline.bold())
                }

                if let title = post.storyTitle, let body = post.storyBody {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.headline)
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
        .task {
            await loadInfoIfNeeded()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if post.photo != nil && AppSettings.printerLinkHost != nil {
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

            Button {
                Task { await toggleVisibility() }
            } label: {
                if isUpdatingVisibility {
                    ProgressView()
                } else {
                    Label(
                        post.isHiddenFromSharing ? "非公開中" : "非公開にする",
                        systemImage: post.isHiddenFromSharing ? "eye.slash.fill" : "eye.slash"
                    )
                }
            }
            .disabled(isUpdatingVisibility)

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
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

    /// 「非公開にする」を切り替える。「みんなの時空旅」に公開中の時空旅であれば、
    /// この写真だけを公開データから外す／戻すために公開データを作り直す。
    private func toggleVisibility() async {
        isUpdatingVisibility = true
        defer { isUpdatingVisibility = false }
        post.isHiddenFromSharing.toggle()
        try? modelContext.save()
        if let walkRouteID = post.walkRouteID {
            await resyncSharedTripIfNeeded(walkRouteID: walkRouteID)
        }
    }

    /// この写真を削除する。端末に保存済みの画像ファイル・SwiftDataのレコードに加え、
    /// クラウド（Firestore・Storage）側のコピーも削除し、公開中であれば公開データも作り直す。
    private func deletePost() {
        let postID = post.id
        let walkRouteID = post.walkRouteID
        let userID = authService.userID
        StampPhotoStore.delete(post.photoFileName)
        modelContext.delete(post)
        try? modelContext.save()
        onDelete()
        Task {
            await syncService.deletePhotoPost(id: postID, userID: userID)
            if let walkRouteID {
                await resyncSharedTripIfNeeded(walkRouteID: walkRouteID)
            }
        }
    }

    /// この写真が属する時空旅が既に「みんなの時空旅」に公開済みなら、最新の内容
    /// （この写真の削除・非公開化を反映したもの）で公開データを作り直す。
    private func resyncSharedTripIfNeeded(walkRouteID: UUID) async {
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

    /// 場所の名前・AIの解説は一度取得したら`post`に保存し、以後は再取得しない。
    private func loadInfoIfNeeded() async {
        guard post.placeName == nil || post.storyTitle == nil else { return }
        isLoadingInfo = true
        infoErrorMessage = nil

        if post.placeName == nil {
            let location = CLLocation(latitude: post.coordinate.latitude, longitude: post.coordinate.longitude)
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                post.placeName = [placemark.name, placemark.locality].compactMap { $0 }.first
            }
        }

        if post.storyTitle == nil {
            do {
                let story = try await historyService.generateStory(
                    for: post.coordinate,
                    overlayMap: nil,
                    placeName: post.placeName
                )
                post.storyTitle = story.title
                post.storyBody = story.body
            } catch {
                infoErrorMessage = error.localizedDescription
            }
        }

        try? modelContext.save()
        // 場所の名前・AIの解説はサインイン中ならクラウドにも反映し、Webでサインインして
        // 見た時にもこの写真の説明が表示されるようにする。
        try? await syncService.upload(post, userID: authService.userID)

        isLoadingInfo = false
    }
}
