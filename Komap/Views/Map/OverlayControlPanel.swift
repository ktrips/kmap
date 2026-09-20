import SwiftUI

/// 画面下部に浮かせる、古地図の選択と不透明度（現在の地図 ⇔ 古地図）の切り替えパネル。
struct OverlayControlPanel: View {
    @EnvironmentObject private var mapSession: MapSessionState
    @Binding var selectedOverlay: HistoricalOverlayMap?
    @Binding var overlayOpacity: Double
    /// 「全ての古地図を表示」が選ばれているかどうか。選ばれている間は、単一の`selectedOverlay`ではなく
    /// 同梱・登録済みの古地図すべてとそのチェックポイントを地図上に重ねて表示する。
    @Binding var isShowingAllOverlays: Bool
    /// 古地図が選び直された時に呼ばれる（マップの中心をその古地図の中心へ移動する等に使う）。
    var onSelect: (HistoricalOverlayMap?) -> Void = { _ in }
    /// 「全ての古地図を表示」が選ばれた時に呼ばれる。
    var onSelectAll: () -> Void = {}
    /// 「新しい古地図を登録」が選ばれた時に呼ばれる。OpenAIの
    /// APIキーが両方とも設定されている時だけメニューに表示する。
    var onRequestSearch: () -> Void = {}

    @State private var isPresentingPicker = false

