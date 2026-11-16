import Foundation
import Testing
@testable import SteadyKit

/// Fixed calendar so tests don't depend on the machine's time zone.
let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

func hourly(_ metric: HealthMetric, _ y: Int, _ m: Int, _ d: Int, hour: Int, value: Double) -> MockSample {
    MockSample(metric, start: date(y, m, d, hour), end: date(y, m, d, hour + 1), value: value)
}

func load(_ source: MockHealthDataSource, from: Date = date(2024, 1, 1), to: Date = date(2024, 2, 1)) async throws -> [DayTotals] {
    try await HistoryLoader(source: source, calendar: utc).loadDays(in: DateInterval(start: from, end: to))
}

@Suite("Counting")
struct CountingTests {
    @Test func sumsSamplesPerDay() async throws {
        let source = MockHealthDataSource(samples: [
            hourly(.walkingDistance, 2024, 1, 10, hour: 8, value: 1_000),
            hourly(.walkingDistance, 2024, 1, 10, hour: 17, value: 2_500),
            hourly(.walkingDistance, 2024, 1, 11, hour: 9, value: 400),
            hourly(.steps, 2024, 1, 10, hour: 8, value: 1_300),
            hourly(.flightsClimbed, 2024, 1, 11, hour: 9, value: 4),
        ], workouts: [])

        let days = try await load(source)

        #expect(days.count == 2)
        #expect(days[0].day == date(2024, 1, 10))
        #expect(days[0].distance == 3_500)
        #expect(days[0].steps == 1_300)
        #expect(days[1].distance == 400)
        #expect(days[1].elevation(includingWorkouts: true) == 12)
    }

    @Test func sampleAcrossMidnightIsSplitByTime() async throws {
        let source = MockHealthDataSource(samples: [
            MockSample(.walkingDistance, start: date(2024, 1, 10, 23), end: date(2024, 1, 11, 1), value: 2_000),
        ], workouts: [])

        let days = try await load(source)

        #expect(days.map(\.distance) == [1_000, 1_000])
    }

    @Test func excludesDistanceInsideWorkout() async throws {
        let source = MockHealthDataSource(samples: [
            hourly(.walkingDistance, 2024, 1, 10, hour: 8, value: 1_000),
            MockSample(.walkingDistance, start: date(2024, 1, 10, 18), end: date(2024, 1, 10, 18, 45), value: 8_000),
            MockSample(.flightsClimbed, start: date(2024, 1, 10, 18), end: date(2024, 1, 10, 18, 45), value: 5),
            hourly(.flightsClimbed, 2024, 1, 10, hour: 8, value: 3),
        ], workouts: [DateInterval(start: date(2024, 1, 10, 18), end: date(2024, 1, 10, 18, 45))])

        let day = try #require(try await load(source).first)

        #expect(day.distance == 9_000)
        #expect(day.distanceInWorkouts == 8_000)
        #expect(day.distance(includingWorkouts: false) == 1_000)
        #expect(day.distance(includingWorkouts: true) == 9_000)
        #expect(day.flights(includingWorkouts: false) == 3)
    }

    @Test func partialOverlapIsProrated() async throws {
        // Workout covers the second half of an hourly sample.
        let source = MockHealthDataSource(samples: [
            hourly(.walkingDistance, 2024, 1, 10, hour: 8, value: 1_000),
        ], workouts: [DateInterval(start: date(2024, 1, 10, 8, 30), end: date(2024, 1, 10, 10))])

        let day = try #require(try await load(source).first)

        #expect(abs(day.distanceInWorkouts - 500) < 0.001)
        #expect(abs(day.distance(includingWorkouts: false) - 500) < 0.001)
    }

    @Test func workoutAcrossMidnightCountsOnBothDays() async throws {
        let workout = DateInterval(start: date(2024, 1, 10, 23), end: date(2024, 1, 11, 1))
        let source = MockHealthDataSource(samples: [
            MockSample(.walkingDistance, start: workout.start, end: workout.end, value: 6_000),
            hourly(.walkingDistance, 2024, 1, 10, hour: 12, value: 1_000),
            hourly(.walkingDistance, 2024, 1, 11, hour: 12, value: 2_000),
        ], workouts: [workout])

        let days = try await load(source)

        #expect(days.map(\.distanceInWorkouts) == [3_000, 3_000])
        #expect(days.map { $0.distance(includingWorkouts: false) } == [1_000, 2_000])
    }

