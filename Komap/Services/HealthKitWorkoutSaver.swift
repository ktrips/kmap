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
            try await beginCollection(builder, start: startedAt)

            let distance = totalDistance(of: coordinates)
            if distance > 0 {
                let sample = HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: HKQuantity(unit: .meter(), doubleValue: distance),
                    start: startedAt,
                    end: endedAt
                )
                try await addSamples([sample], to: builder)
            }

            try await endCollection(builder, end: endedAt)
            guard let workout = try await finishWorkout(builder) else { return }

            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            let locations = timestampedLocations(from: coordinates, start: startedAt, end: endedAt)
            try await insertRouteData(locations, into: routeBuilder)
            try await finishRoute(routeBuilder, workout: workout)
        } catch {
            // 保存に失敗しても、アプリ内の記録（WalkRoute）自体には影響させない。
        }
    }

    private func beginCollection(_ builder: HKWorkoutBuilder, start: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: start) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func addSamples(_ samples: [HKSample], to builder: HKWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func endCollection(_ builder: HKWorkoutBuilder, end: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: end) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func finishWorkout(_ builder: HKWorkoutBuilder) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishWorkout { workout, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: workout) }
            }
        }
    }

    private func insertRouteData(_ locations: [CLLocation], into routeBuilder: HKWorkoutRouteBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            routeBuilder.insertRouteData(locations) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func finishRoute(_ routeBuilder: HKWorkoutRouteBuilder, workout: HKWorkout) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            routeBuilder.finishRoute(with: workout, metadata: nil) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
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
