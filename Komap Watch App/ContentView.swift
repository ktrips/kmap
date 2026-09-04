import SwiftUI

/// Watch側の唯一の画面。「スタート」を押すとWatch自身のGPSで記録が始まり、
/// iPhone側アプリを開いていなくても記録・保存できる。iPhone側で先に記録が
/// 始まっている時は、一時停止・再開・終了だけを遠隔操作する。
struct ContentView: View {
    @StateObject private var sessionManager = WatchSessionManager()
    @State private var isConfirmingStop = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: statusIconSystemName)
                        .font(.system(size: 28))
                        .foregroundStyle(statusColor)
                    HStack(spacing: 6) {
                        if let statusIconImageName {
                            Image(statusIconImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                        Text(statusText)
                            .font(.headline)
                    }

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
                            isConfirmingStop = true
                        } label: {
                            Label("完了", systemImage: "stop.circle.fill")
                        }

                    case .paused:
                        Button {
                            sessionManager.resume()
                        } label: {
                            Label("再開", systemImage: "play.circle.fill")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            isConfirmingStop = true
                        } label: {
                            Label("完了", systemImage: "stop.circle.fill")
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
            .sheet(isPresented: $isConfirmingStop) {
                WatchWalkSaveDecisionView(
                    onSave: { sessionManager.stop() },
                    onDiscard: { sessionManager.stop(shouldSave: false) }
                )
            }
            .sheet(item: stampSheetBinding) { info in
                StampCollectedView(info: info) {
                    sessionManager.acknowledgeStampCollected()
                }
            }
            .overlay(alignment: .top) {
                if let points = sessionManager.newlyPostedPhotoPoints {
                    Text("写真投稿 +\(points)pt")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.86, green: 0.63, blue: 0.24), in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: sessionManager.newlyPostedPhotoPoints) { _, points in
                guard points != nil else { return }
                Task {
                    try? await Task.sleep(for: .seconds(1.8))
                    sessionManager.acknowledgePhotoPosted()
                }
            }
        }
    }

    /// `newlyCollectedStamp`をそのまま`.sheet(item:)`に渡すためのブリッジ。
    /// シートが閉じられた（下スワイプ等）時にも`acknowledgeStampCollected()`が呼ばれるようにする。
    private var stampSheetBinding: Binding<WatchCollectedStampInfo?> {
        Binding(
            get: { sessionManager.newlyCollectedStamp },
            set: { newValue in
                if newValue == nil {
                    sessionManager.acknowledgeStampCollected()
                }
            }
        )
    }

    private var statusText: String {
        switch sessionManager.state {
        case .idle: return "時空旅を始める"
        case .recording: return "時空旅中！"
        case .paused: return "一時停止中"
        }
    }

    /// 「未記録」「記録中」はアプリアイコンで表す。それ以外（一時停止中）は
    /// これまで通りSFシンボルのまま。
    private var statusIconImageName: String? {
        switch sessionManager.state {
        case .idle, .recording: return "KomapIcon"
        case .paused: return nil
        }
    }

    private var statusIconSystemName: String {
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

/// 御朱印チェックポイントに近づいた時、Watch画面に出すその場チェックイン画面。
/// 写真の追加などはiPhone側で行うため、ここでは獲得の確認とチェックインだけを行う。
private struct StampCollectedView: View {
    let info: WatchCollectedStampInfo
    let onCheckIn: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                Text("御朱印を獲得！")
                    .font(.headline)
                Text(info.siteName)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                if !info.siteSummary.isEmpty {
                    Text(info.siteSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    onCheckIn()
                    dismiss()
                } label: {
                    Label("チェックイン", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
            .padding()
        }
    }
}

/// 「完了」を押した直後に出す保存確認画面。
/// 誤って破棄しないよう、「保存」を大きく目立たせ、「破棄」はその下に小さく置く。
private struct WatchWalkSaveDecisionView: View {
    let onSave: () -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// 「破棄」を押した直後、誤操作を防ぐための小さな確認待ち状態。
    @State private var isConfirmingDiscard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("記録を保存しますか？")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Button {
                    onSave()
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)

                if isConfirmingDiscard {
                    VStack(spacing: 6) {
                        Text("本当に破棄しますか？")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("破棄する", role: .destructive) {
                            onDiscard()
                            dismiss()
                        }
                        .font(.caption.bold())
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        Button("キャンセル") { isConfirmingDiscard = false }
                            .font(.caption2)
                            .buttonStyle(.plain)
                    }
                } else {
                    Button(role: .destructive) {
                        isConfirmingDiscard = true
                    } label: {
                        Text("破棄")
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.15), value: isConfirmingDiscard)
        }
    }
}

#Preview {
    ContentView()
}
