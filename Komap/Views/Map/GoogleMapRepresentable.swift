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
    /// 現在地。自前で描く現在地マーク（`applyCurrentLocationMarker`）の位置に使う。
    var currentLocation: CLLocationCoordinate2D?
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
    /// `true`の間（歩いて記録中）は、今の軌跡が目立つよう過去の（保存済みの）
    /// 軌跡を薄く表示する。
    var isRecordingWalk: Bool = false
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
    /// ユーザーが指でマップをドラッグ・ピンチ操作した時に呼ばれる。
    /// 現在地追従中はこれをきっかけに追従をやめる（プログラムによるカメラ移動では呼ばれない）。
    var onUserPanned: () -> Void = {}

    func makeUIView(context: Context) -> GMSMapView {
        let initialCamera = GMSCameraPosition.camera(
            withLatitude: overlayMap?.center.latitude ?? 35.6812,
            longitude: overlayMap?.center.longitude ?? 139.767,
            zoom: 15
        )
        let mapView = GMSMapView()
        mapView.camera = initialCamera
        // Google純正の現在地の「青い点」は小さく、写真ピンなどの下に隠れて見づらいという
        // 声があったため無効化し、代わりに`applyCurrentLocationMarker`で自前の、
        // より大きく・常に最前面に出るマーカーを描く。
        mapView.isMyLocationEnabled = false
        // Google純正の現在地ボタンは大きいため非表示にし、代わりにもっと小さい
        // 自前のボタン（MapScreen側）を使う。
        mapView.settings.myLocationButton = false
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
        context.coordinator.onUserPanned = onUserPanned
        if showAllOverlays {
            context.coordinator.applyAllOverlays(OldMapCatalog.allIncludingCustom, checkpoints: checkpoints, to: mapView)
        } else {
            context.coordinator.removeAllOverlays()
            context.coordinator.applyOverlay(overlayMap, opacity: overlayOpacity, livePath: liveWalkPath, checkpoints: checkpoints, to: mapView)
        }
        context.coordinator.applyWalkPaths(saved: savedWalkPaths, live: liveWalkPath, isRecording: isRecordingWalk, to: mapView)
        context.coordinator.applyCheckpoints(checkpoints, collectedSiteIDs: collectedSiteIDs, to: mapView)
        context.coordinator.applyPhotoPosts(photoPosts, isRecordingWalk: isRecordingWalk, to: mapView)
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)

        if let request = moveCameraRequest, context.coordinator.lastHandledMoveRequestID != request.id {
            context.coordinator.lastHandledMoveRequestID = request.id
            mapView.animate(to: GMSCameraPosition.camera(withTarget: request.coordinate, zoom: request.zoom ?? mapView.camera.zoom))
        }

        context.coordinator.applyCurrentLocationMarker(currentLocation, emphasized: isRecordingWalk, to: mapView)
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(onTap: onTap)
        // このView自体が生成される前から存在していたカメラ移動リクエストは、
        // 「既に処理済み」として扱う。そうしないと、マップタブを離れて戻ってきた時に
        // （Viewが作り直されてCoordinatorも真新しくなるため）、以前の現在地追従などで
        // 残っていた古いリクエストがここで初めて処理され、チェックポイントに合わせた
        // 初期カメラフィットを直後に上書きしてしまう。
        coordinator.lastHandledMoveRequestID = moveCameraRequest?.id
        return coordinator
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onTap: (CLLocationCoordinate2D) -> Void
        var onCheckpointTap: (HistoricSite) -> Void = { _ in }
        var onPhotoPostTap: (WalkPhotoPost) -> Void = { _ in }
        var onUserPanned: () -> Void = {}
        var lastHandledMoveRequestID: UUID?

        private var currentOverlay: GMSGroundOverlay?
        private var currentOverlayID: String?
        /// 「全ての古地図を表示」中に、同梱・登録済みの古地図それぞれに対応するグラウンドオーバーレイ。
        private var allOverlays: [GMSGroundOverlay] = []
        /// `allOverlays`の各要素がどの古地図（画像・範囲のキー）に対応するかを保持する。
        /// `applyAllOverlays`が同じ内容で再度呼ばれた時に無駄な作り直しをスキップしつつ、
        /// 一覧の中身が実際に変わった時（古地図が追加された等）は正しく再構築するために使う
        /// （件数だけの比較だと、件数がたまたま同じ時に変更が反映されないことがあった）。
        private var allOverlayKeys: [String] = []
        /// `applyAllOverlays`が呼ばれるたびに増やす世代番号。画像デコードが終わる前に
        /// 表示が切り替わった場合、古い世代の結果を`allOverlays`へ書き込まないようにする。
        private var allOverlaysGeneration = 0
        private var currentBaseImage: UIImage?
        /// まだ通っていない場所用に、あらかじめぼかしておいた画像（古地図が変わる度に作り直す）。
        private var currentBlurredImage: UIImage?
        private var lastRevealedPointCount = 0
        /// リビール画像の合成中に、GPSの更新が続けて何度も来た場合に合成タスクが
        /// 積み重ならないようにするためのフラグ。
        private var isComposingRevealedImage = false
        /// 直近に合成し終えたリビール画像。次の合成では、この画像を土台にして
        /// 新しく増えた区間だけ追加で「くっきり」描き足す（歩行が長くなるほど
        /// 軌跡全体を毎回描き直すコストが増え続けるのを防ぐため）。
        private var lastRevealedComposedImage: UIImage?
        /// `idleAt`でのオーバーレイ・マーカー貼り直しワークアラウンドを、最後に
        /// 実行した時のズーム値。通常のパン・小さなズーム操作のたびに毎回貼り直すと、
        /// 古地図のテクスチャ再アップロードとチェックポイントの前面出し直しが
        /// 無駄に発生し続けるため、テクスチャ喪失の原因である「大きなズーム変化」が
        /// 実際にあった時だけ行うようにする。
        private var lastOverlayRefreshZoom: Float?
        private let overlayRefreshZoomThreshold: Float = 0.75

        private var savedPolylinePairs: [TrailPolylinePair] = []
        private var liveTrailPair: TrailPolylinePair?
        /// 直近にスムージング・描画済みのライブ軌跡の座標数。GPSの新しい更新が
        /// 無いのに`applyWalkPaths`が呼ばれた場合に、同じ軌跡を無駄に再計算しないための目印。
        private var liveRawPathCount = 0
        /// `liveTrailPair`に設定済みのスムージング後パス本体。新しいGPS点が増えた時、
        /// 全体を再スムージングする代わりに、末尾に増えた分だけ差分で追記するために保持する。
        private var liveTrailMutablePath: GMSMutablePath?
        private var checkpointMarkers: [String: GMSMarker] = [:]
        /// 直近で`applyCheckpoints`に適用した獲得済み状態。GPS更新のたびに呼ばれても、
        /// 変化のないマーカーの`icon`/`opacity`を再設定しない（負荷軽減）ために使う。
        private var checkpointCollectedState: [String: Bool] = [:]
        private var photoPostMarkers: [UUID: GMSMarker] = [:]
        /// チェックポイントの通常アイコン。マーカーごとに毎回生成し直さないよう使い回す。
        private static let checkpointIcon = GMSMarker.markerImage(with: .shuiro)

        /// 古地図のグラウンドオーバーレイ・チェックポイントのマーカー・投稿写真のピンの
        /// 重なり順を、`zIndex`を明示することで常に固定する（安全側の対策。詳細は
        /// `bringCheckpointMarkersToFront`のコメント参照）。
        private static let groundOverlayZIndex: Int32 = 0
        private static let checkpointMarkerZIndex: Int32 = 10
        /// 「全ての古地図を表示」で実画像を貼るオーバーレイの上限。これを超える枚数を
        /// 同時に読み込むと、Google Maps SDKのテクスチャアトラス上限に達し、
        /// チェックポイントの赤いマーカー用テクスチャが一切確保できなくなり、
        /// マーカーが軒並み表示されなくなる（`bringCheckpointMarkersToFront`のコメント
        /// 参照）。上限を超えた分は画像なし（枠だけ）のオーバーレイのままにし、
        /// チェックポイントのマーカー自体は全古地図分きちんと表示されるようにする。
        /// 実機・シミュレータでの検証では8枚でもマーカーが表示されないままだったため、
        /// 十分な余裕を持たせて4枚にしている（同梱の古地図が今後増えても、この値を
        /// 上げる場合は必ずシミュレータで「全ての古地図を表示」を開いてマーカーが
        /// 全古地図分ちゃんと出ることを確認すること）。
        private static let maxSimultaneousAllOverlayImages = 4
        private static let photoPostMarkerZIndex: Int32 = 20
        /// 現在地マークは、写真ピンなど他のどのマーカーより必ず前面に出す。
        private static let currentLocationMarkerZIndex: Int32 = 30

        private var currentLocationMarker: GMSMarker?
        /// 直近に描いた現在地マークが「強調表示」だったかどうか。歩行記録中は
        /// 大きく目立つ見た目にするため、この状態が変わった時だけアイコンを作り直す。
        private var isCurrentLocationMarkerEmphasized = false
        /// 直近に投稿写真ピンへ適用した「記録中で薄く表示」状態。
        private var arePhotoPostsDimmed = false

        /// 歩いた場所を中心に、この幅（メートル）だけ古地図を宝探しのようにはっきり見せる。
        private let revealCorridorMeters: Double = 70
        /// 記録中、「まだ通っていない場所」の不透明度の下限。スライダーがこれより低くても、
        /// 宝探し演出（通った道だけくっきり）を保ったまま、歩いている間は古地図全体が
        /// はっきり見えるようにする（以前は0.6で、ぼかしと合わさって古地図全体が
        /// 薄く霞んで見えづらいという声があったため引き上げた）。
        private static let minimumUnrevealedAlpha: CGFloat = 0.88
        /// 歩いた道の縁取りの太さ（画面上のポイント数）。中の透かし塗りよりわずかに太いだけの、
        /// 細く濃い縁として見せる。
        private let walkedTrailBorderWidth: CGFloat = 14.4 // 18の20%減
        /// 歩いた道の中を薄く塗る太さ。縁取りより一回り細くすることで、縁だけが濃い線として残り、
        /// 中央は明るい色が重なって薄く見える。
        private let walkedTrailFillWidth: CGFloat = 12

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
        func applyAllOverlays(_ overlays: [HistoricalOverlayMap], checkpoints: [HistoricSite] = [], to mapView: GMSMapView) {
            currentOverlay?.map = nil
            currentOverlay = nil
            currentOverlayID = nil

            // 「五色不動めぐり」「松尾芭蕉ゆかりの地」など、同じ広域画像・同じ範囲を
            // 使い回しているだけの古地図が複数あると、見た目は完全に重なって
            // 変わらないのに同じテクスチャを何度も読み込むことになり、Google Maps SDKの
            // テクスチャアトラス上限（"Reached the max number of texture atlases"）に
            // 達して古地図が一切描画されなくなることがある。画像・範囲が同じものは
            // 1枚にまとめてから重ねる。
            func key(for overlayMap: HistoricalOverlayMap) -> String {
                "\(overlayMap.imageAssetName ?? overlayMap.imageFileName ?? "")|\(overlayMap.southWest.latitude)|\(overlayMap.southWest.longitude)|\(overlayMap.northEast.latitude)|\(overlayMap.northEast.longitude)|\(overlayMap.bearing)"
            }
            var seenKeys = Set<String>()
            let uniqueMaps = overlays.filter { seenKeys.insert(key(for: $0)).inserted }
            let newKeys = uniqueMaps.map(key(for:))

            guard allOverlayKeys != newKeys else { return }
            allOverlayKeys = newKeys
            allOverlays.forEach { $0.map = nil }
            allOverlaysGeneration += 1

            // 画像の読み込み・デコードは重いので、まず枠だけ（画像なし）のオーバーレイを
            // メインスレッドで即座に置いてから、それぞれの画像をバックグラウンドで
            // デコードする。まとめて同期デコードするとメインスレッドが固まって
            // 表示がもたつくため。
            // 既存のオーバーレイに後から`.icon`だけ差し替えると描画に反映されない
            // ことがあるため、画像が用意できたらオーバーレイ自体を作り直す。
            allOverlays = uniqueMaps.map { overlayMap in
                let bounds = GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
                let overlay = GMSGroundOverlay(bounds: bounds, icon: nil)
                overlay.bearing = overlayMap.bearing
                overlay.opacity = 0.75
                overlay.zIndex = Self.groundOverlayZIndex
                overlay.map = mapView
                return overlay
            }
            bringCheckpointMarkersToFront(on: mapView)

            let generation = allOverlaysGeneration
            for (index, overlayMap) in uniqueMaps.enumerated() {
                // 上限を超えた分は画像を読み込まない（枠だけのオーバーレイのまま）。
                // チェックポイントのマーカーは`checkpoints`に含まれる全古地図分そのまま描画される。
                guard index < Self.maxSimultaneousAllOverlayImages else { continue }
                let bounds = GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
                let bearing = overlayMap.bearing
                let cacheKey = newKeys[index]
                if let cached = Self.downsampledImageCache[cacheKey] {
                    allOverlays[index].map = nil
                    let replacement = GMSGroundOverlay(bounds: bounds, icon: cached)
                    replacement.bearing = bearing
                    replacement.opacity = 0.75
                    replacement.zIndex = Self.groundOverlayZIndex
                    replacement.map = mapView
                    allOverlays[index] = replacement
                    bringCheckpointMarkersToFront(on: mapView)
                    continue
                }
                // `UIImage(named:)`（`overlayMap.image`）はメインスレッドで読み込み、
                // 重いリサイズ処理だけバックグラウンドで行う。
                let sourceImage = overlayMap.image
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let image = Self.downsampledForAllOverlays(sourceImage)
                    if let image {
                        Self.downsampledImageCache[cacheKey] = image
                    }
                    DispatchQueue.main.async {
                        guard let self,
                              self.allOverlaysGeneration == generation,
                              self.allOverlays.indices.contains(index)
                        else { return }
                        self.allOverlays[index].map = nil
                        let replacement = GMSGroundOverlay(bounds: bounds, icon: image)
                        replacement.bearing = bearing
                        replacement.opacity = 0.75
                        replacement.zIndex = Self.groundOverlayZIndex
                        replacement.map = mapView
                        self.allOverlays[index] = replacement
                        self.bringCheckpointMarkersToFront(on: mapView)
                    }
                }
            }

            var combinedBounds: GMSCoordinateBounds?
            for overlayMap in overlays {
                combinedBounds = combinedBounds?.includingCoordinate(overlayMap.southWest).includingCoordinate(overlayMap.northEast)
                    ?? GMSCoordinateBounds(coordinate: overlayMap.southWest, coordinate: overlayMap.northEast)
            }
            // 古地図の位置合わせは仮座標のため、古地図の範囲だけでカメラを合わせると
            // チェックポイントが画面外に出てしまうことがある。単一の古地図表示時と同様、
            // チェックポイントの座標も収まるようにする。
            for checkpoint in checkpoints {
                combinedBounds = combinedBounds?.includingCoordinate(checkpoint.coordinate)
                    ?? GMSCoordinateBounds(coordinate: checkpoint.coordinate, coordinate: checkpoint.coordinate)
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
            allOverlayKeys = []
            allOverlaysGeneration += 1
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
                // 古いオーバーレイのテクスチャをすぐに手放せるよう、`.map = nil`の前に
                // `.icon`も明示的に外しておく（`.map = nil`だけでは、Google Maps SDK内部の
                // テクスチャアトラスがすぐには解放されないことがある）。
                currentOverlay?.icon = nil
                currentOverlay?.map = nil
                currentBlurredImage = nil
                lastRevealedPointCount = 0

                let bounds = GMSCoordinateBounds(
                    coordinate: overlayMap.southWest,
                    coordinate: overlayMap.northEast
                )
                let overlayID = overlayMap.id

                // フル解像度（3000px超のことがある）の画像をそのまま縮小すると、
                // デコード＋再描画の負荷でメインスレッドが一瞬止まり、「地図タブを開いた
                // 瞬間に表示がもたつく」原因になっていた。縮小結果はオーバーレイIDごとに
                // キャッシュし、初回だけバックグラウンドで計算する（2回目以降は
                // キャッシュ済みの画像を使うため即座に表示できる）。
                if let cached = Self.singleOverlayImageCache[overlayID] {
                    currentBaseImage = cached
                    let overlay = GMSGroundOverlay(bounds: bounds, icon: cached)
                    overlay.bearing = overlayMap.bearing
                    overlay.opacity = 1
                    overlay.zIndex = Self.groundOverlayZIndex
                    overlay.map = mapView
                    currentOverlay = overlay
                } else {
                    currentBaseImage = nil
                    // 縮小画像ができるまでは、枠だけ（画像なし）のオーバーレイを
                    // 即座に表示しておく（メインスレッドを待たせないため）。
                    let overlay = GMSGroundOverlay(bounds: bounds, icon: nil)
                    overlay.bearing = overlayMap.bearing
                    overlay.opacity = 1
                    overlay.zIndex = Self.groundOverlayZIndex
                    overlay.map = mapView
                    currentOverlay = overlay

                    let sourceImage = overlayMap.image
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        let downsampled = Self.downsampledForSingleOverlay(sourceImage)
                        if let downsampled {
                            Self.singleOverlayImageCache[overlayID] = downsampled
                        }
                        DispatchQueue.main.async {
                            guard let self, self.currentOverlayID == overlayID else { return }
                            self.currentBaseImage = downsampled
                            self.currentOverlay?.icon = downsampled
                            // 記録中（宝探し演出）でなければ、この時点でスライダーの
                            // 不透明度を反映しておく（次の`updateUIView`を待たず、
                            // 画像が現れた瞬間から正しい濃さで見えるようにする）。
                            if livePath.count < 2 {
                                self.currentOverlay?.opacity = opacity
                            }
                            if let downsampled {
                                self.startBlurGeneration(for: downsampled, overlayID: overlayID)
                            }
                        }
                    }
                }
                currentOverlayID = overlayMap.id

                // 古地図全体（かなり広いことがある）に合わせるのではなく、その古地図の
                // チェックポイントが収まる範囲にカメラを合わせる（その方が見やすくズームできる）。
                // チェックポイントが1つも無い古地図では、代わりに古地図全体を表示する。
                let ownCheckpoints = checkpoints.filter { $0.overlayMapID == overlayMap.id }
                var fitBounds: GMSCoordinateBounds
                if let first = ownCheckpoints.first {
                    fitBounds = GMSCoordinateBounds(coordinate: first.coordinate, coordinate: first.coordinate)
                    for checkpoint in ownCheckpoints.dropFirst() {
                        fitBounds = fitBounds.includingCoordinate(checkpoint.coordinate)
                    }
                } else {
                    fitBounds = bounds
                }
                mapView.moveCamera(GMSCameraUpdate.fit(fitBounds, withPadding: 24))
                // 「五色不動めぐり」「松尾芭蕉ゆかりの地」「霞ヶ関・虎ノ門」「赤坂・紀尾井町」など、
                // 広域の同じ画像を使い回している古地図は、チェックポイントが画像全体に対して
                // ごく一部・細長い範囲に集中していることがあり、そこへぴったりフィットすると
                // ズームしすぎてGoogle Maps SDKがグラウンドオーバーレイを描画できなくなることがある。
                // そのため、フィット後のズームが行き過ぎていたら上限まで戻す。
                if mapView.camera.zoom > Self.maxCheckpointFitZoom {
                    let center = CLLocationCoordinate2D(
                        latitude: (fitBounds.northEast.latitude + fitBounds.southWest.latitude) / 2,
                        longitude: (fitBounds.northEast.longitude + fitBounds.southWest.longitude) / 2
                    )
                    mapView.moveCamera(
                        GMSCameraUpdate.setCamera(
                            GMSCameraPosition(target: center, zoom: Self.maxCheckpointFitZoom)
                        )
                    )
                }

                // ぼかし画像の生成は重いので、メインスレッドをブロックしないよう
                // バックグラウンドで計算してから後で使う（先に元画像で表示しておく）。
                // 縮小画像がまだキャッシュされていない場合はここではまだ`currentBaseImage`が
                // `nil`のため、縮小完了時のコールバック側（上）で改めて呼び出す。
                if let baseImage = currentBaseImage {
                    startBlurGeneration(for: baseImage, overlayID: overlayID)
                }
            }

            guard let currentOverlay, let baseImage = currentBaseImage else { return }

            if livePath.count >= 2 {
                // 記録中はスライダーの不透明度を「まだ通っていない場所」の薄さとして使い、
                // 通った場所だけくっきり見えるように画像を合成し直す。この不透明度は
                // 合成画像のピクセルに直接焼き込むため、オーバーレイ自体の`opacity`は
                // 常に1にしておく（記録開始前にスライダーで下げていた値が残っていると、
                // 二重に暗くなり古地図がほとんど見えなくなってしまうため）。
                currentOverlay.opacity = 1
                // 合成処理は重いのでメインスレッドをブロックしないようバックグラウンドで行う。
                if !isComposingRevealedImage && (isNewOverlay || livePath.count != lastRevealedPointCount) {
                    let previousPointCount = isNewOverlay ? 0 : lastRevealedPointCount
                    lastRevealedPointCount = livePath.count
                    isComposingRevealedImage = true
                    let southWest = overlayMap.southWest
                    let northEast = overlayMap.northEast
                    let corridorMeters = revealCorridorMeters
                    // スライダーの不透明度が低いままだと「まだ通っていない場所」がほぼ見えなくなり、
                    // 歩いている間ずっと古地図が表示されていないように感じてしまうため、
                    // 宝探し演出（通った道だけくっきり）は保ちつつ、下限の見えやすさを確保する。
                    let faintAlpha = max(CGFloat(opacity), Self.minimumUnrevealedAlpha)
                    let blurredBase = currentBlurredImage ?? baseImage
                    let overlayRef = currentOverlay
                    // 前回合成済みの画像があり、かつ新しく増えた区間だけなら、そこを土台にして
                    // 増えた末尾区間だけ追加でくっきり描き足す（軌跡全体を毎回描き直すコストが
                    // 歩行時間に比例して増え続けるのを防ぐ）。古地図を切り替えた直後や、
                    // まだ土台が無い時は、これまで通り軌跡全体から作り直す。
                    let previousComposed = (previousPointCount > 0 && previousPointCount <= livePath.count)
                        ? lastRevealedComposedImage
                        : nil
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        let image: UIImage?
                        if let previousComposed, previousPointCount >= 1 {
                            let newSegment = Array(livePath[(previousPointCount - 1)...])
                            image = Self.incrementalRevealedImage(
                                previousComposed: previousComposed,
                                base: baseImage,
                                southWest: southWest,
                                northEast: northEast,
                                newSegment: newSegment,
                                corridorMeters: corridorMeters
                            )
                        } else {
                            image = Self.revealedImage(
                                base: baseImage,
                                blurredBase: blurredBase,
                                southWest: southWest,
                                northEast: northEast,
                                path: livePath,
                                corridorMeters: corridorMeters,
                                faintAlpha: faintAlpha
                            )
                        }
                        DispatchQueue.main.async {
                            overlayRef.icon = image
                            self?.lastRevealedComposedImage = image
                            self?.isComposingRevealedImage = false
                        }
                    }
                }
            } else {
                // 記録していない時は、これまで通りスライダーの不透明度を全体にかける。
                if lastRevealedPointCount != 0 {
                    currentOverlay.icon = baseImage
                    lastRevealedPointCount = 0
                    lastRevealedComposedImage = nil
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

        /// `revealedImage`が作った合成済み画像を土台に、新しく増えた軌跡区間
        /// （`newSegment`。前回の終端点＋新しい点、を含む）だけ追加でくっきり描き足す。
        /// まだ通っていない場所は`previousComposed`側で既にぼかし済みのため、ここでは
        /// 新区間のコリドーだけ重ねて描けばよく、軌跡全体を毎回描き直す必要がない
        /// （歩行が長くなっても1回あたりの合成コストが増えないようにするため）。
        private static func incrementalRevealedImage(
            previousComposed: UIImage,
            base: UIImage,
            southWest: CLLocationCoordinate2D,
            northEast: CLLocationCoordinate2D,
            newSegment: [CLLocationCoordinate2D],
            corridorMeters: Double
        ) -> UIImage? {
            guard let cgImage = base.cgImage else { return previousComposed }
            let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
            guard pixelSize.width > 0, pixelSize.height > 0, newSegment.count >= 2 else { return previousComposed }

            let latSpan = northEast.latitude - southWest.latitude
            let lngSpan = northEast.longitude - southWest.longitude
            guard latSpan > 0, lngSpan > 0 else { return previousComposed }

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
            return renderer.image { context in
                let cg = context.cgContext
                let fullRect = CGRect(origin: .zero, size: pixelSize)

                // 土台はすでに合成済みの画像をそのまま描くだけ（ここが全体再合成を避ける肝）。
                previousComposed.draw(in: fullRect, blendMode: .normal, alpha: 1)

                // 新しく増えた区間だけ、太い帯でくっきり鮮明に上書きする。
                cg.saveGState()
                cg.setLineWidth(corridorWidthPixels)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                let corridorPath = CGMutablePath()
                let points = newSegment.map(point(for:))
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
            // 以前は14で、まだ通っていない場所の古地図がぼやけすぎて何の絵か
            // 分かりにくいという声があったため、輪郭が判別できる程度まで弱めた。
            filter.radius = 5
            guard let output = filter.outputImage?.cropped(to: ciImage.extent) else { return nil }
            guard let cgImage = sharedCIContext.createCGImage(output, from: output.extent) else { return nil }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }

        /// 単体表示（`applyOverlay`）でダウンサンプルした結果を、古地図IDごとに使い回す
        /// キャッシュ。同梱画像はアプリ起動中に内容が変わらないため、同じ古地図を
        /// 選び直しても2回目以降は重いデコード・縮小処理をスキップし、即座に表示できる。
        private static var singleOverlayImageCache: [String: UIImage] = [:]

        /// ぼかし画像の生成をバックグラウンドで行い、完了時に（今も同じ古地図を
        /// 選択中であれば）`currentBlurredImage`へ反映する。
        private func startBlurGeneration(for baseImage: UIImage, overlayID: String) {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let blurred = Self.blurredImage(baseImage)
                DispatchQueue.main.async {
                    guard self?.currentOverlayID == overlayID else { return }
                    self?.currentBlurredImage = blurred
                }
            }
        }

        /// 同梱の古地図画像は、この環境のGoogle Maps SDKが確実に描画できることを
        /// 確認済みの1024×1024で統一している（`HistoricalOverlayMap.imageAssetName`の
        /// ドキュメント参照）。1024×1024以外のサイズだと`GMSGroundOverlay`が画像を
        /// 一切描画しない不具合があるため、「全ての古地図を表示」専用の縮小サイズも
        /// 1024のまま（＝実質縮小しない）にしておく必要がある
        /// （「全ての古地図を表示」でチェックポイントのマーカーが表示されない別の問題に
        /// ついては`bringCheckpointMarkersToFront`のコメントを参照。512に縮小して
        /// テクスチャ使用量を減らす対策も試したが、別の描画不具合が出たため見送った）。
        private static let allOverlaysMaxDimension: CGFloat = 1024

        /// `downsampledForAllOverlays`の結果をキー（画像名+範囲）ごとに使い回すキャッシュ。
        /// 同梱画像はアプリ起動中に内容が変わらないため、「全ての古地図を表示」を
        /// 何度も開き直しても、2回目以降は重いデコード・縮小処理をスキップできる。
        private static var downsampledImageCache: [String: UIImage] = [:]

        /// 古地図選択時にチェックポイントへカメラフィットする際の、これ以上は
        /// ズームしない上限。広域画像を使い回している古地図でチェックポイントが
        /// 画像のごく一部に集中していると、フィットだけに任せると極端にズーム
        /// しすぎてグラウンドオーバーレイが描画されなくなることがあるため。
        private static let maxCheckpointFitZoom: Float = 17

        private static func downsampledForAllOverlays(_ image: UIImage?) -> UIImage? {
            downsampled(image, maxDimension: allOverlaysMaxDimension)
        }

        /// 単体表示時（ズームインして見ることが多い）は、全件表示時ほど強くは縮小せず、
        /// 画質と、Google Maps SDKのテクスチャアトラス上限を超えないことのバランスを取る。
        private static let singleOverlayMaxDimension: CGFloat = 1600

        private static func downsampledForSingleOverlay(_ image: UIImage?) -> UIImage? {
            downsampled(image, maxDimension: singleOverlayMaxDimension)
        }

        private static func downsampled(_ image: UIImage?, maxDimension: CGFloat) -> UIImage? {
            guard let image else { return nil }
            let longestSide = max(image.size.width, image.size.height)
            guard longestSide > maxDimension else { return image }

            let scale = maxDimension / longestSide
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            // `UIGraphicsImageRenderer`はデフォルトだと端末の画面スケール（Retinaで2〜3倍）で
            // レンダリングするため、`format.scale`を指定しないと「ポイントサイズは縮小したのに
            // 実ピクセル数はむしろ増える」ことがある（例: 3倍機で1024pt→512ptに縮小したつもりが
            // 実際は1536pxになる）。ここでは実ピクセル数そのものを`maxDimension`に収めたいため、
            // scale基準ではなく実ピクセル基準で明示的に1.0を指定する。
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            onTap(coordinate)
        }

        /// カメラが動き始めた時に呼ばれる。`gesture`が`true`の時だけ、指でのドラッグ・ピンチ操作
        /// （＝現在地追従を続けたくない操作）だと判断する。`mapView.animate(to:)`による
        /// プログラムからの移動では`false`になるため、現在地追従はここでは止まらない。
        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture {
                onUserPanned()
            }
        }

        /// カメラの移動（ズーム・パン）が収まった時に呼ばれる。
        ///
        /// - Important: 稀に、大きくズーム・パンした直後に`GMSGroundOverlay`の
        ///   テクスチャがGPU側で失われたまま再描画されず、古地図が消えて見える
        ///   ことがある（`.map`への再代入がSDK内部で「最後に追加した」扱いとなり
        ///   描画を強制し直すきっかけになるのは、チェックポイントのマーカーで
        ///   `bringCheckpointMarkersToFront`が行っているのと同じ対策）。
        ///   カメラが落ち着いたタイミングで、既存のオーバーレイを画像の再デコードなど
        ///   重い処理をせずに一旦外して貼り直すことで、この消失を防ぐ。
        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            if let lastOverlayRefreshZoom,
               abs(position.zoom - lastOverlayRefreshZoom) < overlayRefreshZoomThreshold {
                return
            }
            lastOverlayRefreshZoom = position.zoom

            if let currentOverlay {
                currentOverlay.map = nil
                currentOverlay.map = mapView
            }
            for overlay in allOverlays {
                overlay.map = nil
                overlay.map = mapView
            }
            if !checkpointMarkers.isEmpty || !allOverlays.isEmpty {
                bringCheckpointMarkersToFront(on: mapView)
            }
            if let currentLocationMarker {
                currentLocationMarker.map = nil
                currentLocationMarker.map = mapView
            }
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

        /// 直近に`savedPolylinePairs`へ適用した「薄く表示」状態。歩き始め・終わりの
        /// たびに毎回色を設定し直さずに済むよう、変化した時だけ更新する。
        private var isSavedTrailDimmed = false

        /// 保存済みの徒歩ルートと、記録中のルートをそれぞれポリラインで塗り分ける。
        /// 記録中（`isRecording`）は、今の軌跡が目立つよう保存済みルートを薄く表示する。
        func applyWalkPaths(
            saved: [[CLLocationCoordinate2D]],
            live: [CLLocationCoordinate2D],
            isRecording: Bool,
            to mapView: GMSMapView
        ) {
            // 保存済みルートは件数が変わった時だけ作り直す（記録終了で1件増える程度の頻度）。
            if saved.count != savedPolylinePairs.count {
                savedPolylinePairs.forEach { $0.remove() }
                savedPolylinePairs = saved.map { coordinates in
                    let path = GMSMutablePath()
                    Self.smoothedTrailCoordinates(coordinates).forEach { path.add($0) }
                    return makeTrailPair(path: path, style: isRecording ? .faded : .saved, on: mapView)
                }
                isSavedTrailDimmed = isRecording
            } else if isRecording != isSavedTrailDimmed {
                isSavedTrailDimmed = isRecording
                for pair in savedPolylinePairs {
                    pair.border.strokeColor = isRecording ? .walkedTrailBorderFaded : .walkedTrailBorder
                    pair.fill.strokeColor = isRecording ? .walkedTrailFillFaded : .walkedTrailFill
                }
            }

            guard live.count >= 2 else {
                liveTrailPair?.remove()
                liveTrailPair = nil
                liveRawPathCount = 0
                liveTrailMutablePath = nil
                return
            }

            // `updateUIView`は、記録中に無関係なUI状態（トースト表示・シート開閉・
            // Watch側の状態変化など）が変わるたびにも呼ばれる。GPSの新しい座標が
            // 1件も増えていない場合にまで、蓄積した軌跡全体をスムージングし直して
            // ポリラインを作り直すのは無駄な負荷（記録が長くなるほど1回あたりの
            // 計算量が増え続ける）になるため、座標数が変化した時だけ再計算する。
            guard live.count != liveRawPathCount else { return }
            let previousCount = liveRawPathCount
            liveRawPathCount = live.count

            // 前回スムージング済みの生座標数が3未満（＝`smoothedTrailCoordinates`が
            // まだ入力をそのまま返している段階）か、まだパスが無い時、あるいは座標が
            // 減った（記録リセットなど）時だけ、全体を作り直す。それ以外は末尾に
            // 増えた区間だけ差分でスムージングして追記する（歩行が長くなっても
            // 1回あたりの計算量が増えないようにするため）。
            if previousCount < 3 || liveTrailMutablePath == nil || live.count < previousCount {
                let path = GMSMutablePath()
                Self.smoothedTrailCoordinates(live).forEach { path.add($0) }
                liveTrailMutablePath = path
                if let liveTrailPair {
                    liveTrailPair.setPath(path)
                } else {
                    liveTrailPair = makeTrailPair(path: path, style: .live, on: mapView)
                }
                return
            }

            let path = liveTrailMutablePath!
            // 直前まで終端としてそのまま置いていた最後の生座標（`live[previousCount - 1]`）を
            // 一旦外し、そこから新しく増えた区間ぶんのスムージング済み中間点を追加してから、
            // 新しい終端を改めて置き直す。
            path.removeLastCoordinate()
            for index in (previousCount - 1)..<(live.count - 1) {
                let p0 = live[index]
                let p1 = live[index + 1]
                path.add(CLLocationCoordinate2D(
                    latitude: p0.latitude * 0.75 + p1.latitude * 0.25,
                    longitude: p0.longitude * 0.75 + p1.longitude * 0.25
                ))
                path.add(CLLocationCoordinate2D(
                    latitude: p0.latitude * 0.25 + p1.latitude * 0.75,
                    longitude: p0.longitude * 0.25 + p1.longitude * 0.75
                ))
            }
            path.add(live[live.count - 1])
            liveTrailPair?.setPath(path)
        }

        /// GPSのノイズでできる細かいジグザグを和らげ、通った道の角を少し丸く滑らかに
        /// 見せる（Chaikinのコーナーカット法を1回だけ適用）。始点・終点はそのまま残すため、
        /// 現在地マーカーや保存済みルートの位置とはズレない。
        private static func smoothedTrailCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
            guard coordinates.count >= 3 else { return coordinates }
            var result: [CLLocationCoordinate2D] = [coordinates[0]]
            for index in 0..<(coordinates.count - 1) {
                let p0 = coordinates[index]
                let p1 = coordinates[index + 1]
                result.append(CLLocationCoordinate2D(
                    latitude: p0.latitude * 0.75 + p1.latitude * 0.25,
                    longitude: p0.longitude * 0.75 + p1.longitude * 0.25
                ))
                result.append(CLLocationCoordinate2D(
                    latitude: p0.latitude * 0.25 + p1.latitude * 0.75,
                    longitude: p0.longitude * 0.25 + p1.longitude * 0.75
                ))
            }
            result.append(coordinates[coordinates.count - 1])
            return result
        }

        /// 通った道の塗り方。`live`（今まさに記録中の軌跡）は保存済みルートよりも
        /// ひときわ濃く・太くして、「歩き進めている」実感を最大限出す。
        private enum TrailStyle {
            case saved
            case faded
            case live
        }

        /// 縁取り（細い線）を先に描き、その上に一回り細い透かし塗りを重ねることで、
        /// 「縁ははっきり・中は控えめ」な1本の通った道を作る。
        private func makeTrailPair(path: GMSMutablePath, style: TrailStyle, on mapView: GMSMapView) -> TrailPolylinePair {
            let borderColor: UIColor
            let fillColor: UIColor
            let widthScale: CGFloat
            switch style {
            case .saved:
                borderColor = .walkedTrailBorder
                fillColor = .walkedTrailFill
                widthScale = 1
            case .faded:
                borderColor = .walkedTrailBorderFaded
                fillColor = .walkedTrailFillFaded
                widthScale = 1
            case .live:
                borderColor = .liveWalkedTrailBorder
                fillColor = .liveWalkedTrailFill
                // 保存済みルートより一回り太くして、今の軌跡が古地図の上でも
                // ひときわくっきり・力強く見えるようにする。
                widthScale = 1.35
            }

            let border = GMSPolyline(path: path)
            border.strokeColor = borderColor
            border.strokeWidth = walkedTrailBorderWidth * widthScale
            border.zIndex = 0
            border.map = mapView

            let fill = GMSPolyline(path: path)
            fill.strokeColor = fillColor
            fill.strokeWidth = walkedTrailFillWidth * widthScale
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
                checkpointCollectedState.removeValue(forKey: siteID)
            }

            var addedNewMarkers = false
            for site in checkpoints where checkpointMarkers[site.id] == nil {
                let marker = GMSMarker(position: site.coordinate)
                marker.title = site.name
                marker.userData = site
                marker.icon = Self.checkpointIcon
                marker.zIndex = Self.checkpointMarkerZIndex
                marker.map = mapView
                checkpointMarkers[site.id] = marker
                addedNewMarkers = true
            }
            // `applyCheckpoints`はGPS更新や他のUI状態変化のたびに呼ばれるため、ここで
            // 毎回`bringCheckpointMarkersToFront`（`.map`の再代入）を行うと、ちょうど
            // タップして開いた直後の情報ウィンドウ（チェックポイント名の吹き出し）まで
            // 選択解除されて一瞬で消えてしまう。マーカーの顔ぶれが実際に変わった時
            // （追加・削除があった時）だけ前面へ出し直す。
            if !staleIDs.isEmpty || addedNewMarkers {
                bringCheckpointMarkersToFront(on: mapView)
            }

            // GPS更新のたびに全マーカーへ`icon`/`opacity`を設定し直すと、チェックポイントが
            // 多い「全ての古地図を表示」時に特に重くなるため、獲得状態が変わったマーカーだけ更新する。
            for (siteID, marker) in checkpointMarkers {
                let isCollected = collectedSiteIDs.contains(siteID)
                guard checkpointCollectedState[siteID] != isCollected else { continue }
                checkpointCollectedState[siteID] = isCollected
                marker.opacity = isCollected ? 1.0 : 0.6
            }
        }

        /// チェックポイントのマーカーを、既に地図上にある古地図オーバーレイより前面に
        /// 出るよう、都度セットし直す（`.map`への再代入は「後から追加した方が上」という
        /// 描画順の目安になるため）。
        ///
        /// - Important: 調査の結果、この環境のGoogle Maps SDKには「同時に読み込む
        ///   `GMSGroundOverlay`（1024×1024）の数が10枚を超えるあたりから、内部の
        ///   テクスチャアトラス上限（"Reached the max number of texture atlases,
        ///   can not allocate more."）に達し、それ以降はマーカー用のテクスチャを
        ///   一切確保できなくなる」という制約があることを確認した。この状態では
        ///   `marker.icon`をカスタム画像から外してSDK標準のピンにしても改善せず、
        ///   `zIndex`を明示しても改善しないため、描画順やアイコンの問題ではなく
        ///   純粋にテクスチャ数の上限に起因する。オーバーレイ画像を512×512へ縮小して
        ///   使用テクスチャ量を減らす対策も試したが、今度は複数の古地図を同時に縮小する際に
        ///   画像の一部が白く欠けて描画される別の不具合が発生したため見送った。
        ///   代わりに`maxSimultaneousAllOverlayImages`で、実画像を貼るオーバーレイの枚数
        ///   自体を上限（10枚未満）に抑えることで、チェックポイントのマーカー用テクスチャの
        ///   確保に必要な余裕を残すようにした。上限を超えた古地図は画像なし（枠だけ）の
        ///   オーバーレイのままになるが、チェックポイントのマーカーは全古地図分表示される。
        ///   この`.map = nil`→再代入は、その安全側の対策として引き続き残している。
        ///   単体の古地図を選んで表示するモードはこの制約の影響を受けない。
        private func bringCheckpointMarkersToFront(on mapView: GMSMapView) {
            // `.map`への再代入はマーカーの選択状態（＝開いている情報ウィンドウ）を
            // 解除してしまう。チェックポイントをタップした直後は、SDKが自動で
            // カメラをそのマーカーへ寄せるため`idleAt`が呼ばれ、ここで前面へ
            // 出し直す処理が走って開いたばかりの名前表示を即座に消してしまっていた。
            // 選択中のマーカーを覚えておき、再代入後に選択し直すことでこれを防ぐ。
            let selected = mapView.selectedMarker
            for marker in checkpointMarkers.values {
                // 既に`.map`が同じ`mapView`のままだと再代入が内部的に無視され、
                // 描画順が更新されないことがあるため、一度`nil`にしてから
                // 改めてセットし直すことで、確実に「最後に追加した」状態にする。
                marker.map = nil
                marker.map = mapView
            }
            if let selected, checkpointMarkers.values.contains(where: { $0 === selected }) {
                mapView.selectedMarker = selected
            }
        }

        /// 記録中に投稿した写真を、その場所に丸いサムネイルのピンとして地図上に共有表示する。
        /// 歩行記録中（`isRecordingWalk`）は、今まさに歩いている軌跡・現在地の方を
        /// 目立たせたいので、過去の投稿写真ピンは薄く控えめに表示する。
        func applyPhotoPosts(_ posts: [WalkPhotoPost], isRecordingWalk: Bool, to mapView: GMSMapView) {
            let currentIDs = Set(posts.map(\.id))
            let staleIDs = photoPostMarkers.keys.filter { !currentIDs.contains($0) }
            for id in staleIDs {
                photoPostMarkers[id]?.map = nil
                photoPostMarkers.removeValue(forKey: id)
            }

            for post in posts where photoPostMarkers[post.id] == nil {
                // `post.photo`はディスクからの読み込み＋JPEGデコードを伴い、キャッシュが
                // 無い時（アプリ起動直後など）はメインスレッドをブロックしてカクつきの
                // 原因になる。先にプレースホルダーのマーカーを即座に置き、実際の画像は
                // バックグラウンドで読み込んでから差し替える。
                let marker = GMSMarker(position: post.coordinate)
                marker.icon = Self.photoPostPlaceholderIcon
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.userData = post
                marker.zIndex = Self.photoPostMarkerZIndex
                marker.opacity = isRecordingWalk ? Self.dimmedPhotoPostOpacity : 1.0
                marker.map = mapView
                photoPostMarkers[post.id] = marker

                let filename = post.photoFileName
                DispatchQueue.global(qos: .userInitiated).async { [weak marker] in
                    guard let photo = StampPhotoStore.load(filename) else { return }
                    let thumbnail = Self.circularThumbnail(photo)
                    DispatchQueue.main.async {
                        marker?.icon = thumbnail
                    }
                }
            }

            guard isRecordingWalk != arePhotoPostsDimmed else { return }
            arePhotoPostsDimmed = isRecordingWalk
            let opacity: Float = isRecordingWalk ? Self.dimmedPhotoPostOpacity : 1.0
            for marker in photoPostMarkers.values {
                marker.opacity = opacity
            }
        }

        /// 歩行記録中に投稿写真ピンを薄く見せる不透明度。目立たなくはするが、
        /// タップして開けることが分かる程度には残す。
        private static let dimmedPhotoPostOpacity: Float = 0.35

        /// 現在地マークを描く。Google純正の「青い点」は使わず、写真ピンなど他の
        /// どのマーカーよりも必ず前面に出て、かつサイズも大きく分かりやすい
        /// 自前のマーカーにする。歩行記録中（`emphasized`）はさらに一回り大きくする。
        func applyCurrentLocationMarker(_ coordinate: CLLocationCoordinate2D?, emphasized: Bool, to mapView: GMSMapView) {
            guard let coordinate else {
                currentLocationMarker?.map = nil
                currentLocationMarker = nil
                return
            }

            if let marker = currentLocationMarker {
                marker.position = coordinate
                if emphasized != isCurrentLocationMarkerEmphasized {
                    isCurrentLocationMarkerEmphasized = emphasized
                    marker.icon = Self.currentLocationIcon(emphasized: emphasized)
                }
            } else {
                isCurrentLocationMarkerEmphasized = emphasized
                let marker = GMSMarker(position: coordinate)
                marker.icon = Self.currentLocationIcon(emphasized: emphasized)
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.zIndex = Self.currentLocationMarkerZIndex
                marker.isTappable = false
                marker.map = mapView
                currentLocationMarker = marker
            }
        }

        /// 現在地マークのアイコン。青い円＋白い縁取り。歩行記録中（`emphasized`）は
        /// 一回り大きく、外側にもう一段リングを足してさらに目立たせる。
        private static func currentLocationIcon(emphasized: Bool) -> UIImage {
            let diameter: CGFloat = emphasized ? 40 : 26
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
            return renderer.image { context in
                let cg = context.cgContext
                let center = CGPoint(x: diameter / 2, y: diameter / 2)

                if emphasized {
                    // 外側の薄いリング（現在地の存在感を広げる）。
                    let outerRadius = diameter / 2 - 1
                    cg.setFillColor(UIColor.systemBlue.withAlphaComponent(0.22).cgColor)
                    cg.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    cg.fillPath()
                }

                // 白い縁取り。
                let dotDiameter: CGFloat = emphasized ? 26 : 20
                let dotRect = CGRect(
                    x: center.x - dotDiameter / 2,
                    y: center.y - dotDiameter / 2,
                    width: dotDiameter,
                    height: dotDiameter
                )
                cg.setFillColor(UIColor.white.cgColor)
                cg.addEllipse(in: dotRect)
                cg.fillPath()

                // 中の青い点。
                let innerInset: CGFloat = 3.5
                let innerRect = dotRect.insetBy(dx: innerInset, dy: innerInset)
                cg.setFillColor(UIColor.systemBlue.cgColor)
                cg.addEllipse(in: innerRect)
                cg.fillPath()
            }
        }

        /// 写真ピンがタップされたら、吹き出しを出さずに直接プレビューを開く。
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let post = marker.userData as? WalkPhotoPost else { return false }
            onPhotoPostTap(post)
            return true
        }

        /// 投稿写真をピン用に、金色の縁取りをつけた丸いサムネイルへ変換する。
        /// 投稿写真の読み込みが終わるまでの間だけ表示する、中身のない丸いプレースホルダー。
        private static let photoPostPlaceholderIcon: UIImage = {
            let diameter: CGFloat = 32
            let borderWidth: CGFloat = 3
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
            return renderer.image { context in
                let rect = CGRect(x: borderWidth / 2, y: borderWidth / 2, width: diameter - borderWidth, height: diameter - borderWidth)
                let ovalPath = UIBezierPath(ovalIn: rect)
                UIColor(white: 0.85, alpha: 1).setFill()
                ovalPath.fill()
                UIColor(red: 0.86, green: 0.63, blue: 0.24, alpha: 1).setStroke()
                ovalPath.lineWidth = borderWidth
                ovalPath.stroke()
            }
        }()

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
