import Foundation

/// Totals over a set of days.
public struct MovementSummary: Sendable, Hashable {
    public var distance: Double     // metres
    public var elevation: Double    // metres
    public var steps: Double
    public var firstDay: Date?
    public var lastDay: Date?
    public var daysWithData: Int

    public static let empty = MovementSummary(distance: 0, elevation: 0, steps: 0, firstDay: nil, lastDay: nil, daysWithData: 0)

    public init(distance: Double, elevation: Double, steps: Double, firstDay: Date?, lastDay: Date?, daysWithData: Int) {
        self.distance = distance
        self.elevation = elevation
        self.steps = steps
        self.firstDay = firstDay
        self.lastDay = lastDay
        self.daysWithData = daysWithData
    }

    public init<S: Sequence>(days: S, includingWorkouts: Bool) where S.Element == DayTotals {
        var summary = MovementSummary.empty
        for day in days where day.hasData {
            summary.distance += day.distance(includingWorkouts: includingWorkouts)
            summary.elevation += day.elevation(includingWorkouts: includingWorkouts)
            summary.steps += day.steps
            summary.daysWithData += 1
            if summary.firstDay.map({ day.day < $0 }) ?? true { summary.firstDay = day.day }
            if summary.lastDay.map({ day.day > $0 }) ?? true { summary.lastDay = day.day }
        }
        self = summary
    }

    /// All days in the calendar year containing `date`.
    public static func year(containing date: Date, days: [DayTotals], includingWorkouts: Bool,
                            calendar: Calendar = .current) -> MovementSummary {
        let year = calendar.component(.year, from: date)
        return MovementSummary(
            days: days.lazy.filter { calendar.component(.year, from: $0.day) == year },
            includingWorkouts: includingWorkouts
        )
    }
}
