import CoreLocation
import GoogleMaps
import SwiftUI

/// 件数に上限を持たせた画像キャッシュ。上限を超えたら、最も長くアクセスされていない
/// ものから捨てる（簡易LRU）。古地図のデコード結果キャッシュのように、キー自体は
/// アプリの寿命中増え続けうるが、実際に画面に必要なのは直近に見ていた数枚だけ、
/// という用途で無制限にメモリを使い続けないようにするために使う。
private struct BoundedImageCache {
    private var storage: [String: UIImage] = [:]
    /// 古い方が先頭。アクセス（読み書き）のたびに末尾へ移動する。
    private var accessOrder: [String] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
    }

    subscript(key: String) -> UIImage? {
        mutating get {
            guard let value = storage[key] else { return nil }
            touch(key)
            return value
        }
        set {
            guard let newValue else {
                storage.removeValue(forKey: key)
                accessOrder.removeAll { $0 == key }
                return
            }
            storage[key] = newValue
            touch(key)
            evictLeastRecentlyUsedIfNeeded()
        }
    }

    private mutating func touch(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private mutating func evictLeastRecentlyUsedIfNeeded() {
        while accessOrder.count > capacity {
            let oldest = accessOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}

/// `GMSMapView` をSwiftUIに橋渡しするラッパー。
///
/// 現在地表示・古地図のグラウンドオーバーレイ（不透明度つき）・
/// タップ地点の検出を担当する。
struct GoogleMapRepresentable: UIViewRepresentable {
    var overlayMap: HistoricalOverlayMap?
    var overlayOpacity: Float
    /// 現在地。自前で描く現在地マーク（`applyCurrentLocationMarker`）の位置に使う。
    var currentLocation: CLLocationCoordinate2D?
    /// 進行方向（true northから時計回りの度数）。歩行記録中、現在地マークに
    /// 添える小さな矢印の向きに使う。算出できていない間は`nil`（矢印を出さない）。
    var currentHeading: CLLocationDirection?
    /// 現在地マークの見た目。「設定」画面で選べる。
    var currentLocationIconStyle: CurrentLocationIconStyle = .blueDot
    /// `true`の間は`overlayMap`単体ではなく、同梱・登録済みの古地図すべてを
    /// 地図上に重ねて表示する（「全ての古地図を表示」選択時）。
    var showAllOverlays: Bool = false
    /// カメラを移動させたい座標のリクエスト。同じ`id`には一度だけ反応する
    /// （同じ座標への再移動要求も、`id`が新しければ改めて移動する）。
    var moveCameraRequest: CameraMoveRequest?
    /// 古地図オーバーレイを貼り直したいというリクエスト。`overlayMap`のidが
    /// 変わっていなくても（＝同じ古地図が選び直されても）、新しい`id`であれば
    /// 一度だけ、オーバーレイを一旦マップから外して付け直す
    /// （GPU側のテクスチャ喪失バグから復帰させるため）。
    var reattachOverlayRequest: UUID?
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
    /// カメラが止まるたびに、その時の表示範囲（南西・北東）を渡す。
    var onVisibleBoundsChange: (OldMapSearchBounds) -> Void = { _ in }

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
        // 描画の負荷を下げる。既定の`.maximum`は120Hz機で毎秒120回も描き直すため、
        // 60回で十分な地図の表示・スクロールでは無駄にGPU・CPUを使っていた。
        // 古地図の上では立体の建物・屋内地図は見えず不要なので、その描画も止める。
        mapView.preferredFrameRate = .conservative
        mapView.isBuildingsEnabled = false
        mapView.isIndoorEnabled = false
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
        context.coordinator.onVisibleBoundsChange = onVisibleBoundsChange
        context.coordinator.mapView = mapView
        // 歩行記録中（iPhone本体・Apple Watch伴走どちらでも）は、GPSの更新が来ない
        // （信号待ち・写真撮影などで静止している）間もGPU側のテクスチャ喪失バグから
        // 定期的に回復できるよう、カメラ操作にもGPS更新にも頼らない貼り直しタイマーを動かす。
        context.coordinator.setWalkingHealingTimerActive(isRecordingWalk)
        if showAllOverlays {
            context.coordinator.applyAllOverlays(OldMapCatalog.allIncludingCustom, checkpoints: checkpoints, to: mapView)
        } else {
            context.coordinator.removeAllOverlays()
            context.coordinator.applyOverlay(
                overlayMap,
                opacity: overlayOpacity,
                checkpoints: checkpoints,
                reattachRequestID: reattachOverlayRequest,
                to: mapView
            )
        }
        context.coordinator.applyWalkPaths(saved: savedWalkPaths, live: liveWalkPath, isRecording: isRecordingWalk, to: mapView)
        context.coordinator.applyCheckpoints(checkpoints, collectedSiteIDs: collectedSiteIDs, to: mapView)
        context.coordinator.applyPhotoPosts(photoPosts, isRecordingWalk: isRecordingWalk, to: mapView)
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)

        if let request = moveCameraRequest, context.coordinator.lastHandledMoveRequestID != request.id {
            context.coordinator.lastHandledMoveRequestID = request.id
            mapView.animate(to: GMSCameraPosition.camera(withTarget: request.coordinate, zoom: request.zoom ?? mapView.camera.zoom))
        }

        context.coordinator.applyCurrentLocationMarker(
            currentLocation,
            heading: currentHeading,
            emphasized: isRecordingWalk,
            style: currentLocationIconStyle,
            to: mapView
        )
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(onTap: onTap)
        // このView自体が生成される前から存在していたカメラ移動リクエストは、
        // 「既に処理済み」として扱う。そうしないと、マップタブを離れて戻ってきた時に
        // （Viewが作り直されてCoordinatorも真新しくなるため）、以前の現在地追従などで
        // 残っていた古いリクエストがここで初めて処理され、チェックポイントに合わせた
        // 初期カメラフィットを直後に上書きしてしまう。
        coordinator.lastHandledMoveRequestID = moveCameraRequest?.id
        // カメラ移動リクエストと同様、View生成前から存在していた貼り直しリクエストは
        // 「既に処理済み」として扱う（タブを離れて戻ってきた時に、古いリクエストで
        // 無駄な貼り直しが起きないようにするため）。
        coordinator.lastHandledReattachRequestID = reattachOverlayRequest
        return coordinator
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onTap: (CLLocationCoordinate2D) -> Void
        var onCheckpointTap: (HistoricSite) -> Void = { _ in }
        var onPhotoPostTap: (WalkPhotoPost) -> Void = { _ in }
        var onUserPanned: () -> Void = {}
        var onVisibleBoundsChange: (OldMapSearchBounds) -> Void = { _ in }
        var lastHandledMoveRequestID: UUID?
        var lastHandledReattachRequestID: UUID?
        /// 貼り直しタイマー（`setWalkingHealingTimerActive`）が使う、最新の`mapView`への弱参照。
        weak var mapView: GMSMapView?
        /// 歩行記録中、GPSの更新にもカメラ操作にも頼らずオーバーレイを定期的に貼り直すタイマー。
        private var walkingHealingTimer: Timer?
        private static let walkingHealingInterval: TimeInterval = 4

        private var currentOverlay: GMSGroundOverlay?
        private var currentOverlayID: String?
        /// `currentOverlayID`に画像の識別子を加えたもの（画像差し替えの検知用）。
        private var currentOverlayKey: String?
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
        /// 直近に描いた現在地マークの見た目スタイル。「設定」で変えた時だけアイコンを作り直す。
        private var currentLocationIconStyleUsed: CurrentLocationIconStyle?
        /// 歩行記録中、進行方向を示す小さな三角を現在地マークのすぐ外側に表示するための
        /// 専用マーカー（本体のマーカーは回転させず、この三角だけ`rotation`で向きを変える）。
        private var headingMarker: GMSMarker?
        /// 直近に三角へ適用した見た目スタイル。現在地マークの色（`CurrentLocationIconStyle`）に
        /// 揃えるため、これが変わった時だけアイコンを作り直す。
        private var headingIconStyleUsed: CurrentLocationIconStyle?
        /// 直近に投稿写真ピンへ適用した「記録中で薄く表示」状態。
        private var arePhotoPostsDimmed = false

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
            currentOverlayKey = nil

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

        /// 古地図を貼り替える。歩行記録中かどうかによらず、常にスライダーの不透明度を
        /// 画像全体にかけて表示する（以前あった、通った場所だけくっきり見せる
        /// 「宝探し」演出は廃止。歩行中も古地図がずっとちゃんと見えるようにするため）。
        func applyOverlay(
            _ overlayMap: HistoricalOverlayMap?,
            opacity: Float,
            checkpoints: [HistoricSite] = [],
            reattachRequestID: UUID? = nil,
            to mapView: GMSMapView
        ) {
            guard let overlayMap else {
                currentOverlay?.map = nil
                currentOverlay = nil
                currentOverlayID = nil
                currentOverlayKey = nil
                currentBaseImage = nil
                return
            }

            // 同じ古地図が選び直された場合でも、新しい貼り直しリクエストが来ていれば
            // （＝ユーザーが古地図メニューを操作した直後であれば）、`idleAt`の
            // ワークアラウンドと同じ方法（一旦マップから外して付け直す）でオーバーレイを
            // 復帰させる。テクスチャの作り直しは行わないため軽量。
            let shouldForceReattach = reattachRequestID != nil && reattachRequestID != lastHandledReattachRequestID
            if let reattachRequestID {
                lastHandledReattachRequestID = reattachRequestID
            }

            // 画像を差し替えた古地図（同じIDで`imageFileName`だけ変わる）で古い画像が
            // 使い回されないよう、作り直しの判定・キャッシュのキーには画像の識別子も含める。
            let cacheKey = "\(overlayMap.id)|\(overlayMap.imageFileName ?? overlayMap.imageAssetName ?? "")"
            let isNewOverlay = currentOverlayKey != cacheKey
            if !isNewOverlay && shouldForceReattach, let currentOverlay {
                currentOverlay.map = nil
                currentOverlay.map = mapView
            }
            if isNewOverlay {
                // 古いオーバーレイのテクスチャをすぐに手放せるよう、`.map = nil`の前に
                // `.icon`も明示的に外しておく（`.map = nil`だけでは、Google Maps SDK内部の
                // テクスチャアトラスがすぐには解放されないことがある）。
                currentOverlay?.icon = nil
                currentOverlay?.map = nil

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
                if let cached = Self.singleOverlayImageCache[cacheKey] {
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
                            Self.singleOverlayImageCache[cacheKey] = downsampled
                        }
                        DispatchQueue.main.async {
                            guard let self, self.currentOverlayKey == cacheKey else { return }
                            self.currentBaseImage = downsampled
                            self.currentOverlay?.icon = downsampled
                            // この時点でスライダーの不透明度を反映しておく（次の`updateUIView`を
                            // 待たず、画像が現れた瞬間から正しい濃さで見えるようにする）。
                            self.currentOverlay?.opacity = opacity
                        }
                    }
                }
                currentOverlayID = overlayMap.id
                currentOverlayKey = cacheKey

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
            }

            guard let currentOverlay, let baseImage = currentBaseImage else { return }

            // 歩行記録中かどうかによらず、ベース画像をそのままスライダーの不透明度で見せる。
            if currentOverlay.icon !== baseImage {
                currentOverlay.icon = baseImage
            }
            currentOverlay.opacity = opacity
        }

        /// 単体表示（`applyOverlay`）でダウンサンプルした結果を、古地図IDごとに使い回す
        /// キャッシュ。同梱画像はアプリ起動中に内容が変わらないため、同じ古地図を
        /// 選び直しても2回目以降は重いデコード・縮小処理をスキップし、即座に表示できる。
        /// 件数に上限を持たせ、古地図を何枚も切り替えるセッションで（1枚あたり1600px四方
        /// までのデコード済み画像が）メモリに溜まり続けないようにする。
        private static var singleOverlayImageCache = BoundedImageCache(capacity: 6)

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
        /// 件数に上限を持たせ、メモリに溜まり続けないようにする（`singleOverlayImageCache`と同様）。
        private static var downsampledImageCache = BoundedImageCache(capacity: 8)

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
            let region = mapView.projection.visibleRegion()
            let bounds = GMSCoordinateBounds(region: region)
            onVisibleBoundsChange(OldMapSearchBounds(southWest: bounds.southWest, northEast: bounds.northEast))
            if let lastOverlayRefreshZoom,
               abs(position.zoom - lastOverlayRefreshZoom) < overlayRefreshZoomThreshold {
                return
            }
            lastOverlayRefreshZoom = position.zoom
            reattachOverlaysAndMarkers(to: mapView)
        }

        /// 古地図オーバーレイ・チェックポイントのマーカー・現在地マークを、画像の再デコードなど
        /// 重い処理をせずに一旦外して貼り直す（GPU側のテクスチャ喪失バグからの回復策）。
        /// `idleAt`（カメラのズーム変化時）と、歩行記録中の貼り直しタイマーの両方から呼ぶ。
        private func reattachOverlaysAndMarkers(to mapView: GMSMapView) {
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
            if let headingMarker {
                headingMarker.map = nil
                headingMarker.map = mapView
            }
        }

        /// 歩行記録中かどうかに応じて、定期貼り直しタイマーを開始・停止する。
        /// GPSの更新が来ない（信号待ち・写真撮影などで静止している）間や、カメラを
        /// 操作していない間も、一定間隔でオーバーレイを貼り直し続けることで、
        /// 古地図が消えたまま長時間戻らない状態を防ぐ。
        func setWalkingHealingTimerActive(_ isActive: Bool) {
            guard isActive else {
                walkingHealingTimer?.invalidate()
                walkingHealingTimer = nil
                return
            }
            guard walkingHealingTimer == nil else { return }
            walkingHealingTimer = Timer.scheduledTimer(withTimeInterval: Self.walkingHealingInterval, repeats: true) { [weak self] _ in
                guard let self, let mapView = self.mapView else { return }
                self.reattachOverlaysAndMarkers(to: mapView)
            }
        }

        deinit {
            walkingHealingTimer?.invalidate()
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
        /// 見た目（`style`）は「設定」画面で選べる（`CurrentLocationIconStyle`）。
        func applyCurrentLocationMarker(
            _ coordinate: CLLocationCoordinate2D?,
            heading: CLLocationDirection?,
            emphasized: Bool,
            style: CurrentLocationIconStyle,
            to mapView: GMSMapView
        ) {
            guard let coordinate else {
                currentLocationMarker?.map = nil
                currentLocationMarker = nil
                headingMarker?.map = nil
                headingMarker = nil
                return
            }

            if let marker = currentLocationMarker {
                marker.position = coordinate
                if emphasized != isCurrentLocationMarkerEmphasized || style != currentLocationIconStyleUsed {
                    isCurrentLocationMarkerEmphasized = emphasized
                    currentLocationIconStyleUsed = style
                    marker.icon = style.icon(emphasized: emphasized)
                }
            } else {
                isCurrentLocationMarkerEmphasized = emphasized
                currentLocationIconStyleUsed = style
                let marker = GMSMarker(position: coordinate)
                marker.icon = style.icon(emphasized: emphasized)
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.zIndex = Self.currentLocationMarkerZIndex
                marker.isTappable = false
                marker.map = mapView
                currentLocationMarker = marker
            }

            // 歩行記録中、進行方向が分かっている間だけ、現在地マークから外向きに
            // 突き出す小さな三角で進んでいる方向を示す。静止中・記録していない時は隠す。
            guard emphasized, let heading else {
                headingMarker?.map = nil
                return
            }
            if let headingMarker {
                headingMarker.position = coordinate
                headingMarker.rotation = heading
                if style != headingIconStyleUsed {
                    headingIconStyleUsed = style
                    headingMarker.icon = Self.makeHeadingIcon(color: style.accentColor)
                }
                headingMarker.map = mapView
            } else {
                headingIconStyleUsed = style
                let marker = GMSMarker(position: coordinate)
                marker.icon = Self.makeHeadingIcon(color: style.accentColor)
                marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
                marker.rotation = heading
                marker.zIndex = Self.currentLocationMarkerZIndex + 1
                marker.isTappable = false
                marker.map = mapView
                headingMarker = marker
            }
        }

        /// 進行方向を示す小さな三角アイコン。現在地マーク（`CurrentLocationIconStyle`）の
        /// 色に揃える。土台（下辺）を現在地マークの中心に合わせて描くため、
        /// `groundAnchor`は下辺中央（(0.5, 1.0)）にする（`applyCurrentLocationMarker`参照）。
        private static func makeHeadingIcon(color: UIColor) -> UIImage {
            let size = CGSize(width: 16, height: 20)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let cg = context.cgContext
                let path = CGMutablePath()
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()

                cg.addPath(path)
                cg.setFillColor(color.cgColor)
                cg.fillPath()

                cg.addPath(path)
                cg.setStrokeColor(UIColor.white.cgColor)
                cg.setLineWidth(1.5)
                cg.strokePath()
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
