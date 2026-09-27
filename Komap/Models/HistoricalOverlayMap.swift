import CoreLocation
import Foundation
import UIKit

/// 古地図1枚分の情報（画像・時代・位置合わせ範囲）を表す。
///
/// - Important: `southWest` / `northEast` はこのサンプルアプリ用に用意した
///   仮の位置合わせ座標です。実際の古地図画像を使う場合は、当時の絵図を
///   現代の緯度経度に正確に対応させた座標に置き換えてください。
struct HistoricalOverlayMap: Identifiable, Hashable {
    let id: String
    /// 一覧・ピッカーに表示する名称（例: 「江戸城 安政期」）
    let title: String
    /// AIへの物語生成プロンプトに渡す時代表現（例: 「江戸時代後期（1850年代・安政期）」）
    let era: String
    /// 短い紹介文（ピッカーやカード表示用）
    let summary: String
    /// Assets.xcassets 内の画像名。同梱の古地図で使う。
    ///
    /// - Important: 画像は必ず1024×1024pxの正方形にしておくこと（縦横比が違う元画像は
    ///   白背景でレターボックス/ピラーボックスして正方形にする）。1024×1024以外のサイズ
    ///   （1536×1536のような正方形でも、1200×895のような長方形でも）だと、Google Maps SDKの
    ///   `GMSGroundOverlay`がこの環境では画像を一切描画しない（チェックポイントや base map は
    ///   正常なのに、古地図の帯だけ完全に透明になる）不具合を確認している。原因はSDK内部の
    ///   テクスチャ処理側にあると見られ、アプリ側のコードでは検出できない（エラーもログも出ない）。
    let imageAssetName: String?
    /// `StampPhotoStore`に保存したファイル名。検索して追加した古地図で使う。
    let imageFileName: String?
    /// 画像の左下（南西）に対応する緯度経度。`bearing`が0でない場合、実際に画像が
    /// 覆う範囲はこの矩形を`bearing`の分だけ中心を軸に回転させたものになる
    /// （`GMSGroundOverlay.bearing`と同じ仕様）。
    let southWest: CLLocationCoordinate2D
    /// 画像の右上（北東）に対応する緯度経度
    let northEast: CLLocationCoordinate2D
    /// 画像の「上」が指す方角（真北から時計回りの度数）。0なら回転なし（画像の上＝北）。
    /// 手描きの古地図は必ずしも北を上にして描かれていないため、実際の地理と重ねる際に
    /// 画像そのものを回転させたい場合に使う。
    let bearing: CLLocationDirection

    init(
        id: String,
        title: String,
        era: String,
        summary: String,
        imageAssetName: String? = nil,
        imageFileName: String? = nil,
        southWest: CLLocationCoordinate2D,
        northEast: CLLocationCoordinate2D,
        bearing: CLLocationDirection = 0
    ) {
        self.id = id
        self.title = title
        self.era = era
        self.summary = summary
        self.imageAssetName = imageAssetName
        self.imageFileName = imageFileName
        self.southWest = southWest
        self.northEast = northEast
        self.bearing = bearing
    }

    /// この古地図がカバーする範囲の中心（初期表示時のカメラ位置に使う）
    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (southWest.latitude + northEast.latitude) / 2,
            longitude: (southWest.longitude + northEast.longitude) / 2
        )
    }

    /// この古地図の表示範囲（`bearing`による画像の回転も考慮）に、指定した座標が
    /// 含まれるかどうか。「全ての古地図を表示」中に地図をタップして、その古地図単体の
    /// 表示に切り替える機能で使う。
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard let fraction = imageFraction(of: coordinate) else { return false }
        return (0...1).contains(fraction.u) && (0...1).contains(fraction.v)
    }

    /// 座標が、画像（`bearing`による回転も考慮）のどこにあたるか。左上を原点とした
    /// 0〜1の割合（範囲外なら0〜1をはみ出す）。古地図の詳細画面で、画像の上に
    /// チェックポイントを重ねて描くために使う。範囲が潰れている時は`nil`。
    func imageFraction(of coordinate: CLLocationCoordinate2D) -> (u: Double, v: Double)? {
        let centerLat = (southWest.latitude + northEast.latitude) / 2
        let centerLng = (southWest.longitude + northEast.longitude) / 2
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLng = 111_320.0 * cos(centerLat * .pi / 180)

        let eastMeters = (coordinate.longitude - centerLng) * metersPerDegreeLng
        let northMeters = (coordinate.latitude - centerLat) * metersPerDegreeLat

        let bearingRad = bearing * .pi / 180
        let uMeters = eastMeters * cos(bearingRad) - northMeters * sin(bearingRad)
        let vMeters = -eastMeters * sin(bearingRad) - northMeters * cos(bearingRad)

        let widthMeters = (northEast.longitude - southWest.longitude) * metersPerDegreeLng
        let heightMeters = (northEast.latitude - southWest.latitude) * metersPerDegreeLat
        guard widthMeters != 0, heightMeters != 0 else { return nil }

        return (0.5 + uMeters / widthMeters, 0.5 + vMeters / heightMeters)
    }

    /// 地図上部のラベルなど、短い表示が必要な場所で使う名称。
    /// 「東海道（日本橋・芝増上寺・品川）」のような、括弧で補足を添えた`title`から
    /// 括弧部分を取り除いたもの（括弧が無ければ`title`のまま）。
    var shortTitle: String {
        guard let openRange = title.range(of: "（") else { return title }
        return String(title[title.startIndex..<openRange.lowerBound])
    }

    /// 同梱アセット・検索で追加した画像のどちらかから、表示用の画像を読み込む。
    var image: UIImage? {
        // 管理者が差し替えた画像（ファイル）があれば、同梱の画像より優先する。
        if let imageFileName, let image = StampPhotoStore.load(imageFileName) {
            return image
        }
        if let imageAssetName {
            return UIImage(named: imageAssetName)
        }
        return nil
    }

    static func == (lhs: HistoricalOverlayMap, rhs: HistoricalOverlayMap) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// アプリに同梱している古地図のカタログ。
