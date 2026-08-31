import SwiftData
import SwiftUI

/// My TimeTripの「ポイント」サマリーカードをタップした時に開く、写真投稿の履歴一覧。
struct PointHistoryView: View {
    @Query(sort: \WalkPhotoPost.postedAt, order: .reverse) private var photoPosts: [WalkPhotoPost]

    @State private var selectedPost: WalkPhotoPost?

    private var totalPoints: Int {
        photoPosts.reduce(0) { $0 + $1.points }
    }

    var body: some View {
        ScrollView {
            if photoPosts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(photoPosts) { post in
                        PhotoPostRow(post: post)
                            .onTapGesture {
                                selectedPost = post
                            }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("ポイント \(totalPoints) pt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPost) { post in
            PhotoPostPreviewSheet(post: post)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("まだ投稿がありません")
                .font(.headline)
            Text("ウォーキングの記録中に「写真投稿」から気になった風景を残すと、ポイントが貯まります。")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

/// ポイント履歴の1行。投稿写真・日時・獲得ポイントを表示する。
private struct PhotoPostRow: View {
    let post: WalkPhotoPost

    var body: some View {
        HStack(spacing: 12) {
            if let photo = post.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(post.postedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline.bold())
                Text("+\(post.points) pt")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PointHistoryView()
    }
    .modelContainer(for: [WalkPhotoPost.self], inMemory: true)
}
