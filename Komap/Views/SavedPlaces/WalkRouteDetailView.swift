import CoreLocation
import GoogleMaps
import SwiftData
import SwiftUI

/// 保存した1回分の時間旅行（ウォーキング記録）の詳細。
/// 使っていた古地図・歩いたルート（塗りつぶした地図）・通ったチェックポイントと御朱印・
/// アップした写真をまとめて表示する。
struct WalkRouteDetailView: View {
    let route: WalkRoute

    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var collectedStamps: [CollectedStamp]
    @Query private var photoPosts: [WalkPhotoPost]

    @State private var isRenaming = false
    @State private var editedTitle = ""
    @State private var isConfirmingDelete = false
    @State private var selectedPhotoPost: WalkPhotoPost?
    @State private var selectedStamp: StampSelection?
    @State private var isUpdatingShare = false
    @State private var shareErrorMessage: String?

    private let syncService = SyncService()

    private var stampsForRoute: [CollectedStamp] {
        collectedStamps
            .filter { $0.walkRouteID == route.id }
            .sorted { $0.collectedAt < $1.collectedAt }
    }

    private var photoPostsForRoute: [WalkPhotoPost] {
        photoPosts
            .filter { $0.walkRouteID == route.id }
            .sorted { $0.postedAt < $1.postedAt }
    }