///
/// ユーザーは後からここに新しい古地図（画像 + 位置合わせ座標）を
/// 追加するだけで、選択肢を増やすことができる。
enum OldMapCatalog {
    // 同梱の古地図（`edoCastle`など）・一覧（`all`）・分類（`categoryByID`）・統合済みIDの対応表
    // （`mergedIntoID`）は、`catalog/old_maps.json`から生成した`Generated/OldMapCatalogData.swift`にある。
    // 古地図を追加・変更する時はJSONを編集し、`node scripts/generate-catalog.mjs`を実行する。

    /// アプリ起動時・記録開始時などにデフォルトで選ぶ古地図。「設定」の
    /// 「古地図のデフォルト」で選んだものを`AppSettings.defaultOverlayMapID`から読み、
    /// 未設定・削除済み・選んでいるリージョンの外なら、そのリージョンの最初の古地図
    /// （Japanなら同梱の「江戸城周辺」）にする。リージョンに古地図が1枚も無ければ`nil`。
    static var defaultOverlay: HistoricalOverlayMap? {
        if let overlay = resolve(id: AppSettings.defaultOverlayMapID), !isHiddenBySettings(overlay) {
            return overlay
        }
        if !isHiddenBySettings(edoCastle) { return edoCastle }
        return visibleIncludingCustom.first
    }

    /// 古地図選択シートでの分類（`OldMapPickerSheet`のセクション分けに使う）。
    enum Category: String, CaseIterable {
        case historicSites = "旧跡・名所巡り"
        case kaido = "街道巡り"
        case animePilgrimage = "アニメ・映画聖地巡礼"
        /// Europeの北欧・バルト海沿岸の旧市街（アムステルダム・ヘルシンキ・ストックホルム・タリン）。
        case oldTowns = "北欧旧市街巡り"
        /// Europeの西ヨーロッパ（パリの芸術家の家めぐり・シェイクスピアの時代のロンドン）。
        case westernEurope = "西ヨーロッパ"
        /// Asiaの古都・聖地（北京・西安・ラサ・アンコール・デリー・イスファハーン・エルサレム）。
        case ancientCapitals = "古都・聖地巡り"
        /// Americaの歴史地区（ボストン・ニューヨーク・メキシコシティ・クスコ・ブエノスアイレス）。
        case colonialCities = "歴史地区巡り"
    }


    /// この古地図が属する分類。同梱リストにない（ユーザーが検索して追加した）古地図は`nil`。
    static func category(of overlay: HistoricalOverlayMap) -> Category? {
        categoryByID[overlay.id]
    }

    /// 古地図が属するリージョン（地図の中心の位置で決める。追加した古地図も同じ）。
    static func region(of overlay: HistoricalOverlayMap) -> MapRegion {
        MapRegion(containing: overlay.center)
    }

    /// 「設定」で選んでいるリージョンの外にあるため、選択肢・全地図表示などから外す古地図か。
    /// 過去の記録や御朱印からIDで引く（`resolve`・`overlay(withID:)`）分には影響しない。
    static func isHiddenBySettings(_ overlay: HistoricalOverlayMap) -> Bool {
        region(of: overlay) != AppSettings.mapRegion
    }

    static func isHiddenBySettings(overlayID: String) -> Bool {
        guard let overlay = overlay(withID: overlayID) else { return false }
        return isHiddenBySettings(overlay)
    }

    /// 古地図選択シートに並べる分類（選んでいるリージョンの古地図が1枚も無い分類を除く）。
    static var visibleCategories: [Category] {
        Category.allCases.filter { category in
            (allByCategory[category] ?? []).contains { !isHiddenBySettings($0) }
        }
    }

    /// `allIncludingCustom`から、設定で非表示にしている古地図を除いたもの。
    /// 古地図の選択肢・全地図表示・現在地からの古地図選択に使う。
    ///
    /// 「全ての古地図を表示」中は歩行のGPS更新のたびに参照されるため、設定の値ごとに
    /// 絞り込んだ結果を覚えておく（`allIncludingCustom`が作り直される時に一緒に捨てる）。
    static var visibleIncludingCustom: [HistoricalOverlayMap] {
        let region = AppSettings.mapRegion
        if let visibleCache, visibleCache.region == region {
            return visibleCache.overlays
        }
        let visible = allIncludingCustom.filter { self.region(of: $0) == region }
        visibleCache = (region, visible)
        return visible
    }

