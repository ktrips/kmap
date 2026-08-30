import CoreMotion
import Foundation

/// 徒歩ルート記録中の歩数を`CMPedometer`で計測する。
///
/// モーション使用の権限が無い・端末が対応していない場合は`nil`を返し、
/// 呼び出し側は「歩数は記録できなかった」として扱う。
final class StepCounter {
    private let pedometer = CMPedometer()
    private var startDate: Date?

    static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    /// 記録開始時に呼び出す。
    func start() {
        guard Self.isAvailable else { return }
        startDate = Date()
    }

    /// 記録終了時に呼び出し、開始〜終了までの歩数を取得する。
    func finish() async -> Int? {
        guard Self.isAvailable, let startDate else { return nil }
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: startDate, to: Date()) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue)
            }
        }
    }
}
