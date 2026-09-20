import SwiftUI

/// 地図上部に表示している「選択中の古地図の名前」ラベルを押した時に開く、
/// その古地図（画像とチェックポイント）と説明をまとめたシート。
/// 古地図を選択の詳細画面（`OverlayDetailView`）と同じ形式（`OverlayInfoContent`）で表示する。
struct OldMapAreaInfoSheet: View {
    let overlay: HistoricalOverlayMap
    let checkpoints: [HistoricSite]
    /// 歩行記録中に、古地図が消えて見える時のために古地図を再読み込みする操作。
    /// 渡した時だけ、下部に「古地図を再読み込み」ボタンを出す。
    var onReload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OverlayInfoContent(overlay: overlay, checkpoints: checkpoints)

                    if let onReload {
                        Button {
                            onReload()
                        } label: {
                            Label("古地図を再読み込み", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle(overlay.shortTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    OldMapAreaInfoSheet(
        overlay: OldMapCatalog.edoCastle,
        checkpoints: HistoricSiteCatalog.sites(forOverlayID: OldMapCatalog.edoCastle.id)
    )
}
