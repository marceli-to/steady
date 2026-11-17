import Foundation

/// One calendar month's totals.
public struct MonthTotal: Sendable, Hashable, Identifiable {
    /// 1…12
    public var month: Int
    public var distance: Double     // metres
    public var elevation: Double    // metres
    public var daysWithData: Int

    public var id: Int { month }
}

/// A year looked back on: totals, each month, and the best one.
public struct YearInReview: Sendable, Hashable {
    public var year: Int
    public var summary: MovementSummary
    /// Always twelve, January first. Months without data are zero.
    public var months: [MonthTotal]

    /// The month with the most distance. Ties go to the earlier month. Nil for an empty year.
    public var bestMonth: MonthTotal? {
        months.filter { $0.distance > 0 }.max { a, b in
            a.distance != b.distance ? a.distance < b.distance : a.month > b.month
        }
    }

    /// Days are grouped by `calendar`, the same calendar their start-of-day dates were made in,
    /// so a day that starts at midnight in Zürich (23:00 UTC the evening before) stays on its own date.
    public init(year: Int, days: [DayTotals], includingWorkouts: Bool, calendar: Calendar = .current) {
        self.year = year
        var months = (1...12).map { MonthTotal(month: $0, distance: 0, elevation: 0, daysWithData: 0) }
        var inYear: [DayTotals] = []
        for day in days where day.hasData {
            let parts = calendar.dateComponents([.year, .month], from: day.day)
            guard parts.year == year, let month = parts.month else { continue }
            inYear.append(day)
            months[month - 1].distance += day.distance(includingWorkouts: includingWorkouts)
            months[month - 1].elevation += day.elevation(includingWorkouts: includingWorkouts)
            months[month - 1].daysWithData += 1
        }
        self.months = months
        summary = MovementSummary(days: inYear, includingWorkouts: includingWorkouts)
    }
}

public enum LookBack {
    /// Years that can be looked back on, newest first: every past year with data, and the
    /// current one only in December, once there's most of a year to look at.
    public static func years(in days: [DayTotals], today: Date = .now, calendar: Calendar = .current) -> [Int] {
        let now = calendar.dateComponents([.year, .month], from: today)
        guard let thisYear = now.year else { return [] }
        let withData = Set(days.lazy.filter(\.hasData).map { calendar.component(.year, from: $0.day) })
        return withData
            .filter { $0 < thisYear || ($0 == thisYear && now.month == 12) }
            .sorted(by: >)
    }

    /// True in December, when this year's look back is new.
    public static func isSeason(today: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.component(.month, from: today) == 12
    }
}
