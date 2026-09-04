import SwiftUI

/// 「みんなの時空旅」として公開した1件に対する、いいね・コメントの表示と投稿。
/// `WalkRouteDetailView`（自分が公開した時空旅）から、対象の`sharedTrips/{tripId}`の
/// IDだけを渡して埋め込める。
struct TripEngagementView: View {
    let tripID: String
    let currentUserID: String?
    let currentUserDisplayName: String?

    @State private var likeUserIDs: [String] = []
    @State private var comments: [RemoteTripComment] = []
    @State private var commentText = ""
    @State private var isToggling = false
    @State private var isPosting = false
    @State private var isLoaded = false

    private let syncService = SyncService()

    private var isLikedByMe: Bool {
        guard let currentUserID else { return false }
        return likeUserIDs.contains(currentUserID)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                Task { await toggleLike() }
            } label: {
                Label(
                    "いいね\(likeUserIDs.isEmpty ? "" : " \(likeUserIDs.count)")",
                    systemImage: isLikedByMe ? "heart.fill" : "heart"
                )
                .font(.subheadline.bold())
                .foregroundStyle(isLikedByMe ? .pink : .secondary)
            }
            .disabled(isToggling || currentUserID == nil)

            VStack(alignment: .leading, spacing: 10) {
                Text("コメント\(comments.isEmpty ? "" : " \(comments.count)件")")
                    .font(.subheadline.bold())

                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(comment.authorDisplayName)
                                .font(.caption.bold())
                            Text(Self.dateFormatter.string(from: comment.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if comment.authorUserID == currentUserID {
                                Spacer()
                                Button("削除") {
                                    Task { await deleteComment(comment) }
                                }
                                .font(.caption2)
                                .foregroundStyle(.red)
                            }
                        }
                        Text(comment.text)
                            .font(.subheadline)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack(spacing: 8) {
                    TextField(
                        currentUserID != nil ? "コメントを書く…" : "サインインするとコメントできます",
                        text: $commentText
                    )
                    .textFieldStyle(.roundedBorder)
                    .disabled(currentUserID == nil)

                    Button("投稿") {
                        Task { await postComment() }
                    }
                    .disabled(isPosting || currentUserID == nil || commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            guard !isLoaded else { return }
            isLoaded = true
            await reload()
        }
    }

    private func reload() async {
        async let likes = try? syncService.fetchLikeUserIDs(tripID: tripID)
        async let fetchedComments = try? syncService.fetchComments(tripID: tripID)
        likeUserIDs = await likes ?? likeUserIDs
        comments = await fetchedComments ?? comments
    }

    private func toggleLike() async {
        guard let currentUserID, !isToggling else { return }
        isToggling = true
        defer { isToggling = false }
        let wasLiked = isLikedByMe
        do {
            try await syncService.setLiked(tripID: tripID, userID: currentUserID, liked: !wasLiked)
            if wasLiked {
                likeUserIDs.removeAll { $0 == currentUserID }
            } else {
                likeUserIDs.append(currentUserID)
            }
        } catch {
            // 通信に失敗しても表示は変えない（次回の再読み込みで実際の状態に揃う）。
        }
    }

    private func postComment() async {
        guard let currentUserID, !isPosting else { return }
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await syncService.postComment(
                tripID: tripID,
                authorUserID: currentUserID,
                authorDisplayName: currentUserDisplayName ?? "名無し",
                text: trimmed
            )
            commentText = ""
            comments = (try? await syncService.fetchComments(tripID: tripID)) ?? comments
        } catch {
            // 投稿失敗時は入力欄の文字を残し、ユーザーが再送できるようにする。
        }
    }

    private func deleteComment(_ comment: RemoteTripComment) async {
        do {
            try await syncService.deleteComment(tripID: tripID, commentID: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {
            // 失敗した場合は一覧に残したままにする。
        }
    }
}
