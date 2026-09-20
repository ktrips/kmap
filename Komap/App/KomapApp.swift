import FirebaseCore
import GoogleMaps
import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct KomapApp: App {
    init() {
        if let apiKey = SecretsConfig.googleMapsAPIKey, SecretsConfig.isGoogleMapsAPIKeyConfigured {
            GMSServices.provideAPIKey(apiKey)
        }

        // GoogleService-Info.plist が未配置の場合は `FirebaseApp.configure()` が
        // クラッシュしてしまうため、存在チェックしてから初期化する。
        // これにより、Firebase未セットアップの状態でもアプリ自体は起動できる
        // （その場合はクラウド同期・Googleサインインのみ利用不可）。
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }

        // 以前の版で巨大なまま保存された写真を、一度だけバックグラウンドで縮小し直す。
        Task.detached(priority: .utility) {
            StampPhotoStore.migrateOversizedPhotosIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Googleサインインの認証結果はこのURLスキーム経由でアプリに戻ってくる。
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(for: [SavedPlace.self, WalkRoute.self, CollectedStamp.self, WalkPhotoPost.self, CheckpointStory.self])
    }
}
