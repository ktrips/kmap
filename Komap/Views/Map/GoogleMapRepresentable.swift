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
    /// 記録中に投稿した写真。地図上にピンとして共有表示する。
    var photoPosts: [WalkPhotoPost] = []
    var onTap: (CLLocationCoordinate2D) -> Void
    /// チェックポイントのマーカーに表示される小さなアイコンボタンがタップされた時に呼ばれる。
    var onCheckpointTap: (HistoricSite) -> Void = { _ in }
    /// 投稿写真のピンがタップされた時に呼ばれる。
    var onPhotoPostTap: (WalkPhotoPost) -> Void = { _ in }

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
        context.coordinator.onCheckpointTap = onCheckpointTap
        context.coordinator.onPhotoPostTap = onPhotoPostTap
        context.coordinator.applyOverlay(overlayMap, opacity: overlayOpacity, livePath: liveWalkPath, to: mapView)
        context.coordinator.applyWalkPaths(saved: savedWalkPaths, live: liveWalkPath, to: mapView)
        context.coordinator.applyCheckpoints(checkpoints, collectedSiteIDs: collectedSiteIDs, to: mapView)
        context.coordinator.applyPhotoPosts(photoPosts, to: mapView)
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
        var onCheckpointTap: (HistoricSite) -> Void = { _ in }
        var onPhotoPostTap: (WalkPhotoPost) -> Void = { _ in }
        var lastHandledMoveRequestID: UUID?

        private var currentOverlay: GMSGroundOverlay?
        private var currentOverlayID: String?
        private var currentBaseImage: UIImage?
        private var lastRevealedPointCount = 0

        private var savedPolylines: [GMSPolyline] = []
        private var livePolyline: GMSPolyline?
        private var checkpointMarkers: [String: GMSMarker] = [:]
        private var photoPostMarkers: [UUID: GMSMarker] = [:]

        /// 歩いた場所を中心に、この幅（メートル）だけ古地図をはっきり見せる。
        private let revealCorridorMeters: Double = 45

        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onTap = onTap
        }

        /// 古地図を貼り替える。記録中の軌跡（`livePath`）が2点以上あれば、
        /// 通った場所だけくっきり見えるよう画像を合成し直す。それ以外は
        /// スライダーの不透明度をそのまま全体にかける、これまで通りの表示。
        func applyOverlay(
            _ overlayMap: HistoricalOverlayMap?,
            opacity: Float,
            livePath: [CLLocationCoordinate2D],
            to mapView: GMSMapView
        ) {
            guard let overlayMap else {
                currentOverlay?.map = nil
                currentOverlay = nil
                currentOverlayID = nil
                currentBaseImage = nil
                lastRevealedPointCount = 0
                return
            }

            let isNewOverlay = currentOverlayID != overlayMap.id
            if isNewOverlay {
                currentOverlay?.map = nil
                currentBaseImage = overlayMap.image
                lastRevealedPointCount = 0

                let bounds = GMSCoordinateBounds(
                    coordinate: overlayMap.southWest,
                    coordinate: overlayMap.northEast
                )
                let overlay = GMSGroundOverlay(bounds: bounds, icon: currentBaseImage)
                overlay.opacity = 1
                overlay.map = mapView
                currentOverlay = overlay
                currentOverlayID = overlayMap.id
            }

            guard let currentOverlay, let baseImage = currentBaseImage else { return }

            if livePath.count >= 2 {
                // 記録中はスライダーの不透明度を「まだ通っていない場所」の薄さとして使い、
                // 通った場所だけくっきり見えるように画像を合成し直す。
                if isNewOverlay || livePath.count != lastRevealedPointCount {
                    lastRevealedPointCount = livePath.count
                    currentOverlay.icon = Self.revealedImage(
                        base: baseImage,
                        southWest: overlayMap.southWest,
                        northEast: overlayMap.northEast,
                        path: livePath,
                        corridorMeters: revealCorridorMeters,
                        faintAlpha: CGFloat(opacity)
                    )
                }
            } else {
                // 記録していない時は、これまで通りスライダーの不透明度を全体にかける。
                if lastRevealedPointCount != 0 {
                    currentOverlay.icon = baseImage
                    lastRevealedPointCount = 0
                }
                currentOverlay.opacity = opacity
            }
        }

        /// 古地図の画像に、`path`に沿った太い帯（`corridorMeters`幅）だけくっきり見せ、
        /// それ以外は`faintAlpha`で薄く見せた画像を合成する。
        private static func revealedImage(
            base: UIImage,
            southWest: CLLocationCoordinate2D,
            northEast: CLLocationCoordinate2D,
            path: [CLLocationCoordinate2D],
            corridorMeters: Double,
            faintAlpha: CGFloat
        ) -> UIImage? {
            guard let cgImage = base.cgImage else { return base }
            let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
            guard pixelSize.width > 0, pixelSize.height > 0 else { return base }

            let latSpan = northEast.latitude - southWest.latitude
            let lngSpan = northEast.longitude - southWest.longitude
            guard latSpan > 0, lngSpan > 0 else { return base }

            // 緯度1度あたりの実距離はほぼ一定だが、経度1度あたりの実距離は緯度に応じて縮む。
            let centerLatRadians = (southWest.latitude + northEast.latitude) / 2 * .pi / 180
            let metersPerDegreeLat = 111_320.0
            let metersPerDegreeLng = 111_320.0 * cos(centerLatRadians)
            let pixelsPerMeterX = pixelSize.width / (lngSpan * metersPerDegreeLng)
            let pixelsPerMeterY = pixelSize.height / (latSpan * metersPerDegreeLat)
            let corridorWidthPixels = max(CGFloat(corridorMeters) * CGFloat((pixelsPerMeterX + pixelsPerMeterY) / 2), 6)

            func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
                let x = (coordinate.longitude - southWest.longitude) / lngSpan * pixelSize.width
                let y = (northEast.latitude - coordinate.latitude) / latSpan * pixelSize.height
                return CGPoint(x: x, y: y)
            }

            let renderer = UIGraphicsImageRenderer(size: pixelSize)
            let composited = renderer.image { context in
                let cg = context.cgContext
                let fullRect = CGRect(origin: .zero, size: pixelSize)

                // まず全体を薄く描く（まだ通っていない場所の見え方）。
                base.draw(in: fullRect, blendMode: .normal, alpha: faintAlpha)

                // 通った場所だけ、太い帯でくっきり見せる。
                cg.saveGState()
                cg.setLineWidth(corridorWidthPixels)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                let corridorPath = CGMutablePath()
                let points = path.map(point(for:))
                if let first = points.first {
                    corridorPath.move(to: first)
                    for p in points.dropFirst() {
                        corridorPath.addLine(to: p)
                    }
                }
                cg.addPath(corridorPath)
                cg.replacePathWithStrokedPath()
                cg.clip()
                base.draw(in: fullRect, blendMode: .normal, alpha: 1)
                cg.restoreGState()
            }
            return composited
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            onTap(coordinate)
        }

        /// チェックポイントのマーカーをタップした時に出す情報ウィンドウを、
        /// 吹き出しではなく小さな丸いアイコンボタンとして描画する。
        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            guard marker.userData is HistoricSite else { return nil }

            let size: CGFloat = 40
            let button = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            button.backgroundColor = .white
            button.layer.cornerRadius = size / 2
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.2
            button.layer.shadowRadius = 4
            button.layer.shadowOffset = CGSize(width: 0, height: 2)

            let iconSize: CGFloat = 20
            let icon = UIImageView(image: UIImage(systemName: "text.book.closed.fill"))
            icon.tintColor = .systemBrown
            icon.contentMode = .scaleAspectFit
            icon.frame = CGRect(
                x: (size - iconSize) / 2,
                y: (size - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            button.addSubview(icon)

            return button
        }

        /// 小さなアイコンボタン（情報ウィンドウ）がタップされたら、その地域の物語を表示する。
        func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
            guard let site = marker.userData as? HistoricSite else { return }
            onCheckpointTap(site)
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
                livePolyline = makePolyline(path: path, strokeColor: .systemOrange, strokeWidth: 8, on: mapView)
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
                marker.userData = site
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

        /// 記録中に投稿した写真を、その場所に丸いサムネイルのピンとして地図上に共有表示する。
        func applyPhotoPosts(_ posts: [WalkPhotoPost], to mapView: GMSMapView) {
            let currentIDs = Set(posts.map(\.id))
            let staleIDs = photoPostMarkers.keys.filter { !currentIDs.contains($0) }
            for id in staleIDs {
                photoPostMarkers[id]?.map = nil
                photoPostMarkers.removeValue(forKey: id)
            }

            for post in posts where photoPostMarkers[post.id] == nil {
                guard let photo = post.photo else { continue }
                let marker = GMSMarker(position: post.coordinate)
                marker.icon = Self.circularThumbnail(photo)
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.userData = post
                marker.map = mapView
                photoPostMarkers[post.id] = marker
            }
        }

        /// 写真ピンがタップされたら、吹き出しを出さずに直接プレビューを開く。
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let post = marker.userData as? WalkPhotoPost else { return false }
            onPhotoPostTap(post)
            return true
        }

        /// 投稿写真をピン用に、金色の縁取りをつけた丸いサムネイルへ変換する。
        private static func circularThumbnail(_ image: UIImage, diameter: CGFloat = 44) -> UIImage {
            let borderWidth: CGFloat = 3
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
            return renderer.image { context in
                let rect = CGRect(x: borderWidth / 2, y: borderWidth / 2, width: diameter - borderWidth, height: diameter - borderWidth)
                let clipPath = UIBezierPath(ovalIn: rect)
                context.cgContext.saveGState()
                clipPath.addClip()

                let imageAspect = image.size.width / image.size.height
                var drawRect = rect
                if imageAspect > 1 {
                    drawRect.size.width = rect.height * imageAspect
                    drawRect.origin.x -= (drawRect.width - rect.width) / 2
                } else {
                    drawRect.size.height = rect.width / imageAspect
                    drawRect.origin.y -= (drawRect.height - rect.height) / 2
                }
                image.draw(in: drawRect)
                context.cgContext.restoreGState()

                UIColor(red: 0.86, green: 0.63, blue: 0.24, alpha: 1).setStroke()
                clipPath.lineWidth = borderWidth
                clipPath.stroke()
            }
        }
    }
}
