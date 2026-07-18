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
    }
}
