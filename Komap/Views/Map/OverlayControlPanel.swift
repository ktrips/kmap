import SwiftUI

/// 画面下部に浮かせる、古地図の選択と不透明度（現在の地図 ⇔ 古地図）の切り替えパネル。
struct OverlayControlPanel: View {
    @Binding var selectedOverlay: HistoricalOverlayMap?
    @Binding var overlayOpacity: Double
    /// 「全ての古地図を表示」が選ばれているかどうか。選ばれている間は、単一の`selectedOverlay`ではなく
    /// 同梱・登録済みの古地図すべてとそのチェックポイントを地図上に重ねて表示する。
    @Binding var isShowingAllOverlays: Bool
    /// 古地図が選び直された時に呼ばれる（マップの中心をその古地図の中心へ移動する等に使う）。
    var onSelect: (HistoricalOverlayMap?) -> Void = { _ in }
    /// 「全ての古地図を表示」が選ばれた時に呼ばれる。
    var onSelectAll: () -> Void = {}
    /// 「新しい古地図を登録」が選ばれた時に呼ばれる。OpenAI・Googleカスタム検索の
    /// APIキーが両方とも設定されている時だけメニューに表示する。
    var onRequestSearch: () -> Void = {}

    var body: some View {
        VStack(spacing: 14) {
            Menu {
                Button {
                    isShowingAllOverlays = true
                    onSelectAll()
                } label: {
                    if isShowingAllOverlays {
                        Label("全ての古地図を表示", systemImage: "checkmark")
                    } else {
                        Text("全ての古地図を表示")
                    }
                }
                Divider()
                Button("古地図を表示しない") {
                    isShowingAllOverlays = false
                    selectedOverlay = nil
                    onSelect(nil)
                }
                Divider()
                ForEach(OldMapCatalog.allIncludingCustom) { overlay in
                    Button {
                        isShowingAllOverlays = false
                        selectedOverlay = overlay
                        onSelect(overlay)
                    } label: {
                        if !isShowingAllOverlays && overlay.id == selectedOverlay?.id {
                            Label(menuTitle(for: overlay), systemImage: "checkmark")
                        } else {
                            Text(menuTitle(for: overlay))
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
                    Text(isShowingAllOverlays ? "全ての古地図" : (selectedOverlay?.title ?? "古地図を選択"))
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
            }

            if selectedOverlay != nil && !isShowingAllOverlays {
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

    /// メニュー一覧だけで使う、少し短くした古地図名。選択後に表示される名称（`title`そのもの）は変えない。
    private func menuTitle(for overlay: HistoricalOverlayMap) -> String {
        if overlay.id == OldMapCatalog.goshikiFudo.id {
            return "五色不動巡り(目黒・目白・目赤・目青・目黄)"
        }
        return overlay.title
            .replacingOccurrences(of: "・谷中", with: "")
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        VStack {
            Spacer()
            OverlayControlPanel(
                selectedOverlay: .constant(OldMapCatalog.edoCastle),
                overlayOpacity: .constant(0.6),
                isShowingAllOverlays: .constant(false)
            )
            .padding(.bottom, 20)
        }
    }
}
