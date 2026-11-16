import Foundation
import HealthKit
import SteadyKit

/// Reads from Health. Read-only: steady never writes anything.
///
/// Totals come from statistics collection queries, which deduplicate overlapping samples from
/// iPhone and Apple Watch. Summing raw samples would count a walk twice.
final class HealthKitDataSource: HealthDataSource, @unchecked Sendable {
    // HKHealthStore is documented as thread-safe; the class holds no other state.
    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.flightsClimbed),
        HKObjectType.workoutType(),
    ]

    /// Workout intervals per OR-predicate. Keeps predicates a reasonable size.
    private let intervalsPerQuery = 64

    func requestAuthorization() async throws {
        guard Self.isAvailable else { throw HealthDataError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func firstSampleDate() async throws -> Date? {
        var earliest: Date?
        for type in [HKQuantityType(.distanceWalkingRunning), HKQuantityType(.stepCount)] {
            let query = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: type)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
                limit: 1
            )
            if let date = try await query.result(for: store).first?.startDate {
                earliest = min(earliest ?? date, date)
            }
        }
        return earliest
    }

    func workoutIntervals(in range: DateInterval) async throws -> [DateInterval] {
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: [])
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await query.result(for: store)
            .filter { $0.endDate > $0.startDate }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
    }

    func dailyTotals(_ metric: HealthMetric, in range: DateInterval,
                     restrictedTo intervals: [DateInterval]?, calendar: Calendar) async throws -> [Date: Double] {
        let rangePredicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: [])

        guard let intervals else {
            return try await collect(metric, predicate: rangePredicate, range: range, calendar: calendar)
        }

        // Intervals are merged and non-overlapping, so per-group sums simply add up.
        var result: [Date: Double] = [:]
        for group in intervals.chunked(into: intervalsPerQuery) {
            let within = NSCompoundPredicate(orPredicateWithSubpredicates: group.map {
                HKQuery.predicateForSamples(withStart: $0.start, end: $0.end, options: [])
            })
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [rangePredicate, within])
            let groupRange = DateInterval(start: group.first!.start, end: group.last!.end)
            for (day, value) in try await collect(metric, predicate: predicate, range: groupRange, calendar: calendar) {
                result[day, default: 0] += value
            }
        }
        return result
    }

    /// Wakes the app (at most hourly) when new steps are saved, so widgets stay current
    /// without the app being opened. `onChange` must finish before HealthKit is told we're done.
    func observeNewSteps(_ onChange: @escaping @Sendable () async -> Void) {
        let type = HKQuantityType(.stepCount)
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            // HealthKit's completion handler is safe to call from any thread.
            nonisolated(unsafe) let done = completion
            Task {
                await onChange()
                done()
            }
        }
        store.execute(query)
        store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }

    private func collect(_ metric: HealthMetric, predicate: NSPredicate, range: DateInterval,
                         calendar: Calendar) async throws -> [Date: Double] {
        let anchor = calendar.startOfDay(for: range.start)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: metric.quantityType, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await query.result(for: store)
        var result: [Date: Double] = [:]
        collection.enumerateStatistics(from: anchor, to: range.end) { statistics, _ in
            if let sum = statistics.sumQuantity()?.doubleValue(for: metric.unit), sum > 0 {
                result[calendar.startOfDay(for: statistics.startDate), default: 0] += sum
            }
        }
        return result
    }
}

private extension HealthMetric {
    var quantityType: HKQuantityType {
        switch self {
        case .walkingDistance: HKQuantityType(.distanceWalkingRunning)
        case .steps: HKQuantityType(.stepCount)
        case .flightsClimbed: HKQuantityType(.flightsClimbed)
        }
    }

    var unit: HKUnit {
        switch self {
        case .walkingDistance: .meter()
        case .steps, .flightsClimbed: .count()
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: size).map { self[$0..<Swift.min($0 + size, count)] }
    }
}
