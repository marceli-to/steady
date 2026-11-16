import Foundation

/// Everything steady needs from Health. The HealthKit implementation lives in the app target;
/// `MockHealthDataSource` backs previews, tests and the simulator.
public protocol HealthDataSource: Sendable {
    /// Ask for read access. Health never tells apps whether read access was granted,
    /// so callers learn about a refusal only through missing data.
    func requestAuthorization() async throws

    /// Earliest walking-distance or step sample, or nil when there is nothing to read.
    func firstSampleDate() async throws -> Date?

    /// Totals per calendar day (keys are start of day in `calendar`), deduplicated across devices.
    /// When `intervals` is given, only the part of each sample that falls inside those
    /// intervals is counted (prorated by time). Intervals must not overlap.
    func dailyTotals(
        _ metric: HealthMetric,
        in range: DateInterval,
        restrictedTo intervals: [DateInterval]?,
        calendar: Calendar
    ) async throws -> [Date: Double]

    /// Time ranges of recorded workouts that overlap `range`.
    func workoutIntervals(in range: DateInterval) async throws -> [DateInterval]
}

public enum HealthDataError: Error, Sendable {
    case notAvailable
}