    private var checkpointsForOverlay: [HistoricSite] {
        HistoricSiteCatalog.sites(forOverlayID: route.overlayMapID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WalkRouteMapView(
                    overlayMap: route.overlayMap,
                    overlayOpacity: Float(route.overlayOpacity),
                    path: route.coordinates,
                    checkpoints: checkpointsForOverlay,
                    collectedSiteIDs: Set(stampsForRoute.map(\.siteID))
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                header

                if !photoPostsForRoute.isEmpty {
                    photoPostsSection
                }

                if !stampsForRoute.isEmpty {
                    checkpointsSection
                }
            }
            .padding()
        }
        .navigationTitle("時間旅の記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editedTitle = route.title ?? ""
                        isRenaming = true
                    } label: {
                        Label("名前を変更", systemImage: "pencil")
                    }
                    Button {
                        Task { await togglePublicSharing() }
                    } label: {
                        if route.isSharedPublicly {
                            Label("「みんなの時空旅」への公開をやめる", systemImage: "person.2.slash")
                        } else {
                            Label("「みんなの時空旅」に公開する", systemImage: "person.2.fill")
                        }
                    }
                    .disabled(isUpdatingShare)
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("時間旅の名前", isPresented: $isRenaming) {
            TextField("例: 皇居さんぽ", text: $editedTitle)
            Button("保存する") {
                let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                route.title = trimmed.isEmpty ? nil : trimmed
                try? modelContext.save()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "この時間旅を削除しますか？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                modelContext.delete(route)
                try? modelContext.save()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("歩いたルートの記録が削除されます。この操作は取り消せません。")
        }
        .sheet(item: $selectedPhotoPost) { post in
            PhotoPostPreviewSheet(post: post)
        }
        .sheet(item: $selectedStamp) { selection in
            StampCheckInSheet(site: selection.site, stamp: selection.stamp)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = route.title, !title.isEmpty {
                Text(title)
                    .font(.title3.bold())
                Text(route.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(route.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.title3.bold())
            }

            Text(route.overlayMap?.title ?? "古地図なし")
                .font(.subheadline.bold())
                .foregroundStyle(.brown)

            if route.isSharedPublicly {
                Label("みんなの時空旅に公開中", systemImage: "person.2.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }

            if let shareErrorMessage {
                Text(shareErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Label(distanceText, systemImage: "figure.walk")
                if let durationText {
                    Label(durationText, systemImage: "clock")
                }
                if let stepCount = route.stepCount {
                    Label("\(stepCount)歩", systemImage: "shoeprints.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label("御朱印 \(stampsForRoute.count)件", systemImage: "seal.fill")
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                if !photoPostsForRoute.isEmpty {
                    Label("写真 \(photoPostsForRoute.count)件", systemImage: "camera.fill")
                        .foregroundStyle(Color(red: 0.86, green: 0.63, blue: 0.24))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var photoPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投稿した写真")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(photoPostsForRoute) { post in
                    if let photo = post.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture {
                                selectedPhotoPost = post
                            }
                    }
                }
            }
        }
    }

    private var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通ったチェックポイント")
                .font(.headline)

            ForEach(stampsForRoute) { stamp in
                if let site = stamp.site {
                    CheckpointRow(site: site, stamp: stamp)
                        .onTapGesture {
                            selectedStamp = StampSelection(site: site, stamp: stamp)
                        }
                }
            }
        }
    }

    /// 「みんなの時空旅」への公開・非公開を切り替える。
    private func togglePublicSharing() async {
        isUpdatingShare = true
        shareErrorMessage = nil
        let newValue = !route.isSharedPublicly
        do {
            try await syncService.setPubliclyShared(
                route,
                isShared: newValue,
                userID: authService.userID,
                ownerDisplayName: authService.displayName
            )
            route.isSharedPublicly = newValue
            try? modelContext.save()
        } catch {
            shareErrorMessage = "共有の変更に失敗しました: \(error.localizedDescription)"
        }
        isUpdatingShare = false
    }

    private var distanceText: String {
        let meters = route.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private var durationText: String? {
        guard let durationSeconds = route.durationSeconds else { return nil }
        let totalMinutes = Int(durationSeconds / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)時間\(totalMinutes % 60)分"
        }
        return "\(max(totalMinutes, 1))分"
    }
}

/// この時間旅で獲得した1つのチェックポイント（史跡・御朱印・アップした写真）を表す行。
private struct CheckpointRow: View {
    let site: HistoricSite
    let stamp: CollectedStamp

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let photo = stamp.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                    .frame(width: 56, height: 56)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .font(.subheadline.bold())
                Text(site.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(stamp.collectedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

/// 歩いたルート（＝自分が通って塗りつぶした地図）を、使っていた古地図・
/// チェックポイントと一緒に表示する、操作不要の小さな地図。
private struct WalkRouteMapView: UIViewRepresentable {
    let overlayMap: HistoricalOverlayMap?
    let overlayOpacity: Float
    let path: [CLLocationCoordinate2D]
    let checkpoints: [HistoricSite]
    let collectedSiteIDs: Set<String>

    func makeUIView(context: Context) -> GMSMapView {
        let initialCamera = GMSCameraPosition.camera(
            withLatitude: overlayMap?.center.latitude ?? path.first?.latitude ?? 35.6812,
            longitude: overlayMap?.center.longitude ?? path.first?.longitude ?? 139.767,
            zoom: 15
        )
        let mapView = GMSMapView()
        mapView.camera = initialCamera
        mapView.settings.scrollGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false

        if let overlayMap {
            let bounds = GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
            let overlay = GMSGroundOverlay(bounds: bounds, icon: overlayMap.image)
            overlay.opacity = overlayOpacity
            overlay.map = mapView
        }

        if path.count >= 2 {
            let gmsPath = GMSMutablePath()
            path.forEach { gmsPath.add($0) }

            let border = GMSPolyline(path: gmsPath)
            border.strokeColor = .walkedTrailBorder
            border.strokeWidth = 9
            border.zIndex = 0
            border.map = mapView

            let fill = GMSPolyline(path: gmsPath)
            fill.strokeColor = .walkedTrailFill
            fill.strokeWidth = 6
            fill.zIndex = 1
            fill.map = mapView
        }

        for site in checkpoints {
            let marker = GMSMarker(position: site.coordinate)
            marker.title = site.name
            marker.icon = GMSMarker.markerImage(with: .shuiro)
            marker.opacity = collectedSiteIDs.contains(site.id) ? 1.0 : 0.6
            marker.map = mapView
        }

        var pathBounds: GMSCoordinateBounds?
        for coordinate in path {
            pathBounds = pathBounds?.includingCoordinate(coordinate)
                ?? GMSCoordinateBounds(coordinate: coordinate, coordinate: coordinate)
        }
        if let pathBounds {
            mapView.moveCamera(GMSCameraUpdate.fit(pathBounds, withPadding: 32))
        }

        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {}
}

#Preview {
    NavigationStack {
        WalkRouteDetailView(
            route: WalkRoute(
                coordinates: [
                    CLLocationCoordinate2D(latitude: 35.6773, longitude: 139.7539),
                    CLLocationCoordinate2D(latitude: 35.6822, longitude: 139.7565),
                ],
                overlayMapID: OldMapCatalog.edoCastle.id
            )
        )
    }
    .modelContainer(for: [WalkRoute.self, CollectedStamp.self, WalkPhotoPost.self], inMemory: true)
}
