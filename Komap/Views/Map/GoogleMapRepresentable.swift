import CoreLocation
import GoogleMaps
import SwiftUI

/// `GMSMapView` をSwiftUIに橋渡しするラッパー。
///
/// 現在地表示・古地図のグラウンドオーバーレイ（不透明度つき）・
/// タップ地点の検出を担当する。
struct GoogleMapRepresentable: UIViewRepresentable {
    var overlayMap: HistoricalOverlayMap?
    var overlayOpacity: Float
    /// カメラを移動させたい座標のリクエスト。同じ`id`には一度だけ反応する
    /// （同じ座標への再移動要求も、`id`が新しければ改めて移動する）。
    var moveCameraRequest: CameraMoveRequest?
    /// 画面下部に浮かせているパネルの高さ分、現在地ボタンなど純正コントロールを
    /// 押し上げるための余白（パネルに隠れてボタンが押せなくなるのを防ぐ）。
    var bottomInset: CGFloat = 0
    /// 過去に記録して保存済みの徒歩ルート（複数）。
    var savedWalkPaths: [[CLLocationCoordinate2D]] = []
    /// 「スタート」ボタンで記録中の、現在進行形の徒歩ルート。
    var liveWalkPath: [CLLocationCoordinate2D] = []
    /// 地図上に強調表示する史跡チェックポイント一覧。
    var checkpoints: [HistoricSite] = []
    /// 既に御朱印を獲得済みのチェックポイントID（マーカーの色分けに使う）。
    var collectedSiteIDs: Set<String> = []
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> GMSMapView {
        let initialCamera = GMSCameraPosition.camera(
            withLatitude: overlayMap?.center.latitude ?? 35.6812,
            longitude: overlayMap?.center.longitude ?? 139.767,
            zoom: 15
        )
        let mapView = GMSMapView()
        mapView.camera = initialCamera
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.applyOverlay(overlayMap, opacity: overlayOpacity, to: mapView)
        context.coordinator.applyWalkPaths(saved: savedWalkPaths, live: liveWalkPath, to: mapView)
        context.coordinator.applyCheckpoints(checkpoints, collectedSiteIDs: collectedSiteIDs, to: mapView)
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)

        if let request = moveCameraRequest, context.coordinator.lastHandledMoveRequestID != request.id {
            context.coordinator.lastHandledMoveRequestID = request.id
            mapView.animate(to: GMSCameraPosition.camera(withTarget: request.coordinate, zoom: mapView.camera.zoom))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onTap: (CLLocationCoordinate2D) -> Void
        var lastHandledMoveRequestID: UUID?

        private var currentOverlay: GMSGroundOverlay?
        private var currentOverlayID: String?

        private var savedPolylines: [GMSPolyline] = []
        private var livePolyline: GMSPolyline?
        private var checkpointMarkers: [String: GMSMarker] = [:]

        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onTap = onTap
        }

        func applyOverlay(_ overlayMap: HistoricalOverlayMap?, opacity: Float, to mapView: GMSMapView) {
            guard let overlayMap else {
                currentOverlay?.map = nil
                currentOverlay = nil
                currentOverlayID = nil
                return
            }

            if currentOverlayID != overlayMap.id {
                currentOverlay?.map = nil

                let bounds = GMSCoordinateBounds(
                    coordinate: overlayMap.southWest,
                    coordinate: overlayMap.northEast
                )
                let overlay = GMSGroundOverlay(bounds: bounds, icon: UIImage(named: overlayMap.imageAssetName))
                overlay.opacity = opacity
                overlay.map = mapView
                currentOverlay = overlay
                currentOverlayID = overlayMap.id
            } else {
                currentOverlay?.opacity = opacity
            }
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            onTap(coordinate)
        }

        /// 保存済みの徒歩ルートと、記録中のルートをそれぞれポリラインで塗り分ける。
        func applyWalkPaths(
            saved: [[CLLocationCoordinate2D]],
            live: [CLLocationCoordinate2D],
            to mapView: GMSMapView
        ) {
            // 保存済みルートは件数が変わった時だけ作り直す（記録終了で1件増える程度の頻度）。
            if saved.count != savedPolylines.count {
                savedPolylines.forEach { $0.map = nil }
                savedPolylines = saved.map { coordinates in
                    makePolyline(for: coordinates, strokeColor: .systemBlue, strokeWidth: 4, on: mapView)
                }
            }

            guard live.count >= 2 else {
                livePolyline?.map = nil
                livePolyline = nil
                return
            }

            let path = GMSMutablePath()
            live.forEach { path.add($0) }
            if let livePolyline {
                livePolyline.path = path
            } else {
                livePolyline = makePolyline(path: path, strokeColor: .systemOrange, strokeWidth: 5, on: mapView)
            }
        }

        private func makePolyline(
            for coordinates: [CLLocationCoordinate2D],
            strokeColor: UIColor,
            strokeWidth: CGFloat,
            on mapView: GMSMapView
        ) -> GMSPolyline {
            let path = GMSMutablePath()
            coordinates.forEach { path.add($0) }
            return makePolyline(path: path, strokeColor: strokeColor, strokeWidth: strokeWidth, on: mapView)
        }

        private func makePolyline(
            path: GMSMutablePath,
            strokeColor: UIColor,
            strokeWidth: CGFloat,
            on mapView: GMSMapView
        ) -> GMSPolyline {
            let polyline = GMSPolyline(path: path)
            polyline.strokeColor = strokeColor
            polyline.strokeWidth = strokeWidth
            polyline.map = mapView
            return polyline
        }

        /// 史跡チェックポイントをマーカーとして描画し、獲得済みかどうかで色を塗り分ける。
        /// 古地図の切り替えでチェックポイントの顔ぶれが変わるため、対象外になった
        /// マーカーはここで取り除く。
        func applyCheckpoints(
            _ checkpoints: [HistoricSite],
            collectedSiteIDs: Set<String>,
            to mapView: GMSMapView
        ) {
            let currentIDs = Set(checkpoints.map(\.id))
            let staleIDs = checkpointMarkers.keys.filter { !currentIDs.contains($0) }
            for siteID in staleIDs {
                checkpointMarkers[siteID]?.map = nil
                checkpointMarkers.removeValue(forKey: siteID)
            }

            for site in checkpoints where checkpointMarkers[site.id] == nil {
                let marker = GMSMarker(position: site.coordinate)
                marker.title = site.name
                marker.snippet = site.summary
                marker.map = mapView
                checkpointMarkers[site.id] = marker
            }

            for (siteID, marker) in checkpointMarkers {
                let isCollected = collectedSiteIDs.contains(siteID)
                marker.icon = GMSMarker.markerImage(
                    with: isCollected ? .systemYellow : .systemBrown
                )
                marker.opacity = isCollected ? 1.0 : 0.85
            }
        }
    }
}
