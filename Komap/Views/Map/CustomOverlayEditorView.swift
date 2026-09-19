import CoreLocation
import GoogleMaps
import SwiftUI

/// 追加した古地図を、地図の上で編集する画面。
/// 地図をタップしてポイントを追加し、ポイントをタップして削除する。古地図そのものの削除もここから行う。
struct CustomOverlayEditorView: View {
    let overlay: HistoricalOverlayMap
    /// 古地図を削除した時に呼ばれる。
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var checkpoints: [HistoricSite]
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    @State private var newPointName = ""
    @State private var newPointSummary = ""
    @State private var pointToDelete: HistoricSite?
    @State private var isConfirmingDeleteOverlay = false

    init(overlay: HistoricalOverlayMap, onDeleted: @escaping () -> Void = {}) {
        self.overlay = overlay
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
                    Button("古地図を削除", role: .destructive) { isConfirmingDeleteOverlay = true }
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
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
                    CustomOverlayMapStore.deleteCheckpoint(siteID: site.id)
                    checkpoints = HistoricSiteCatalog.sites(forOverlayID: overlay.id)
                }
                Button("キャンセル", role: .cancel) {}
            }
            .confirmationDialog(
                "この古地図を削除しますか？",
                isPresented: $isConfirmingDeleteOverlay,
                titleVisibility: .visible
            ) {
                Button("古地図とポイントをすべて削除", role: .destructive) {
                    CustomOverlayMapStore.deleteOverlay(id: overlay.id)
                    onDeleted()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("追加したポイントも含めて削除され、元に戻せません。")
            }
        }
    }

    private func addPoint() {
        guard let coordinate = pendingCoordinate else { return }
        let name = newPointName.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = newPointSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        CustomOverlayMapStore.addCheckpoint(
            toOverlayID: overlay.id,
            name: name.isEmpty ? "新しいポイント" : name,
            summary: summary,
            coordinate: coordinate
        )
        pendingCoordinate = nil
        checkpoints = HistoricSiteCatalog.sites(forOverlayID: overlay.id)
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
        mapView.moveCamera(GMSCameraUpdate.fit(bounds, withPadding: 24))
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTapMap = onTapMap
        coordinator.onTapCheckpoint = onTapCheckpoint
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
