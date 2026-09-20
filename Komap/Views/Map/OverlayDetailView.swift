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
                VStack(alignment: .leading, spacing: 14) {
                    if let image = overlay.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Text(overlay.title)
                        .font(.title3.bold())
                    Label(category, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(overlay.era)
                        .font(.subheadline.bold())
                        .foregroundStyle(.brown)
                    Text(overlay.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(
                        format: "範囲: 南西 %.4f, %.4f ／ 北東 %.4f, %.4f",
                        overlay.southWest.latitude, overlay.southWest.longitude,
                        overlay.northEast.latitude, overlay.northEast.longitude
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Divider()

                    Text("チェックポイント（\(checkpoints.count)件）")
                        .font(.headline)
                    if checkpoints.isEmpty {
                        Text("この古地図にはチェックポイントがありません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(checkpoints) { site in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.name).font(.subheadline.bold())
                            if !site.summary.isEmpty {
                                Text(site.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
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
