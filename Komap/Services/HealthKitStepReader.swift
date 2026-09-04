import Foundation
import HealthKit

/// Apple Healthから歩数を読み取る。iPhone単体の`CMPedometer`（`StepCounter`）と違い、
/// Apple Healthの歩数は「歩数」カテゴリにApple Watch・iPhone双方のセンサー値が
/// まとめて記録されるため、Apple Watchと連携して歩いた記録では、こちらの方が
/// より実態に近い歩数になる。
final class HealthKitStepReader {
    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 起動時・記録開始時などに一度呼んでおく。ユーザーが許可しなくても、
    /// 呼び出し側は`stepCount(from:to:)`が`nil`を返すだけなので、
    /// 従来の`StepCounter`にフォールバックできる。
    func requestAuthorizationIfNeeded() async {
        guard Self.isAvailable else { return }
        try? await healthStore.requestAuthorization(toShare: [], read: [stepType])
    }

    /// 指定した期間の歩数の合計を取得する。ヘルスケアへのアクセス権がない・
    /// データが無い場合は`nil`を返す。
    func stepCount(from start: Date, to end: Date) async -> Int? {
        guard Self.isAvailable else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps.map { Int($0.rounded()) })
            }
            healthStore.execute(query)
        }
    }
}
