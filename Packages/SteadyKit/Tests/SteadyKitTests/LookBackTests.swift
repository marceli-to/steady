import Foundation
import Testing
@testable import SteadyKit

private let zurich: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    return c
}()

/// Start of a day in Zürich, as HistoryLoader stores it.
private func zurichDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
    zurich.date(from: DateComponents(year: y, month: m, day: d))!
}

private func walk(_ day: Date, _ metres: Double, workouts: Double = 0, flights: Double = 0) -> DayTotals {
    DayTotals(day: day, distance: metres + workouts, distanceInWorkouts: workouts, flights: flights)
}

@Suite("Look back")
struct LookBackTests {
    @Test func totalsMonthsAndBestMonth() {
        let days = [
            walk(date(2025, 1, 10), 3_000),
            walk(date(2025, 5, 2), 8_000, flights: 10),
            walk(date(2025, 5, 3), 7_000),
            walk(date(2025, 9, 9), 9_000, workouts: 20_000),
            walk(date(2024, 5, 1), 50_000),            // other year
            DayTotals(day: date(2025, 6, 1)),          // no data
        ]

        let review = YearInReview(year: 2025, days: days, includingWorkouts: false, calendar: utc)

        #expect(review.summary.distance == 27_000)
        #expect(review.summary.elevation == 30)
        #expect(review.summary.daysWithData == 4)
        #expect(review.months.count == 12)
        #expect(review.months[4].distance == 15_000)
        #expect(review.months[4].daysWithData == 2)
        #expect(review.months[5].daysWithData == 0)
        #expect(review.bestMonth?.month == 5)

        // Counting workouts, September's run wins.
        let withWorkouts = YearInReview(year: 2025, days: days, includingWorkouts: true, calendar: utc)
        #expect(withWorkouts.bestMonth?.month == 9)
    }

    @Test func tiesGoToTheEarlierMonthAndEmptyYearsHaveNone() {
        let days = [walk(date(2025, 3, 1), 5_000), walk(date(2025, 7, 1), 5_000)]
        #expect(YearInReview(year: 2025, days: days, includingWorkouts: false, calendar: utc).bestMonth?.month == 3)
        #expect(YearInReview(year: 2023, days: days, includingWorkouts: false, calendar: utc).bestMonth == nil)
    }

    @Test func yearBoundariesFollowTheLocalCalendar() {
        // Midnight on 1 January in Zürich is 23:00 UTC on 31 December.
        let newYear = zurichDay(2025, 1, 1)
        #expect(utc.component(.year, from: newYear) == 2024)
        let days = [walk(zurichDay(2024, 12, 31), 4_000), walk(newYear, 6_000)]

        let review2025 = YearInReview(year: 2025, days: days, includingWorkouts: false, calendar: zurich)
        let review2024 = YearInReview(year: 2024, days: days, includingWorkouts: false, calendar: zurich)

        #expect(review2025.summary.distance == 6_000)
        #expect(review2025.months[0].distance == 6_000)
        #expect(review2024.summary.distance == 4_000)
        #expect(review2024.months[11].distance == 4_000)
    }

    @Test func daylightSavingDaysStayInTheirMonth() {
        // 30 March 2025 has 23 hours in Zürich, 26 October has 25. Neither day nor its
        // neighbours may slip into another month.
        let days = [
            walk(zurichDay(2025, 3, 30), 1_000), walk(zurichDay(2025, 3, 31), 2_000), walk(zurichDay(2025, 4, 1), 4_000),
            walk(zurichDay(2025, 10, 26), 8_000), walk(zurichDay(2025, 10, 31), 16_000), walk(zurichDay(2025, 11, 1), 32_000),
        ]
        let review = YearInReview(year: 2025, days: days, includingWorkouts: false, calendar: zurich)

        #expect(review.months[2].distance == 3_000)
        #expect(review.months[3].distance == 4_000)
        #expect(review.months[9].distance == 24_000)
        #expect(review.months[10].distance == 32_000)
    }

    @Test func thisYearOnlyInDecember() {
        let days = [walk(date(2023, 6, 1), 1_000), walk(date(2025, 6, 1), 1_000), walk(date(2026, 2, 1), 1_000)]

        #expect(LookBack.years(in: days, today: date(2026, 11, 30), calendar: utc) == [2025, 2023])
        #expect(LookBack.years(in: days, today: date(2026, 12, 1), calendar: utc) == [2026, 2025, 2023])
        #expect(LookBack.isSeason(today: date(2026, 12, 1), calendar: utc))
        #expect(!LookBack.isSeason(today: date(2027, 1, 1), calendar: utc))
    }
}
