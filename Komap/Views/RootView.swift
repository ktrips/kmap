import SwiftUI

struct RootView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var mapSession = MapSessionState()

    var body: some View {
        Group {
            if SecretsConfig.isGoogleMapsAPIKeyConfigured {
                MainTabView()
            } else {
                GoogleMapsSetupNoticeView()
            }
        }
        .environmentObject(authService)
        .environmentObject(mapSession)
    }
}

/// Google Maps APIキーが未設定の場合に表示する案内画面。
/// キーが無いと `GMSMapView` はエラーになるため、地図タブそのものを出さずに案内する。
private struct GoogleMapsSetupNoticeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Google Maps APIキーが未設定です")
                    .font(.title2.bold())
                Text("""
                このアプリを動かすには、Google Maps SDK for iOSのAPIキーが必要です。
                リポジトリ内の Config/Secrets.xcconfig を開き、
                GOOGLE_MAPS_API_KEY にご自身のAPIキーを設定してから、
                再ビルドしてください。
                """)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

                Link(destination: URL(string: "https://developers.google.com/maps/documentation/ios-sdk/get-api-key")!) {
                    Text("APIキーの取得方法を見る")
                }
                .padding(.top, 4)
            }
            .padding()
            .navigationTitle("セットアップが必要です")
        }
    }
}

/// 画面下部のタブバーを使わず、`mapSession.selectedTab`に応じて
/// マップ・My Trips・設定を切り替える。マップは全画面表示にし、左上に浮かせた
/// 「マイ時空旅」「古地図選択」、右上に浮かせた「セットアップ」のボタンから他画面へ移動する。
private struct MainTabView: View {
    @EnvironmentObject private var mapSession: MapSessionState

    var body: some View {
        ZStack {
            // マップタブは`switch`で条件分岐させず、常にマウントしたまま表示・非表示だけを
            // 切り替える。以前は他タブへ移動するたびに`MapScreen`（＝`GMSMapView`本体・
            // GPSのLocationManager・チェックポイントのマーカー・古地図オーバーレイの画像）が
            // 丸ごと作り直されており、マップタブに戻るたびに毎回同じ初期化コストを
            // 払っていたため「地図の表示が遅い」原因になっていた。
            ZStack(alignment: .topLeading) {
                MapScreen()
                MapTopLeftControls()
            }
            .overlay(alignment: .top) {
                MapTopCenterOverlayLabel()
            }
            .overlay(alignment: .topTrailing) {
                MapTopRightControls()
            }
            .opacity(mapSession.selectedTab == .map ? 1 : 0)
            .allowsHitTesting(mapSession.selectedTab == .map)

            if mapSession.selectedTab == .myTimeTrip {
                MyTimeTripView()
            } else if mapSession.selectedTab == .settings {
                SettingsView()
            }
        }
    }
}

/// マップ画面の左上に浮かせる、「マイ時空旅」への直接のショートカットボタンと、
/// その真下に並べた「古地図選択」ボタン（押すとすぐ古地図選択シートを開く）。
private struct MapTopLeftControls: View {
    @EnvironmentObject private var mapSession: MapSessionState
    @State private var isPresentingOldMapPicker = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                mapSession.selectedTab = .myTimeTrip
            } label: {
                Image(systemName: "book.closed.fill")
                    .roundControlButtonStyle()
            }
            .accessibilityLabel("マイ時空旅")

            Button {
                isPresentingOldMapPicker = true
            } label: {
                Image(systemName: "map")
                    .roundControlButtonStyle()
            }
            .accessibilityLabel("古地図選択")
        }
        .padding(.top, 8)
        .padding(.leading, 16)
        .sheet(isPresented: $isPresentingOldMapPicker) {
            OldMapPickerSheet(
                selectedOverlay: $mapSession.selectedOverlay,
                isShowingAllOverlays: $mapSession.isShowingAllOverlays,
                onRequestSearch: {
                    mapSession.isShowingOldMapSearch = true
                }
            )
        }
    }
}

/// マップ画面の右上に浮かせる、「セットアップ」への直接のショートカットボタン
/// （以前はハンバーガーメニューだったが、押すとすぐセットアップ画面を開く形にした。
/// 「Komapの使い方」はセットアップ画面の下部に移した）。
private struct MapTopRightControls: View {
    @EnvironmentObject private var mapSession: MapSessionState

    var body: some View {
        Button {
            mapSession.selectedTab = .settings
        } label: {
            Image(systemName: "line.3.horizontal")
                .roundControlButtonStyle()
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
        .accessibilityLabel("セットアップ")
    }
}

/// マップ画面の上部中央に浮かせる、選択中の古地図名のラベル。
/// 押すと、その地域の簡単な説明とチェックポイント一覧をシートで表示する
/// （`OldMapAreaInfoSheet`）。「全ての古地図を表示」中や、古地図を表示していない間は出さない。
private struct MapTopCenterOverlayLabel: View {
    @EnvironmentObject private var mapSession: MapSessionState
    @State private var isPresentingAreaInfo = false

    var body: some View {
        if let overlay = mapSession.selectedOverlay, !mapSession.isShowingAllOverlays {
            Button {
                isPresentingAreaInfo = true
            } label: {
                Text(overlay.shortTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
            .padding(.top, 8)
            .sheet(isPresented: $isPresentingAreaInfo) {
                OldMapAreaInfoSheet(
                    overlay: overlay,
                    checkpoints: HistoricSiteCatalog.sites(forOverlayID: overlay.id)
                )
            }
        }
    }
}

private extension Image {
    /// 地図の上に浮かせるボタンの共通の見た目（丸背景つきのアイコン）。
    func roundControlButtonStyle() -> some View {
        self
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

#Preview {
    RootView()
}
