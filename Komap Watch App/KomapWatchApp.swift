import HealthKit
import SwiftUI
import WatchKit

@main
struct KomapWatchApp: App {
    @WKApplicationDelegateAdaptor(KomapWatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// 記録中にWatchアプリが落ちると、watchOSはワークアウトを続けたままアプリを起動し直し、
/// `handleActiveWorkoutRecovery()`を呼ぶ。軌跡はメモリ上にしか無く引き継げないため、
/// 残ったワークアウトをここで終わらせ、誰も止めないワークアウトとGPSが電池を
/// 減らし続けないようにする（ヘルスケアには、それまでのワークアウトとして保存される）。
final class KomapWatchAppDelegate: NSObject, WKApplicationDelegate {
    private let healthStore = HKHealthStore()

    func handleActiveWorkoutRecovery() {
        healthStore.recoverActiveWorkoutSession { session, _ in
            guard let session else { return }
            let builder = session.associatedWorkoutBuilder()
            session.end()
            builder.endCollection(withEnd: Date()) { _, _ in
                builder.finishWorkout { _, _ in }
            }
        }
    }
}
