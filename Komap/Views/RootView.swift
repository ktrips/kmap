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
/// マップ・My Trips・設定を切り替える。マップは全画面表示にし、
/// 左上に浮かせたハンバーガーメニュー（古地図選択・マイ時空旅・セットアップ）から他画面へ移動する。
private struct MainTabView: View {
    @EnvironmentObject private var mapSession: MapSessionState

    var body: some View {
        switch mapSession.selectedTab {
        case .map:
            ZStack(alignment: .topLeading) {
                MapScreen()
                MapTopLeftControls()
            }
        case .myTimeTrip:
            MyTimeTripView()
        case .settings:
            SettingsView()
        }
    }
}

/// マップ画面の左上に浮かせる、ハンバーガーメニュー（Komapアイコン表示）。
/// 「古地図選択」（submenuで古地図を選ぶとその範囲でマップが表示される）・
/// 「マイ時空旅」・「セットアップ」の3項目をまとめる。
private struct MapTopLeftControls: View {
    @EnvironmentObject private var mapSession: MapSessionState
    @State private var isPresentingOldMapPicker = false

    var body: some View {
        Menu {
            // アプリ名の行をタップすると、古地図オーバーレイを外した「元のマップ」表示に
            // 戻る（迷子になった時のホームボタンのような役割）。
            Button {
                mapSession.resetToOriginalMap()
            } label: {
                Label {
                    Text("Komap 古地図巡り")
                } icon: {
                    Image("KomapIcon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            Divider()
            // 「古地図選択」はここでsubmenu（Menu内Menu）にせず、シートを開くボタンにする。
            // 同梱の古地図が増えた結果、submenuに入り切らない項目がスクロールもできないまま
            // 表示されなくなる問題があったため（`OldMapPickerSheet`のコメント参照）。
            Button {
                isPresentingOldMapPicker = true
            } label: {
                // Menu項目はカスタムレイアウトが効かず単純なテキスト+アイコンしか
                // 描画されないため、「その場で開いて選ぶ」ことが分かるよう
                // タイトル末尾に下矢印（⌄）を付ける。
                Label("古地図選択  ⌄", systemImage: "map")
            }
            Divider()
            Button {
                mapSession.selectedTab = .myTimeTrip
            } label: {
                // 同様に、新しい画面へ遷移することが分かるよう末尾に右矢印（›）を付ける。
                Label("マイ時空旅  ›", systemImage: "book.closed")
            }
            Divider()
            Button {
                mapSession.selectedTab = .settings
            } label: {
                Label("セットアップ  ›", systemImage: "gearshape")
            }
            Divider()
            Link(destination: URL(string: "https://github.com/ktrips/kmap#readme")!) {
                Label("Komapの使い方", systemImage: "book")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .roundControlButtonStyle()
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