    @Test func overlappingWorkoutsAreNotSubtractedTwice() async throws {
        // A watch and a phone app both recorded the same run, offset by 10 minutes.
        let source = MockHealthDataSource(samples: [
            MockSample(.walkingDistance, start: date(2024, 1, 10, 7), end: date(2024, 1, 10, 8), value: 10_000),
            hourly(.walkingDistance, 2024, 1, 10, hour: 12, value: 3_000),
        ], workouts: [
            DateInterval(start: date(2024, 1, 10, 7), end: date(2024, 1, 10, 7, 50)),
            DateInterval(start: date(2024, 1, 10, 7, 10), end: date(2024, 1, 10, 8)),
        ])

        let day = try #require(try await load(source).first)

        #expect(abs(day.distanceInWorkouts - 10_000) < 0.001)
        #expect(abs(day.distance(includingWorkouts: false) - 3_000) < 0.001)
    }

    @Test func mergesAndClipsIntervals() {
        let merged = WorkoutIntervals.normalized([
            DateInterval(start: date(2024, 1, 1, 10), end: date(2024, 1, 1, 11)),
            DateInterval(start: date(2024, 1, 1, 9), end: date(2024, 1, 1, 10)),   // touches
            DateInterval(start: date(2024, 1, 1, 14), end: date(2024, 1, 1, 15)),
            DateInterval(start: date(2023, 12, 31, 23), end: date(2024, 1, 1, 1)), // clipped
        ], clippedTo: DateInterval(start: date(2024, 1, 1), end: date(2024, 1, 2)))

        #expect(merged == [
            DateInterval(start: date(2024, 1, 1), end: date(2024, 1, 1, 1)),
            DateInterval(start: date(2024, 1, 1, 9), end: date(2024, 1, 1, 11)),
            DateInterval(start: date(2024, 1, 1, 14), end: date(2024, 1, 1, 15)),
        ])
    }

    @Test func workoutPartNeverExceedsDayTotal() {
        // HealthKit deduplicates the two queries independently; guard against rounding mismatches.
        let day = DayTotals(day: date(2024, 1, 1), distance: 5_000, distanceInWorkouts: 5_200,
                            flights: 2, flightsInWorkouts: 3)
        #expect(day.distance(includingWorkouts: false) == 0)
        #expect(day.flights(includingWorkouts: false) == 0)
    }

    @Test func summaryRespectsWorkoutSetting() {
        let days = [
            DayTotals(day: date(2023, 12, 31), distance: 4_000, distanceInWorkouts: 1_000, flights: 10, flightsInWorkouts: 2, steps: 5_000),
            DayTotals(day: date(2024, 1, 1), distance: 6_000, distanceInWorkouts: 0, flights: 5, steps: 8_000),
            DayTotals(day: date(2024, 1, 2)), // empty day is ignored
        ]

        let everyday = MovementSummary(days: days, includingWorkouts: false)
        let everything = MovementSummary(days: days, includingWorkouts: true)
        let thisYear = MovementSummary.year(containing: date(2024, 6, 1), days: days, includingWorkouts: false, calendar: utc)

        #expect(everyday.distance == 9_000)
        #expect(everyday.elevation == 39)
        #expect(everyday.firstDay == date(2023, 12, 31))
        #expect(everyday.daysWithData == 2)
        #expect(everything.distance == 10_000)
        #expect(everything.elevation == 45)
        #expect(thisYear.distance == 6_000)
    }

    @Test func yearlyChunksCoverRangeExactly() {
        let loader = HistoryLoader(source: MockHealthDataSource(samples: [], workouts: []), calendar: utc)
        let chunks = loader.yearlyChunks(of: DateInterval(start: date(2021, 6, 15), end: date(2023, 3, 1)))

        #expect(chunks.count == 3)
        #expect(chunks.first?.start == date(2021, 6, 15))
        #expect(chunks[1] == DateInterval(start: date(2022, 1, 1), end: date(2023, 1, 1)))
        #expect(chunks.last?.end == date(2023, 3, 1))
    }

    @Test func mockHistoryIsLongWithGapsAndWorkouts() async throws {
        let now = date(2026, 11, 16, 12)
        let source = MockHistory.make(endingAt: now, years: 6, calendar: utc)
        let first = try #require(try await source.firstSampleDate())
        let days = try await load(source, from: first, to: now)

        let years = now.timeIntervalSince(first) / (365.25 * 86_400)
        let calendarDays = utc.dateComponents([.day], from: first, to: now).day!
        let everyday = MovementSummary(days: days, includingWorkouts: false)
        let everything = MovementSummary(days: days, includingWorkouts: true)

        #expect(years >= 5)
        #expect(days.count < calendarDays - 35)              // forgotten days + the long gap
        #expect(everything.distance > everyday.distance * 1.1) // workouts are a real share
        #expect((4_000_000...30_000_000).contains(everyday.distance)) // 4,000–30,000 km
        // Same seed, same history.
        let again = try await load(MockHistory.make(endingAt: now, years: 6, calendar: utc), from: first, to: now)
        #expect(again == days)
    }
}
