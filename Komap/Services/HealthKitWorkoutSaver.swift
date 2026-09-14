import CoreLocation
import Foundation
import HealthKit

/// 記録し終えた徒歩ルートを、Apple Healthに「屋外ウォーキング」ワークアウトとして保存する。
///
/// Apple Watchが伴走している間は、Watch側（`WatchWorkoutLocationTracker`）が
/// 自分自身の`HKWorkoutSession`で既にワークアウトを保存するため、二重に記録されないよう
/// 呼び出し側（`MapScreen`）はWatchの伴走が無かった時だけこのクラスを使う。
/// ライブの`HKWorkoutSession`は使わず、記録が終わった後にまとめて`HKWorkoutBuilder`へ
/// データを追加する形で保存するため、iPhone単体でも完結できる。
final class HealthKitWorkoutSaver {
    private let healthStore = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 起動時・記録開始時などに一度呼んでおく。ユーザーが許可しなくても、
    /// `saveWalk`は静かに失敗するだけなので、呼び出し側は特に分岐しなくてよい。
    func requestAuthorizationIfNeeded() async {
        guard Self.isAvailable else { return }
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType(.distanceWalkingRunning),
        ]
        try? await healthStore.requestAuthorization(toShare: typesToShare, read: [])
    }

    /// 記録し終えた軌跡を、屋外ウォーキングのワークアウトとしてヘルスケアに保存する。
    /// 座標に個別のタイムスタンプが無いため、開始〜終了の間に均等割りした時刻を補って
    /// ルートデータとする（Fitness/ヘルスケアアプリの地図表示用の近似で、厳密な速度分析等には使わない）。
    func saveWalk(coordinates: [CLLocationCoordinate2D], startedAt: Date, endedAt: Date) async {
        guard Self.isAvailable, coordinates.count >= 2, endedAt > startedAt else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(withStart: startedAt)

            let distance = totalDistance(of: coordinates)
            if distance > 0 {
                let sample = HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: HKQuantity(unit: .meter(), doubleValue: distance),
                    start: startedAt,
                    end: endedAt
                )
                try await builder.addSamples([sample])
            }

            try await builder.endCollection(withEnd: endedAt)
            guard let workout = try await builder.finishWorkout() else { return }

            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            let locations = timestampedLocations(from: coordinates, start: startedAt, end: endedAt)
            try await routeBuilder.insertRouteData(locations)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        } catch {
            // 保存に失敗しても、アプリ内の記録（WalkRoute）自体には影響させない。
        }
    }

    private func totalDistance(of coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        var total: Double = 0
        for index in 1..<coordinates.count {
            let previous = CLLocation(latitude: coordinates[index - 1].latitude, longitude: coordinates[index - 1].longitude)
            let current = CLLocation(latitude: coordinates[index].latitude, longitude: coordinates[index].longitude)
            total += previous.distance(from: current)
        }
        return total
    }

    private func timestampedLocations(
        from coordinates: [CLLocationCoordinate2D],
        start: Date,
        end: Date
    ) -> [CLLocation] {
        guard coordinates.count > 1 else {
            return coordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        }
        let interval = end.timeIntervalSince(start) / Double(coordinates.count - 1)
        return coordinates.enumerated().map { index, coordinate in
            CLLocation(
                coordinate: coordinate,
                altitude: 0,
                horizontalAccuracy: kCLLocationAccuracyNearestTenMeters,
                verticalAccuracy: -1,
                timestamp: start.addingTimeInterval(interval * Double(index))
            )
        }
    }
}
