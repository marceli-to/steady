import Foundation

/// A sample like HealthKit's: a value spread evenly over a time range.
public struct MockSample: Sendable, Hashable {
    public var metric: HealthMetric
    public var start: Date
    public var end: Date
    public var value: Double

    public init(_ metric: HealthMetric, start: Date, end: Date, value: Double) {
        self.metric = metric
        self.start = start
        self.end = end
        self.value = value
    }
}

/// In-memory Health. Queries prorate samples by time, like HealthKit's statistics queries do.
public struct MockHealthDataSource: HealthDataSource {
    private let samples: [HealthMetric: [MockSample]]   // sorted by start
    private let workouts: [DateInterval]
    /// Simulated delay per query, so the reveal's loading state can be seen in the simulator.
    public var latency: Duration = .zero

    public init(samples: [MockSample], workouts: [DateInterval]) {
        self.samples = Dictionary(grouping: samples, by: \.metric).mapValues { $0.sorted { $0.start < $1.start } }
        self.workouts = workouts.sorted { $0.start < $1.start }
    }

    public func requestAuthorization() async throws {}

    public func firstSampleDate() async throws -> Date? {
        [samples[.walkingDistance]?.first?.start, samples[.steps]?.first?.start].compactMap { $0 }.min()
    }

    public func workoutIntervals(in range: DateInterval) async throws -> [DateInterval] {
        try await pause()
        return workouts.filter { $0.intersects(range) && $0.end > range.start && $0.start < range.end }
    }

    public func dailyTotals(_ metric: HealthMetric, in range: DateInterval,
                            restrictedTo intervals: [DateInterval]?, calendar: Calendar) async throws -> [Date: Double] {
        try await pause()
        let list = samples[metric] ?? []
        let windows = intervals.map { WorkoutIntervals.normalized($0, clippedTo: range) } ?? [range]
        var result: [Date: Double] = [:]
        guard !windows.isEmpty else { return result }

        // Samples are sorted by start; anything starting at or after range.end is irrelevant.
        let upper = list.partitioningIndex { $0.start >= range.end }
        for sample in list[..<upper] {
            let span = sample.end.timeIntervalSince(sample.start)
            if span <= 0 {
                // Instantaneous sample: counts fully if it sits inside a window.
                if windows.contains(where: { $0.start <= sample.start && sample.start < $0.end }) {
                    result[calendar.startOfDay(for: sample.start), default: 0] += sample.value
                }
                continue
            }
            guard sample.end > range.start else { continue }
            let sampleInterval = DateInterval(start: sample.start, end: sample.end)
            var i = windows.partitioningIndex { $0.end > sample.start }
            while i < windows.count, windows[i].start < sample.end {
                if let overlap = windows[i].intersection(with: sampleInterval), overlap.duration > 0 {
                    // Split the overlap at midnights so each day gets its share.
                    var cursor = overlap.start
                    while cursor < overlap.end {
                        let dayStart = calendar.startOfDay(for: cursor)
                        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? overlap.end
                        let pieceEnd = min(nextDay, overlap.end)
                        let share = pieceEnd.timeIntervalSince(cursor) / span
                        result[dayStart, default: 0] += sample.value * share
                        cursor = pieceEnd
                    }
                }
                i += 1
            }
        }
        return result
    }

    private func pause() async throws {
        if latency > .zero { try await Task.sleep(for: latency) }
    }
}

extension RandomAccessCollection {
    /// First index where `predicate` is true, assuming the collection is partitioned (false…, true…).
    func partitioningIndex(where predicate: (Element) -> Bool) -> Index {
        var low = startIndex
        var count = self.count
        while count > 0 {
            let half = count / 2
            let mid = index(low, offsetBy: half)
            if predicate(self[mid]) {
                count = half
            } else {
                low = index(after: mid)
                count -= half + 1
            }
        }
        return low
    }
}
