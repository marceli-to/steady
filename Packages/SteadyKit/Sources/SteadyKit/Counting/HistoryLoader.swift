import Foundation

public enum WorkoutIntervals {
    /// Sorts, clips to `range` and merges overlapping or touching intervals,
    /// so nothing inside two overlapping workouts gets subtracted twice.
    public static func normalized(_ intervals: [DateInterval], clippedTo range: DateInterval? = nil) -> [DateInterval] {
        var clipped: [DateInterval] = []
        for interval in intervals {
            if let range {
                guard let part = interval.intersection(with: range), part.duration > 0 else { continue }
                clipped.append(part)
            } else if interval.duration > 0 {
                clipped.append(interval)
            }
        }
        clipped.sort { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in clipped {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}

/// Reads a range of days from a `HealthDataSource` and splits each day into everyday movement
/// and movement inside workouts.
public struct HistoryLoader: Sendable {
    public let source: any HealthDataSource
    public let calendar: Calendar

    public init(source: any HealthDataSource, calendar: Calendar = .current) {
        self.source = source
        self.calendar = calendar
    }

    public func loadDays(in range: DateInterval) async throws -> [DayTotals] {
        let workouts = WorkoutIntervals.normalized(try await source.workoutIntervals(in: range), clippedTo: range)

        async let distance = source.dailyTotals(.walkingDistance, in: range, restrictedTo: nil, calendar: calendar)
        async let flights = source.dailyTotals(.flightsClimbed, in: range, restrictedTo: nil, calendar: calendar)
        async let steps = source.dailyTotals(.steps, in: range, restrictedTo: nil, calendar: calendar)
        async let distanceInWorkouts = workouts.isEmpty ? [:] :
            source.dailyTotals(.walkingDistance, in: range, restrictedTo: workouts, calendar: calendar)
        async let flightsInWorkouts = workouts.isEmpty ? [:] :
            source.dailyTotals(.flightsClimbed, in: range, restrictedTo: workouts, calendar: calendar)

        let (d, f, s, dw, fw) = try await (distance, flights, steps, distanceInWorkouts, flightsInWorkouts)

        let allDays = Set(d.keys).union(f.keys).union(s.keys)
        return allDays.sorted().map { day in
            let dist = d[day] ?? 0
            let fl = f[day] ?? 0
            return DayTotals(
                day: day,
                distance: dist,
                distanceInWorkouts: min(dw[day] ?? 0, dist),
                flights: fl,
                flightsInWorkouts: min(fw[day] ?? 0, fl),
                steps: s[day] ?? 0
            )
        }
    }

    /// Splits `range` into calendar-year chunks so a long first sync can report progress.
    public func yearlyChunks(of range: DateInterval) -> [DateInterval] {
        var chunks: [DateInterval] = []
        var start = range.start
        while start < range.end {
            let year = calendar.component(.year, from: start)
            let nextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? range.end
            let end = min(nextYear, range.end)
            chunks.append(DateInterval(start: start, end: end))
            start = end
        }
        return chunks
    }
}
