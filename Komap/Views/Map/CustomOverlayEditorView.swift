import CoreLocation
import GoogleMaps
import SwiftUI

/// 古地図を、地図の上で編集する画面。
/// 地図をタップしてポイントを追加し、ポイントをタップして削除する。
/// 追加した古地図は、公開範囲の変更・古地図そのものの削除もここから行う。
/// 同梱の古地図（管理者だけが編集できる）は、変更を端末内の「上書き」として保存し、
/// 削除の代わりに「変更を元に戻す」ができる。
struct CustomOverlayEditorView: View {
    /// 編集中の古地図。名前や画像を変えたら、保存済みの最新の内容に読み直す。
    @State private var overlay: HistoricalOverlayMap
    /// 古地図を削除した時に呼ばれる。
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var checkpoints: [HistoricSite]
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    @State private var newPointName = ""
    @State private var newPointSummary = ""
    @State private var pointToDelete: HistoricSite?
    @State private var isConfirmingDeleteOverlay = false
    @State private var isConfirmingResetOverlay = false
    @State private var isRenaming = false
    @State private var editedTitle = ""
    @State private var isPublic: Bool
    @State private var isShowingUpdateSheet = false
    @State private var isSyncingCloud = false
    @State private var cloudErrorMessage: String?

    private let shareService = OverlayMapShareService()

    /// 同梱の古地図かどうか（追加した古地図と、保存先・使える操作が異なる）。
    private var isBundled: Bool { OldMapCatalog.isBundled(id: overlay.id) }

