import AVKit
import SwiftUI

/// 動画シートを`.sheet(item:)`で開くための入れ物。
struct TripVideoItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// 作った旅の動画を再生し、再生が終わったら共有（保存を含む）ボタンを出すシート。
struct TripVideoPlayerSheet: View {
    let videoURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var didFinish = false

    init(videoURL: URL) {
        self.videoURL = videoURL
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if didFinish {
                    VStack(spacing: 10) {
                        // 共有シートの「ビデオを保存」で、写真ライブラリに保存できる。
                        ShareLink(item: videoURL) {
                            Label("動画を共有・保存する", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            didFinish = false
                            player.seek(to: .zero)
                            player.play()
                        } label: {
                            Label("もう一度再生", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("旅の動画")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear { player.play() }
        .onDisappear { player.pause() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            didFinish = true
        }
    }
}
