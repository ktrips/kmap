import CoreImage
import CoreImage.CIFilterBuiltins
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
    /// `true`の間は`overlayMap`単体ではなく、同梱・登録済みの古地図すべてを
    /// 地図上に重ねて表示する（「全ての古地図を表示」選択時）。
    var showAllOverlays: Bool = false
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
        // 歩いた道の朱色をくっきり引き立たせるため、地図自体は少しだけ彩度を落としておく。
        mapView.mapStyle = try? GMSMapStyle(jsonString: Self.mutedMapStyleJSON)
        return mapView
    }

    private static let mutedMapStyleJSON = """
    [
      {"elementType": "geometry", "stylers": [{"saturation": -35}, {"lightness": 8}]},
      {"elementType": "labels.text.fill", "stylers": [{"saturation": -25}]},
      {"elementType": "labels.icon", "stylers": [{"saturation": -35}]}
    ]
    """

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onCheckpointTap = onCheckpointTap
        context.coordinator.onPhotoPostTap = onPhotoPostTap
        if showAllOverlays {
            context.coordinator.applyAllOverlays(OldMapCatalog.allIncludingCustom, to: mapView)
        } else {
            context.coordinator.removeAllOverlays()
            context.coordinator.applyOverlay(overlayMap, opacity: overlayOpacity, livePath: liveWalkPath, checkpoints: checkpoints, to: mapView)
        }
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
        /// 「全ての古地図を表示」中に、同梱・登録済みの古地図それぞれに対応するグラウンドオーバーレイ。
        private var allOverlays: [GMSGroundOverlay] = []
        private var currentBaseImage: UIImage?
        /// まだ通っていない場所用に、あらかじめぼかしておいた画像（古地図が変わる度に作り直す）。
        private var currentBlurredImage: UIImage?
        private var lastRevealedPointCount = 0

        private var savedPolylinePairs: [TrailPolylinePair] = []
        private var liveTrailPair: TrailPolylinePair?
        private var checkpointMarkers: [String: GMSMarker] = [:]
        private var photoPostMarkers: [UUID: GMSMarker] = [:]

        /// 歩いた場所を中心に、この幅（メートル）だけ古地図を宝探しのようにはっきり見せる。
        private let revealCorridorMeters: Double = 70
        /// 歩いた道の縁取りの太さ（画面上のポイント数）。中の透かし塗りよりわずかに太いだけの、
        /// 細く濃い縁として見せる。
        private let walkedTrailBorderWidth: CGFloat = 9
        /// 歩いた道の中を薄く塗る太さ。縁取りより一回り細くすることで、縁だけが濃い線として残り、
        /// 中央は明るい色が重なって薄く見える。
        private let walkedTrailFillWidth: CGFloat = 6

        /// 縁取り（細い線）と内側の透かし塗りの2本を重ねて、1本の「通った道」を表す組。
        private struct TrailPolylinePair {
            let border: GMSPolyline
            let fill: GMSPolyline

            func setPath(_ path: GMSMutablePath) {
                border.path = path
                fill.path = path
            }

            func remove() {
                border.map = nil
                fill.map = nil
            }
        }

        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onTap = onTap
        }

        /// 「全ての古地図を表示」用に、渡された古地図すべてをグラウンドオーバーレイとして重ねる。
        /// 一度重ねたら（一覧が変わらない限り）作り直さず、初回だけ全体が収まるようカメラを合わせる。
        func applyAllOverlays(_ overlays: [HistoricalOverlayMap], to mapView: GMSMapView) {
            currentOverlay?.map = nil
            currentOverlay = nil
            currentOverlayID = nil

            guard allOverlays.count != overlays.count else { return }
            allOverlays.forEach { $0.map = nil }

            // 画像の読み込み・デコードは重いので、まず枠だけ（画像なし）のオーバーレイを
            // メインスレッドで即座に置いてから、それぞれの画像をバックグラウンドで
            // デコードして後から差し込む。10枚分をまとめて同期デコードすると
            // メインスレッドが固まって表示がもたつくため。
            allOverlays = overlays.map { overlayMap in
                let bounds = GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
                let overlay = GMSGroundOverlay(bounds: bounds, icon: nil)
                overlay.opacity = 0.75
                overlay.map = mapView
                return overlay
            }

            for (overlay, overlayMap) in zip(allOverlays, overlays) {
                DispatchQueue.global(qos: .userInitiated).async { [weak overlay] in
                    let image = overlayMap.image
                    DispatchQueue.main.async {
                        overlay?.icon = image
                    }
                }
            }

            var combinedBounds: GMSCoordinateBounds?
            for overlayMap in overlays {
                combinedBounds = combinedBounds?.includingCoordinate(overlayMap.southWest).includingCoordinate(overlayMap.northEast)
                    ?? GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
            }
            if let combinedBounds {
                mapView.moveCamera(GMSCameraUpdate.fit(combinedBounds, withPadding: 24))
            }
        }

        /// 「全ての古地図を表示」を抜けた時に、重ねていたグラウンドオーバーレイをすべて取り除く。
        func removeAllOverlays() {
            guard !allOverlays.isEmpty else { return }
            allOverlays.forEach { $0.map = nil }
            allOverlays = []
        }

        /// 古地図を貼り替える。記録中の軌跡（`livePath`）が2点以上あれば、
        /// 通った場所だけくっきり見えるよう画像を合成し直す。それ以外は
        /// スライダーの不透明度をそのまま全体にかける、これまで通りの表示。
        func applyOverlay(
            _ overlayMap: HistoricalOverlayMap?,
            opacity: Float,
            livePath: [CLLocationCoordinate2D],
            checkpoints: [HistoricSite] = [],
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
                currentBlurredImage = nil
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

                // 古地図の範囲だけでなく、その古地図のチェックポイントも収まるようカメラを合わせる
                // （古地図の位置合わせが実際の座標と少しずれていても、チェックポイントが画面外に
                // 出てしまわないようにする）。
                var fitBounds = bounds
                for checkpoint in checkpoints where checkpoint.overlayMapID == overlayMap.id {
                    fitBounds = fitBounds.includingCoordinate(checkpoint.coordinate)
                }
                mapView.moveCamera(GMSCameraUpdate.fit(fitBounds, withPadding: 24))

                // ぼかし画像の生成は重いので、メインスレッドをブロックしないよう
                // バックグラウンドで計算してから後で使う（先に元画像で表示しておく）。
                if let baseImage = currentBaseImage {
                    let overlayID = overlayMap.id
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        let blurred = Self.blurredImage(baseImage)
                        DispatchQueue.main.async {
                            guard self?.currentOverlayID == overlayID else { return }
                            self?.currentBlurredImage = blurred
                        }
                    }
                }
            }

            guard let currentOverlay, let baseImage = currentBaseImage else { return }

            if livePath.count >= 2 {
                // 記録中はスライダーの不透明度を「まだ通っていない場所」の薄さとして使い、
                // 通った場所だけくっきり見えるように画像を合成し直す。
                // 合成処理は重いのでメインスレッドをブロックしないようバックグラウンドで行う。
                if isNewOverlay || livePath.count != lastRevealedPointCount {
                    lastRevealedPointCount = livePath.count
                    let southWest = overlayMap.southWest
                    let northEast = overlayMap.northEast
                    let corridorMeters = revealCorridorMeters
                    let faintAlpha = CGFloat(opacity)
                    let blurredBase = currentBlurredImage ?? baseImage
                    let overlayRef = currentOverlay
                    DispatchQueue.global(qos: .userInitiated).async {
                        let image = Self.revealedImage(
                            base: baseImage,
                            blurredBase: blurredBase,
                            southWest: southWest,
                            northEast: northEast,
                            path: livePath,
                            corridorMeters: corridorMeters,
                            faintAlpha: faintAlpha
                        )
                        DispatchQueue.main.async {
                            overlayRef.icon = image
                        }
                    }
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
        /// それ以外はぼかした上で`faintAlpha`で薄く見せた画像を合成する（宝探しのような演出）。
        private static func revealedImage(
            base: UIImage,
            blurredBase: UIImage,
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

                // まず全体を、ぼかした上で薄く描く（まだ通っていない場所の見え方）。
                blurredBase.draw(in: fullRect, blendMode: .normal, alpha: faintAlpha)

                // 通った場所だけ、太い帯でくっきり鮮明に見せる。
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

        /// `CIContext`はGPUコンテキストの初期化コストが大きいため、呼び出しのたびに
        /// 作り直さず使い回す。
        private static let sharedCIContext = CIContext()

        /// 「まだ通っていない場所」を宝探しの霧のようにぼんやりさせるための、
        /// ガウスぼかしをかけた画像を作る。古地図が変わる度に一度だけ計算してキャッシュする。
        private static func blurredImage(_ image: UIImage) -> UIImage? {
            guard let ciImage = CIImage(image: image) else { return nil }
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciImage
            filter.radius = 14
            guard let output = filter.outputImage?.cropped(to: ciImage.extent) else { return nil }
            guard let cgImage = sharedCIContext.createCGImage(output, from: output.extent) else { return nil }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            onTap(coordinate)
        }

        /// チェックポイントのマーカーをタップした時に出す情報ウィンドウを、
        /// そのチェックポイント名を示す小さな丸みのあるラベルとして描画する。
        /// これ自体をタップすると`didTapInfoWindowOf`が呼ばれ、詳細（物語）を開く。
        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            guard let site = marker.userData as? HistoricSite else { return nil }

            let label = UILabel()
            label.text = site.name
            label.font = .systemFont(ofSize: 13, weight: .bold)
            label.textColor = .systemBrown
            label.numberOfLines = 1
            label.sizeToFit()

            let horizontalPadding: CGFloat = 14
            let verticalPadding: CGFloat = 10
            let container = UIView(frame: CGRect(
                x: 0, y: 0,
                width: label.bounds.width + horizontalPadding * 2,
                height: label.bounds.height + verticalPadding * 2
            ))
            container.backgroundColor = .white
            container.layer.cornerRadius = container.bounds.height / 2
            container.layer.shadowColor = UIColor.black.cgColor
            container.layer.shadowOpacity = 0.2
            container.layer.shadowRadius = 4
            container.layer.shadowOffset = CGSize(width: 0, height: 2)

            label.frame = CGRect(x: horizontalPadding, y: verticalPadding, width: label.bounds.width, height: label.bounds.height)
            container.addSubview(label)

            return container
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
            if saved.count != savedPolylinePairs.count {
                savedPolylinePairs.forEach { $0.remove() }
                savedPolylinePairs = saved.map { coordinates in
                    let path = GMSMutablePath()
                    coordinates.forEach { path.add($0) }
                    return makeTrailPair(path: path, on: mapView)
                }
            }

            guard live.count >= 2 else {
                liveTrailPair?.remove()
                liveTrailPair = nil
                return
            }

            let path = GMSMutablePath()
            live.forEach { path.add($0) }
            if let liveTrailPair {
                liveTrailPair.setPath(path)
            } else {
                liveTrailPair = makeTrailPair(path: path, on: mapView)
            }
        }

        /// 縁取り（細い線）を先に描き、その上に一回り細い透かし塗りを重ねることで、
        /// 「縁ははっきり・中は控えめ」な1本の通った道を作る。
        private func makeTrailPair(path: GMSMutablePath, on mapView: GMSMapView) -> TrailPolylinePair {
            let border = GMSPolyline(path: path)
            border.strokeColor = .walkedTrailBorder
            border.strokeWidth = walkedTrailBorderWidth
            border.zIndex = 0
            border.map = mapView

            let fill = GMSPolyline(path: path)
            fill.strokeColor = .walkedTrailFill
            fill.strokeWidth = walkedTrailFillWidth
            fill.zIndex = 1
            fill.map = mapView

            return TrailPolylinePair(border: border, fill: fill)
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
                marker.icon = GMSMarker.markerImage(with: .shuiro)
                marker.opacity = isCollected ? 1.0 : 0.6
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
        private static func circularThumbnail(_ image: UIImage, diameter: CGFloat = 32) -> UIImage {
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
