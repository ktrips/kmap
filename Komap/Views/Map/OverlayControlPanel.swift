import SwiftUI

/// 画面下部に浮かせる、古地図の選択と不透明度（現在の地図 ⇔ 古地図）の切り替えパネル。
struct OverlayControlPanel: View {
    @Binding var selectedOverlay: HistoricalOverlayMap?
    @Binding var overlayOpacity: Double
    /// 古地図が選び直された時に呼ばれる（マップの中心をその古地図の中心へ移動する等に使う）。
    var onSelect: (HistoricalOverlayMap?) -> Void = { _ in }
    /// 「新しい古地図を登録」が選ばれた時に呼ばれる。OpenAI・Googleカスタム検索の
    /// APIキーが両方とも設定されている時だけメニューに表示する。
    var onRequestSearch: () -> Void = {}

    var body: some View {
        VStack(spacing: 14) {
            Menu {
                Button("古地図を表示しない") {
                    selectedOverlay = nil
                    onSelect(nil)
                }
                Divider()
                ForEach(OldMapCatalog.allIncludingCustom) { overlay in
                    Button {
                        selectedOverlay = overlay
                        onSelect(overlay)
                    } label: {
                        if overlay.id == selectedOverlay?.id {
                            Label(overlay.title, systemImage: "checkmark")
                        } else {
                            Text(overlay.title)
                        }
                    }
                }
                if SecretsConfig.isOldMapSearchConfigured {
                    Divider()
                    Button {
                        onRequestSearch()
                    } label: {
                        Label("新しい古地図を登録", systemImage: "plus.circle")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "map.fill")
                    Text(selectedOverlay?.title ?? "古地図を選択")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
            }

            if selectedOverlay != nil {
                HStack(spacing: 10) {
                    Text("現在")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Slider(value: $overlayOpacity, in: 0...1)
                    Text("古地図")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        VStack {
            Spacer()
            OverlayControlPanel(
                selectedOverlay: .constant(OldMapCatalog.edoCastle),
                overlayOpacity: .constant(0.6)
            )
            .padding(.bottom, 20)
        }
    }
}
