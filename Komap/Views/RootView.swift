import SwiftUI

struct RootView: View {
    @StateObject private var authService = AuthService()

    var body: some View {
        Group {
            if SecretsConfig.isGoogleMapsAPIKeyConfigured {
                MainTabView()
            } else {
                GoogleMapsSetupNoticeView()
            }
        }
        .environmentObject(authService)
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

private struct MainTabView: View {
    var body: some View {
        TabView {
            MapScreen()
                .tabItem {
                    Label("マップ", systemImage: "map")
                }

            SavedPlacesListView()
                .tabItem {
                    Label("わたしの時間旅行", systemImage: "book.closed")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    RootView()
}