    private static var visibleCache: (region: MapRegion, overlays: [HistoricalOverlayMap])?

    /// 古地図の一覧（同梱＋追加＋管理者の上書き）が変わるたびに増える番号。地図画面は、
    /// この番号と設定の値が前回と同じなら、全地図の重ね直しの判定自体を省く。
    private(set) static var revision = 0

    /// `allIncludingCustom`の結果のキャッシュ。「全ての古地図を表示」中は歩行のGPS更新の
    /// たびに参照されるため、変化がない間は配列の再構築（同梱リストとカスタム古地図の
    /// 結合・`HistoricalOverlayMap`値のコピー）を毎回行わずに済ませる。
    private static var allIncludingCustomCache: [HistoricalOverlayMap]?

    /// 同梱の古地図 + ユーザーが検索して追加した古地図。
    static var allIncludingCustom: [HistoricalOverlayMap] {
        if let allIncludingCustomCache {
            return allIncludingCustomCache
        }
        let combined = all.map(OverlayOverrideStore.apply(to:)) + CustomOverlayMapStore.all()
        allIncludingCustomCache = combined
        allIncludingCustomByID = Dictionary(combined.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return combined
    }

    /// `allIncludingCustom`のID索引（キャッシュと同時に作り直す）。
    private static var allIncludingCustomByID: [String: HistoricalOverlayMap] = [:]

    /// 同梱・追加済みの古地図からIDで1件探す。全件走査せず索引を引く。
    static func overlay(withID id: String) -> HistoricalOverlayMap? {
        _ = allIncludingCustom
        return allIncludingCustomByID[id]
    }

    /// 同梱の古地図のIDかどうか（管理者による上書きの対象になる）。
    static func isBundled(id: String) -> Bool {
        bundledIDs.contains(id)
    }

    private static let bundledIDs = Set(all.map(\.id))

    /// 分類ごとの同梱古地図（一覧シートの表示のたびに絞り込み直さないよう、一度だけ作る）。
    static let allByCategory: [Category: [HistoricalOverlayMap]] = Dictionary(
        grouping: all.filter { category(of: $0) != nil }, by: { category(of: $0)! }
    )

    /// カスタム古地図が追加された時など、`allIncludingCustom`の内容が実際に変わった
    /// タイミングで呼び、次回参照時に作り直させる。
    static func invalidateAllIncludingCustomCache() {
        allIncludingCustomCache = nil
        allIncludingCustomByID = [:]
        visibleCache = nil
        revision += 1
    }


    /// 保存されているIDを、廃止されていれば統合先のIDに読み替えてから古地図を探す。
    static func resolve(id: String?) -> HistoricalOverlayMap? {
        guard let id else { return nil }
        let resolvedID = mergedIntoID[id] ?? id
        return overlay(withID: resolvedID)
    }
}

/// 「設定」で選ぶ古地図のリージョン。選んだリージョンの古地図だけを、古地図の選択肢・全地図表示・
/// 現在地からの古地図選択・御朱印一覧に出す。古地図の中心の位置で自動的に振り分ける。
enum MapRegion: String, CaseIterable, Identifiable {
    case japan, europe, asia, america

    var id: String { rawValue }

    var title: String {
        switch self {
        case .japan: return "Japan"
        case .europe: return "Europe"
        case .asia: return "Asia"
        case .america: return "America"
        }
    }

    var subtitle: String {
        switch self {
        case .japan: return "日本"
        case .europe: return "ヨーロッパ"
        case .asia: return "アジア・その他"
        case .america: return "南北アメリカ"
        }
    }

    /// 位置からリージョンを決める（日本 → ヨーロッパ → 南北アメリカの範囲に入らなければアジア）。
    init(containing coordinate: CLLocationCoordinate2D) {
        let lat = coordinate.latitude, lon = coordinate.longitude
        if (24...46).contains(lat) && (122...154).contains(lon) {
            self = .japan
        } else if (34...72).contains(lat) && (-25...45).contains(lon) {
            self = .europe
        } else if (-170 ... -30).contains(lon) {
            self = .america
        } else {
            self = .asia
        }
    }
}

extension MapRegion {
    /// 「みんなの旅」「みんなの古地図」（Webも同じ）で、リージョンごとに分けて並べる時の順番。
    static let displayOrder: [MapRegion] = [.europe, .america, .japan, .asia]
}

/// 「みんなの旅」を各リージョンの中で並べる順番（Webの`tripSort.ts`と同じ選択肢）。
enum TripSortOrder: String, CaseIterable, Identifiable {
    /// いいねの多い順（同じ数なら日付の新しい順、さらに距離の長い順）。
    case likes
    /// 日付の新しい順。
    case date
    /// 歩いた距離の長い順。
    case distance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .likes: return "いいね順"
        case .date: return "日付順"
        case .distance: return "距離順"
        }
    }
}
