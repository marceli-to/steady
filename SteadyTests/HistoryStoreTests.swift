import Foundation
import SwiftData
import Testing
@testable import Steady
import SteadyKit

@MainActor
@Suite("History store")
struct HistoryStoreTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func makeStore(_ source: some HealthDataSource) throws -> HistoryStore {
        let container = try ModelContainer(for: DayRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return HistoryStore(container: container, loader: HistoryLoader(source: source, calendar: calendar))
    }

    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func firstSyncReadsEverythingYearByYear() async throws {
        let now = day(2026, 11, 16, 12)
        let store = try makeStore(MockHistory.make(endingAt: now, years: 3, calendar: calendar))
        var years: [Int] = []

        let days = try await store.sync(now: now) { _, year in years.append(year) }

        #expect(days.count > 900)
        #expect(Set(years).count >= 4)                  // 2023…2026, one chunk per calendar year
        #expect(try store.cachedDays() == days)
    }

    @Test func laterSyncOnlyRereadsRecentDaysAndPicksUpLateData() async throws {
        let sample = MockSample(.walkingDistance, start: day(2026, 11, 10, 9), end: day(2026, 11, 10, 10), value: 1_000)
        let early = MockHealthDataSource(samples: [sample], workouts: [])
        let store = try makeStore(early)
        try await store.sync(now: day(2026, 11, 12))

        // The watch syncs late: an extra sample for the 10th, plus a new day.
        let late = MockHealthDataSource(samples: [
            sample,
            MockSample(.walkingDistance, start: day(2026, 11, 10, 18), end: day(2026, 11, 10, 19), value: 500),
            MockSample(.walkingDistance, start: day(2026, 11, 13, 9), end: day(2026, 11, 13, 10), value: 2_000),
        ], workouts: [])
        let store2 = HistoryStore(container: store.container, loader: HistoryLoader(source: late, calendar: calendar))
        let days = try await store2.sync(now: day(2026, 11, 14))

        #expect(days.map(\.distance) == [1_500, 2_000])
    }

    @Test func noHistoryMeansNoDays() async throws {
        let store = try makeStore(MockHealthDataSource(samples: [], workouts: []))
        #expect(try await store.sync().isEmpty)
    }
}
