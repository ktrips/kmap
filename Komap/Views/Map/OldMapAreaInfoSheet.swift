import SwiftUI

/// 地図上部に表示している「選択中の古地図の名前」ラベルを押した時に開く、
/// その地域の簡単な説明とチェックポイント一覧をまとめたシート。
struct OldMapAreaInfoSheet: View {
    let overlay: HistoricalOverlayMap
    let checkpoints: [HistoricSite]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(overlay.era, systemImage: "clock.arrow.circlepath")
                            .font(.subheadline.bold())
                            .foregroundStyle(.brown)
                        Text(overlay.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !checkpoints.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("チェックポイント")
                                .font(.headline)
                            ForEach(checkpoints) { site in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(site.name)
                                        .font(.subheadline.bold())
                                    Text(site.summary)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
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
