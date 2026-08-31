import CoreLocation
import SwiftUI

/// 地図上の写真ピンをタップした時に開く、その場所で投稿した写真・獲得ポイント・
/// 場所の名前とAIによる解説のプレビュー。
///
/// 場所の名前（逆ジオコーディング）とAIの解説は、一度取得したら`WalkPhotoPost`に
/// 保存し、次回このシートを開いた時は再取得しに行かない。
struct PhotoPostPreviewSheet: View {
    @Bindable var post: WalkPhotoPost

    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingInfo = false
    @State private var infoErrorMessage: String?

    private let geocoder = CLGeocoder()
    private let historyService = AIHistoryService()

    var body: some View {
        NavigationStack {
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
            .navigationTitle("投稿した写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await loadInfoIfNeeded()
            }
        }
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

        isLoadingInfo = false
    }
}
