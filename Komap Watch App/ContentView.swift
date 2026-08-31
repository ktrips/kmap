import SwiftUI

/// Watch側の唯一の画面。「スタート」を押すとWatch自身のGPSで記録が始まり、
/// iPhone側アプリを開いていなくても記録・保存できる。iPhone側で先に記録が
/// 始まっている時は、一時停止・再開・終了だけを遠隔操作する。
struct ContentView: View {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 28))
                        .foregroundStyle(statusColor)
                    Text(statusText)
                        .font(.headline)

                    if sessionManager.state != .idle {
                        Text(sessionManager.isSelfTracking ? "Watch単体で記録中" : "iPhoneと連動中")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !sessionManager.isReachable {
                        Label("iPhoneと未接続", systemImage: "iphone.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    switch sessionManager.state {
                    case .idle:
                        Button {
                            sessionManager.start()
                        } label: {
                            Label("スタート", systemImage: "play.circle.fill")
                        }
                        .tint(.green)

                    case .recording:
                        Button {
                            sessionManager.pause()
                        } label: {
                            Label("一時停止", systemImage: "pause.circle.fill")
                        }
                        .tint(.orange)

                        Button(role: .destructive) {
                            sessionManager.stop()
                        } label: {
                            Label("終了", systemImage: "stop.circle.fill")
                        }

                    case .paused:
                        Button {
                            sessionManager.resume()
                        } label: {
                            Label("再開", systemImage: "play.circle.fill")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            sessionManager.stop()
                        } label: {
                            Label("終了", systemImage: "stop.circle.fill")
                        }
                    }

                    NavigationLink {
                        MapPickerView(sessionManager: sessionManager)
                    } label: {
                        Label(selectedMapTitle, systemImage: "map")
                            .lineLimit(1)
                    }
                    .disabled(sessionManager.availableMaps.isEmpty)
                }
                .padding()
            }
        }
    }

    private var statusText: String {
        switch sessionManager.state {
        case .idle: return "未記録"
        case .recording: return "記録中"
        case .paused: return "一時停止中"
        }
    }

    private var statusIcon: String {
        switch sessionManager.state {
        case .idle: return "figure.walk"
        case .recording: return "figure.walk.motion"
        case .paused: return "pause.circle"
        }
    }

    private var statusColor: Color {
        switch sessionManager.state {
        case .idle: return .secondary
        case .recording: return .green
        case .paused: return .orange
        }
    }

    private var selectedMapTitle: String {
        sessionManager.availableMaps.first(where: { $0.id == sessionManager.selectedMapID })?.title ?? "古地図を選ぶ"
    }
}

/// 使う古地図を選ぶ一覧。iPhone側の選択にそのまま反映される。
private struct MapPickerView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(sessionManager.availableMaps) { option in
            Button {
                sessionManager.selectMap(option.id)
                dismiss()
            } label: {
                HStack {
                    Text(option.title)
                    Spacer()
                    if option.id == sessionManager.selectedMapID {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle("古地図")
    }
}

#Preview {
    ContentView()
}
