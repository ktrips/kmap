import SwiftUI

/// 古地図の詳細情報（画像・時代・紹介文・範囲・チェックポイント）。
/// 追加した古地図と、管理者ユーザーの同梱の古地図には「編集」ボタンを出し、
/// 地図の編集画面（`CustomOverlayEditorView`）を開ける。
struct OverlayDetailView: View {
    @State private var overlay: HistoricalOverlayMap
    /// 古地図を削除した時に呼ばれる（追加した古地図のみ）。
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var isShowingEditor = false
    @State private var checkpoints: [HistoricSite]

    init(overlay: HistoricalOverlayMap, onDeleted: @escaping () -> Void = {}) {
        _overlay = State(initialValue: overlay)
        _checkpoints = State(initialValue: HistoricSiteCatalog.sites(forOverlayID: overlay.id))
        self.onDeleted = onDeleted
    }

    /// 同梱の古地図は管理者だけ、追加した古地図（自分の端末に保存したもの）は誰でも編集できる。
    private var canEdit: Bool {
        OldMapCatalog.isBundled(id: overlay.id) ? authService.isAdmin : true
    }

    private var category: String {
        OldMapCatalog.category(of: overlay)?.rawValue ?? "追加した古地図"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                OverlayInfoContent(
                    overlay: overlay,
                    checkpoints: checkpoints,
                    category: category,
                    showsRange: true
                )
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("地図の詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button("編集") { isShowingEditor = true }
                    }
                }
            }
            .sheet(isPresented: $isShowingEditor, onDismiss: reload) {
                CustomOverlayEditorView(overlay: overlay, onDeleted: {
                    onDeleted()
                    dismiss()
                })
            }
        }
    }

    /// 編集後の最新の内容に読み直す。
    private func reload() {
        if let latest = OldMapCatalog.overlay(withID: overlay.id) {
            overlay = latest
        }
        checkpoints = HistoricSiteCatalog.sites(forOverlayID: overlay.id)
    }
}