    var body: some View {
        VStack(spacing: 14) {
            Button {
                // 歩行記録中も、これまで通り選び直しシートを開く（以前は歩行中だけ
                // シートを開かず貼り直しリクエストのみ送っていたため、歩きながら
                // 別の古地図に切り替えられなかった。定期貼り直しタイマーの追加で
                // GPU不具合からの復帰はシート無しでも自動的に効くようになったため、
                // ここでの特別扱いは不要になった）。
                isPresentingPicker = true
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
            .sheet(isPresented: $isPresentingPicker) {
                OldMapPickerSheet(
                    selectedOverlay: $selectedOverlay,
                    isShowingAllOverlays: $isShowingAllOverlays,
                    onSelect: onSelect,
                    onSelectAll: onSelectAll,
                    onRequestSearch: onRequestSearch
                )
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
}

/// 古地図選択シートの中身（上部のクイックボタン（現在地・新地図・全地図・地図無し）と古地図一覧・新規登録）。
/// 画面下部の`OverlayControlPanel`と、右上のハンバーガーメニュー内の「古地図選択」、
/// 両方から`.sheet`として表示する。
///
/// - Important: 以前はSwiftUIの`Menu`にこの内容をそのまま並べていたが、
///   同梱の古地図が増えて項目数が多くなった結果、iOS側がメニューの表示可能件数を
///   超えた分を（スクロールもできないまま）黙って表示しないことがあった
///   （画面下部から開くメニューで、上に入り切らない項目が切り捨てられる）。
///   そのため一覧が伸びても確実に全件が見えるよう、スクロール可能な`List`を
///   シートとして全画面表示する形に変更した。
struct OldMapPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var mapSession: MapSessionState
    @Binding var selectedOverlay: HistoricalOverlayMap?
    @Binding var isShowingAllOverlays: Bool
    var onSelect: (HistoricalOverlayMap?) -> Void = { _ in }
    var onSelectAll: () -> Void = {}
    var onRequestSearch: () -> Void = {}

    /// 追加した古地図の一覧。編集・削除の後に読み直す。
    @State private var customOverlays: [HistoricalOverlayMap] = CustomOverlayMapStore.all()
    @State private var detailOverlay: HistoricalOverlayMap?
    /// 「みんなの古地図」（クラウドで公開されているもの）。一覧の最下部に出す。
    @State private var sharedMaps: [RemoteOverlayMap] = []
    @State private var importingSharedID: String?
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        quickButton("現在地", systemImage: "magnifyingglass",
                                    isSelected: mapSession.isCurrentLocationMode && !isShowingAllOverlays) {
                            mapSession.requestCurrentLocationSearch()
                            dismiss()
                        }
                        // 「新地図」は、AI設定の「新しい地図を追加」がオンの間だけ表示する
                        // （AI・Web検索のAPIを呼び出す機能のため、意図しない利用を防ぐ）。
                        if AppSettings.allowAddingNewMapContent && SecretsConfig.isOldMapSearchConfigured {
                            quickButton("新地図", systemImage: "plus", isSelected: false) {
                                onRequestSearch()
                                dismiss()
                            }
                        }
                        quickButton("全地図", systemImage: "globe", isSelected: isShowingAllOverlays) {
                            mapSession.isCurrentLocationMode = false
                            isShowingAllOverlays = true
                            onSelectAll()
                            dismiss()
                        }
                        quickButton("地図無し", systemImage: "nosign",
                                    isSelected: selectedOverlay == nil && !isShowingAllOverlays) {
                            mapSession.isCurrentLocationMode = false
                            isShowingAllOverlays = false
                            selectedOverlay = nil
                            onSelect(nil)
                            dismiss()
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                ForEach(OldMapCatalog.Category.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(overlays(in: category)) { overlay in
                            overlayRow(for: overlay)
                        }
                    }
                }

                if !customOverlays.isEmpty {
                    Section("追加した古地図") {
                        ForEach(customOverlays) { overlay in
                            overlayRow(for: overlay)
                        }
                    }
                }


                sharedMapsSection
            }
            .task { await loadSharedMaps() }
            .sheet(item: $detailOverlay, onDismiss: refreshAfterDetail) { overlay in
                OverlayDetailView(overlay: overlay, onDeleted: {
                    // 表示中の古地図を削除した場合は、既定の古地図に戻す。
                    if selectedOverlay?.id == overlay.id {
                        selectedOverlay = OldMapCatalog.defaultOverlay
                        onSelect(selectedOverlay)
                    }
                })
            }
            .navigationTitle("古地図を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    /// 同梱の古地図のうち、指定した分類に属するものだけを返す
    /// （管理者による名前・画像の変更を反映した内容で）。
    private func overlays(in category: OldMapCatalog.Category) -> [HistoricalOverlayMap] {
        (OldMapCatalog.allByCategory[category] ?? []).compactMap { OldMapCatalog.overlay(withID: $0.id) }
    }

    /// 古地図1件の行。左に選択ボタン、右に詳細アイコン（押すと詳細情報の画面が開く）。
    private func overlayRow(for overlay: HistoricalOverlayMap) -> some View {
        HStack {
            overlayButton(for: overlay)
            Spacer()
            Button {
                detailOverlay = overlay
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
            }
            .accessibilityLabel("詳細")
        }
        .buttonStyle(.borderless)
    }

    /// 詳細画面（編集を含む）を閉じた後、一覧と、表示中の古地図を最新の内容に読み直す。
    private func refreshAfterDetail() {
        customOverlays = CustomOverlayMapStore.all()
        if let selected = selectedOverlay,
           let latest = OldMapCatalog.overlay(withID: selected.id),
           latest.title != selected.title || latest.imageFileName != selected.imageFileName {
            selectedOverlay = latest
            onSelect(latest)
        }
    }

    /// 一覧の最下部の「みんなの古地図」（公開されているもの）。追加ボタンで自分の古地図に取り込める。
    @ViewBuilder
    private var sharedMapsSection: some View {
        let others = sharedMaps.filter { $0.ownerUserID != authService.userID }
        if !others.isEmpty {
            Section("みんなの古地図") {
                ForEach(others.prefix(10)) { remote in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(remote.title).font(.body)
                            Text("\(remote.era)・チェックポイント\(remote.checkpoints.count)件")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await importShared(remote) }
                        } label: {
                            if importingSharedID == remote.id {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle").font(.title3)
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(importingSharedID != nil)
                        .accessibilityLabel("追加する")
                    }
                }
                NavigationLink {
                    SharedOverlayMapsView { overlay in selectImported(overlay) }
                } label: {
                    Label("みんなの古地図をすべて見る", systemImage: "person.2")
                }
            }
        }
    }

    private func loadSharedMaps() async {
        sharedMaps = (try? await OverlayMapShareService().fetchPublicMaps(limit: 30)) ?? []
    }

    private func importShared(_ remote: RemoteOverlayMap) async {
        importingSharedID = remote.id
        defer { importingSharedID = nil }
        if let overlay = try? await OverlayMapShareService().importMap(remote) {
            selectImported(overlay)
        }
    }

    /// 取り込んだ古地図をそのまま表示して閉じる。
    private func selectImported(_ overlay: HistoricalOverlayMap) {
        mapSession.isCurrentLocationMode = false
        isShowingAllOverlays = false
        selectedOverlay = overlay
        onSelect(overlay)
        dismiss()
    }

    /// 一覧の先頭に横並びで置く、アイコン付きのコンパクトなボタン。
    private func quickButton(
        _ title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
            .background(
                isSelected ? Color.accentColor : Color.accentColor.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func overlayButton(for overlay: HistoricalOverlayMap) -> some View {
        Button {
            mapSession.isCurrentLocationMode = false
            isShowingAllOverlays = false
            selectedOverlay = overlay
            onSelect(overlay)
            dismiss()
        } label: {
            if !isShowingAllOverlays && overlay.id == selectedOverlay?.id {
                Label(menuTitle(for: overlay), systemImage: "checkmark")
            } else {
                Text(menuTitle(for: overlay))
            }
        }
    }

    /// 一覧だけで使う、少し短くした古地図名。選択後に表示される名称（`title`そのもの）は変えない。
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
            .environmentObject(MapSessionState())
            .padding(.bottom, 20)
        }
    }
}
