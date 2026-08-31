import SwiftUI

/// 地図上の写真ピンをタップした時に開く、その場所で投稿した写真と獲得ポイントのプレビュー。
struct PhotoPostPreviewSheet: View {
    let post: WalkPhotoPost

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let photo = post.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Label("+\(post.points) pt 獲得", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))

                    Text(post.postedAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("投稿した写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
