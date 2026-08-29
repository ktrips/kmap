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
    /// カメラを移動させたい座標。値がセットされる度に一度だけ移動する。
    var moveCameraTo: CLLocationCoordinate2D?
    /// 画面下部に浮かせているパネルの高さ分、現在地ボタンなど純正コントロールを
    /// 押し上げるための余白（パネルに隠れてボタンが押せなくなるのを防ぐ）。
    var bottomInset: CGFloat = 0
    /// 過去に記録して保存済みの徒歩ルート（複数）。
    var savedWalkPaths: [[CLLocationCoordinate2D]] = []
    /// 「スタート」ボタンで記録中の、現在進行形の徒歩ルート。
    var liveWalkPath: [CLLocationCoordinate2D] = []
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
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)

        if let target = moveCameraTo, !context.coordinator.hasMoved(to: target) {
            context.coordinator.lastMovedCoordinate = target
            mapView.animate(to: GMSCameraPosition.camera(withTarget: target, zoom: mapView.camera.zoom))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onTap: (CLLocationCoordinate2D) -> Void
        var lastMovedCoordinate: CLLocationCoordinate2D?

        private var currentOverlay: GMSGroundOverlay?
        private var currentOverlayID: String?

        private var savedPolylines: [GMSPolyline] = []
        private var livePolyline: GMSPolyline?

        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onTap = onTap
        }

        func hasMoved(to target: CLLocationCoordinate2D) -> Bool {
            guard let last = lastMovedCoordinate else { return false }
            return last.latitude == target.latitude && last.longitude == target.longitude
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
    }
}