    init(overlay: HistoricalOverlayMap, onDeleted: @escaping () -> Void = {}) {
        _overlay = State(initialValue: overlay)
        _isPublic = State(initialValue: CustomOverlayMapStore.isPublic(id: overlay.id))
        self.onDeleted = onDeleted
        _checkpoints = State(initialValue: HistoricSiteCatalog.sites(forOverlayID: overlay.id))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                OverlayEditorMapView(
                    overlay: overlay,
                    checkpoints: checkpoints,
                    onTapMap: { coordinate in
                        newPointName = ""
                        newPointSummary = ""
                        pendingCoordinate = coordinate
                    },
                    onTapCheckpoint: { site in pointToDelete = site }
                )
                .ignoresSafeArea(edges: .bottom)

                Text("地図をタップしてポイントを追加、ポイントをタップして削除")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            .navigationTitle(overlay.shortTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完了") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            editedTitle = overlay.title
                            isRenaming = true
                        } label: {
                            Label("地図名を変更", systemImage: "pencil")
                        }

                        if !isBundled {
                            Picker(selection: publicBinding) {
                                Label("自分だけ", systemImage: "lock.fill").tag(false)
                                Label("公開", systemImage: "person.2.fill").tag(true)
                            } label: {
                                Label("公開範囲", systemImage: "eye")
                            }
                            .pickerStyle(.menu)
                        }

                        Button {
                            isShowingUpdateSheet = true
                        } label: {
                            Label("地図をアップデート", systemImage: "wand.and.stars")
                        }

                        Divider()

                        if isBundled {
                            Button(role: .destructive) {
                                isConfirmingResetOverlay = true
                            } label: {
                                Label("変更を元に戻す", systemImage: "arrow.uturn.backward")
                            }
                            .disabled(!OverlayOverrideStore.hasOverride(id: overlay.id))
                        } else {
                            Button(role: .destructive) {
                                isConfirmingDeleteOverlay = true
                            } label: {
                                Label("この古地図を削除", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("メニュー")
                }
            }
            .overlay(alignment: .bottom) {
                if isSyncingCloud || cloudErrorMessage != nil {
                    Text(cloudErrorMessage ?? "クラウドと同期中…")
                        .font(.caption.bold())
                        .foregroundStyle(cloudErrorMessage == nil ? Color.primary : Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            cloudErrorMessage == nil ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.red),
                            in: Capsule()
                        )
                        .padding(.bottom, 24)
                        .onTapGesture { cloudErrorMessage = nil }
                }
            }
            .alert("地図名を変更", isPresented: $isRenaming) {
                TextField("地図名", text: $editedTitle)
                Button("変更する") { renameOverlay() }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $isShowingUpdateSheet) {
                UpdateOverlayMapSheet(overlay: overlay) {
                    reloadOverlay()
                    resyncIfPublic()
                }
            }
            .alert("新しいポイントを追加", isPresented: Binding(
                get: { pendingCoordinate != nil },
                set: { if !$0 { pendingCoordinate = nil } }
            )) {
                TextField("名前", text: $newPointName)
                TextField("説明（任意）", text: $newPointSummary)
                Button("追加する") { addPoint() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("タップした場所にチェックポイントを追加します。")
            }
            .confirmationDialog(
                "このポイントを削除しますか？",
                isPresented: Binding(
                    get: { pointToDelete != nil },
                    set: { if !$0 { pointToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pointToDelete
            ) { site in
                Button("「\(site.name)」を削除", role: .destructive) {
                    if isBundled {
                        OverlayOverrideStore.removeCheckpoint(overlayID: overlay.id, siteID: site.id)
                    } else {
                        CustomOverlayMapStore.deleteCheckpoint(siteID: site.id)
                    }
                    checkpoints = HistoricSiteCatalog.sites(forOverlayID: overlay.id)
                    resyncIfPublic()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .confirmationDialog(
                "この古地図への変更を元に戻しますか？",
                isPresented: $isConfirmingResetOverlay,
                titleVisibility: .visible
            ) {
                Button("元に戻す", role: .destructive) {
                    OverlayOverrideStore.reset(id: overlay.id)
                    reloadOverlay()
                    checkpoints = HistoricSiteCatalog.sites(forOverlayID: overlay.id)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("名前・画像・ポイントの変更がすべて取り消され、アプリに同梱の内容に戻ります。")
            }
            .confirmationDialog(
                "この古地図を削除しますか？",
                isPresented: $isConfirmingDeleteOverlay,
                titleVisibility: .visible
            ) {
                Button("古地図とポイントをすべて削除", role: .destructive) {
                    let deletedID = overlay.id
                    let wasPublic = isPublic
                    let userID = authService.userID
                    CustomOverlayMapStore.deleteOverlay(id: deletedID)
                    if wasPublic {
                        Task { await OverlayMapShareService().unpublish(mapID: deletedID, userID: userID) }
                    }
                    onDeleted()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("追加したポイントも含めて削除され、元に戻せません。")
            }
        }
    }

    /// 公開範囲の切り替え。公開にする時はクラウドへ上げ、失敗したら元に戻す。
    private var publicBinding: Binding<Bool> {
        Binding(
            get: { isPublic },
            set: { newValue in
                guard newValue != isPublic else { return }
                Task { await setPublic(newValue) }
            }
        )
    }

    private func setPublic(_ newValue: Bool) async {
        isSyncingCloud = true
        cloudErrorMessage = nil
        defer { isSyncingCloud = false }
        if newValue {
            do {
                try await shareService.publish(
                    mapID: overlay.id, userID: authService.userID, ownerDisplayName: authService.displayName
                )
            } catch {
                cloudErrorMessage = error.localizedDescription
                return
            }
        } else {
            await shareService.unpublish(mapID: overlay.id, userID: authService.userID)
        }
        isPublic = newValue
        CustomOverlayMapStore.setPublic(id: overlay.id, newValue)
    }

    /// 公開中の古地図を編集した時に、クラウド側の公開データも作り直す。
    private func resyncIfPublic() {
        guard isPublic else { return }
        Task {
            isSyncingCloud = true
            defer { isSyncingCloud = false }
            do {
                try await shareService.publish(
                    mapID: overlay.id, userID: authService.userID, ownerDisplayName: authService.displayName
                )
            } catch {
                cloudErrorMessage = "公開中の地図の更新に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private func renameOverlay() {
        let title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if isBundled {
            OverlayOverrideStore.setTitle(id: overlay.id, title)
        } else {
            CustomOverlayMapStore.rename(id: overlay.id, to: title)
        }
        reloadOverlay()
        resyncIfPublic()
    }

    /// 保存済みの最新の内容（名前・画像）を読み直す。
    private func reloadOverlay() {
        if let latest = OldMapCatalog.overlay(withID: overlay.id) {
            overlay = latest
        }
    }

    private func addPoint() {
        guard let coordinate = pendingCoordinate else { return }
        let name = newPointName.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = newPointSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let pointName = name.isEmpty ? "新しいポイント" : name
        if isBundled {
            OverlayOverrideStore.addCheckpoint(
                toOverlayID: overlay.id, name: pointName, summary: summary, coordinate: coordinate
            )
        } else {
            CustomOverlayMapStore.addCheckpoint(
                toOverlayID: overlay.id, name: pointName, summary: summary, coordinate: coordinate
            )
        }
        pendingCoordinate = nil
        checkpoints = HistoricSiteCatalog.sites(forOverlayID: overlay.id)
        resyncIfPublic()
    }
}

/// 古地図とそのポイントだけを表示する、編集用の小さな地図。
private struct OverlayEditorMapView: UIViewRepresentable {
    let overlay: HistoricalOverlayMap
    let checkpoints: [HistoricSite]
    var onTapMap: (CLLocationCoordinate2D) -> Void
    var onTapCheckpoint: (HistoricSite) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView()
        mapView.delegate = context.coordinator
        let bounds = GMSCoordinateBounds(coordinate: overlay.southWest, coordinate: overlay.northEast)
        let groundOverlay = GMSGroundOverlay(bounds: bounds, icon: overlay.image)
        groundOverlay.opacity = 0.7
        groundOverlay.map = mapView
        context.coordinator.groundOverlay = groundOverlay
        context.coordinator.shownImageFileName = overlay.imageFileName
        mapView.moveCamera(GMSCameraUpdate.fit(bounds, withPadding: 24))
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTapMap = onTapMap
        coordinator.onTapCheckpoint = onTapCheckpoint
        // 画像を差し替えた時は、地図に貼った画像も入れ替える。
        if coordinator.shownImageFileName != overlay.imageFileName {
            coordinator.shownImageFileName = overlay.imageFileName
            coordinator.groundOverlay?.map = nil
            let bounds = GMSCoordinateBounds(coordinate: overlay.southWest, coordinate: overlay.northEast)
            let replacement = GMSGroundOverlay(bounds: bounds, icon: overlay.image)
            replacement.opacity = 0.7
            replacement.map = mapView
            coordinator.groundOverlay = replacement
        }
        coordinator.sitesByID = Dictionary(checkpoints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // ポイントの増減があった時だけマーカーを作り直す。
        let ids = Set(checkpoints.map(\.id))
        guard ids != coordinator.shownIDs else { return }
        coordinator.shownIDs = ids
        coordinator.markers.forEach { $0.map = nil }
        coordinator.markers = checkpoints.map { site in
            let marker = GMSMarker(position: site.coordinate)
            marker.title = site.name
            marker.icon = GMSMarker.markerImage(with: .shuiro)
            marker.userData = site.id
            marker.map = mapView
            return marker
        }
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onTapMap: (CLLocationCoordinate2D) -> Void = { _ in }
        var onTapCheckpoint: (HistoricSite) -> Void = { _ in }
        var sitesByID: [String: HistoricSite] = [:]
        var shownIDs: Set<String> = []
        var markers: [GMSMarker] = []
        var groundOverlay: GMSGroundOverlay?
        var shownImageFileName: String?

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            onTapMap(coordinate)
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let id = marker.userData as? String, let site = sitesByID[id] {
                onTapCheckpoint(site)
            }
            return true
        }
    }
}

/// 説明を入れて、AIに古地図の見た目をもっと綺麗にわかりやすく描き直してもらうシート。
/// いまの地図の画像をもとに、位置や範囲はそのままで絵だけを差し替える。
private struct UpdateOverlayMapSheet: View {
    let overlay: HistoricalOverlayMap
    var onUpdated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var instructions = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "例: 川と道をはっきり描いて、緑を増やし、全体を明るく見やすく",
                        text: $instructions,
                        axis: .vertical
                    )
                    .lineLimit(4...8)

                    Button {
                        Task { await update() }
                    } label: {
                        if isUpdating {
                            HStack {
                                ProgressView()
                                Text("アップデート中…")
                            }
                        } else {
                            Label("この内容でアップデート", systemImage: "wand.and.stars")
                        }
                    }
                    .disabled(isUpdating)
                } header: {
                    Text("どんな地図にしたいか")
                } footer: {
                    Text("いまの地図をもとに、説明に沿って、もっと綺麗でわかりやすい見た目にAIが描き直します（何も書かなければ、全体をより綺麗に整えます）。範囲やポイントの位置は変わりません。画像の生成はOpenAI・Googleで利用できます。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("地図をアップデート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(isUpdating)
                }
            }
            .interactiveDismissDisabled(isUpdating)
        }
    }

    private func update() async {
        guard let current = overlay.image else {
            errorMessage = "いまの地図の画像を読み込めませんでした。"
            return
        }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        let wish = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        Redraw this map illustration so that it is more beautiful, clear and easy to read. \
        Keep the same geographic layout, coastlines, rivers, roads and the position of every feature \
        so it still lines up with the original map, and keep the aged parchment look unless told otherwise. \
        Make roads, water, green areas and landmarks clearly distinguishable with harmonious colors. \
        The map is called "\(overlay.title)" (\(overlay.era)). \
        \(wish.isEmpty ? "" : "Follow these instructions from the user: \(wish). ")\
        Fill the entire square frame edge to edge, no border, no text, no letters, no legend.
        """
        do {
            let generated = try await AIClient.generateImage(prompt: prompt, referenceImage: current)
            if OldMapCatalog.isBundled(id: overlay.id) {
                OverlayOverrideStore.replaceImage(id: overlay.id, with: generated)
            } else {
                CustomOverlayMapStore.replaceImage(id: overlay.id, with: generated)
            }
            onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
