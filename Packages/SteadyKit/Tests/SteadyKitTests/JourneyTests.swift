import Foundation
import Testing
@testable import SteadyKit

private let rome = Journey(
    id: "test-rome", title: "Zürich → Rome", destination: "Rome", metric: .distance, total: 900_000,
    milestones: [
        Milestone(id: "zurich", name: "Zürich", at: 0, lat: 0, lon: 0),
        Milestone(id: "gotthard", name: "Gotthard", at: 115_000, lat: 0, lon: 0),
        Milestone(id: "bellinzona", name: "Bellinzona", at: 205_000, lat: 0, lon: 0),
        Milestone(id: "milano", name: "Milano", at: 300_000, lat: 0, lon: 0),
        Milestone(id: "roma", name: "Roma", at: 900_000, lat: 0, lon: 0),
    ]
)

/// `metres` of everyday walking on each listed day of January 2024.
private func walks(_ perDay: [Int: Double], workouts: Double = 0) -> [DayTotals] {
    perDay.map { DayTotals(day: date(2024, 1, $0.key), distance: $0.value + workouts, distanceInWorkouts: workouts, flights: 0) }
}

@Suite("Journeys")
struct JourneyTests {
    let tracker = JourneyTracker(calendar: utc)

    @Test func bundledJourneysAreValid() {
        let ids = JourneyCatalog.bundled.map(\.id)
        #expect(ids == ["zurich-rome", "hadrians-wall", "camino-frances", "kilimanjaro", "everest"])
        for journey in JourneyCatalog.bundled {
            #expect(journey.validationProblems().isEmpty, "\(journey.id): \(journey.validationProblems())")
        }
        #expect(JourneyCatalog.journey(id: "everest")?.metric == .elevation)
        #expect(JourneyCatalog.journey(id: "zurich-rome")?.destination == "Rome")
    }

    @Test func validationCatchesBadData() {
        var bad = rome
        bad.milestones[2].at = 100_000                 // goes backwards
        bad.milestones.append(bad.milestones[1])       // duplicate id
        bad.milestones[0].lat = nil
        let problems = bad.validationProblems()
        #expect(problems.contains { $0.contains("must come after") })
        #expect(problems.contains("milestone ids must be unique"))
        #expect(problems.contains("last milestone must be at total"))
        #expect(problems.contains("distance milestones need coordinates"))
    }

    @Test func countsOnlyFromTheStartDay() {
        let days = walks([9: 50_000, 10: 10_000, 11: 20_000])
        let progress = tracker.progress(of: rome, startedOn: date(2024, 1, 10, 15), days: days, includingWorkouts: false)

        #expect(progress.done == 30_000)               // the whole start day counts, the day before doesn't
        #expect(progress.startedOn == date(2024, 1, 10))
    }

    @Test func milestonesGetTheDayTheyWereReached() {
        // Nothing opened the app in between: the dates still come from history.
        let days = walks([1: 60_000, 2: 60_000, 5: 100_000])
        let progress = tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days, includingWorkouts: false)

        #expect(progress.reached.map(\.milestone.id) == ["zurich", "gotthard", "bellinzona"])
        #expect(progress.reached.map(\.date) == [date(2024, 1, 1), date(2024, 1, 2), date(2024, 1, 5)])
        #expect(progress.reached.map(\.dayNumber) == [1, 2, 5])
        #expect(abs(progress.reached[2].fraction - 205.0 / 900) < 0.0001)
    }

    @Test func severalMilestonesInOneDayAndExactBoundary() {
        let days = walks([1: 205_000])                // lands exactly on Bellinzona
        let progress = tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days, includingWorkouts: false)

        #expect(progress.reached.map(\.milestone.id) == ["zurich", "gotthard", "bellinzona"])
        #expect(Set(progress.reached.dropFirst().map(\.date)) == [date(2024, 1, 1)])
        #expect(progress.whereabouts == .near(rome.milestones[2]))
    }

    @Test func workoutsFollowTheSetting() {
        let days = walks([1: 100_000], workouts: 20_000)
        #expect(tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days, includingWorkouts: false).done == 100_000)
        #expect(tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days, includingWorkouts: true).done == 120_000)
    }

    @Test func progressIsCappedAndFinishDateKept() {
        let days = walks([1: 500_000, 2: 500_000, 3: 50_000])
        let progress = tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days, includingWorkouts: false)

        #expect(progress.done == 900_000)
        #expect(progress.fraction == 1)
        #expect(progress.finishedOn == date(2024, 1, 2))
        #expect(progress.whereabouts.phrase == "arrived in Roma")
        #expect(progress.next == nil)
    }

    @Test func whereaboutsInWords() {
        #expect(tracker.whereabouts(in: rome, at: 0).phrase == "near Zürich")
        #expect(tracker.whereabouts(in: rome, at: 214_000).phrase == "near Bellinzona")     // 9 km past, segment 95 km
        #expect(tracker.whereabouts(in: rome, at: 296_000).phrase == "near Milano")         // 4 km before
        #expect(tracker.whereabouts(in: rome, at: 250_000).phrase == "between Bellinzona and Milano")
        #expect(tracker.whereabouts(in: rome, at: 250_000).shortPhrase == "past Bellinzona")
        #expect(tracker.whereabouts(in: rome, at: 214_000).shortPhrase == "near Bellinzona")
        let everest = JourneyCatalog.journey(id: "everest")!
        #expect(tracker.whereabouts(in: everest, at: 8_849).phrase == "reached Summit")
    }

    @Test func paceSkipsDaysWithoutData() {
        let estimator = ArrivalEstimator(calendar: utc)
        let today = date(2024, 1, 31)
        // 10 days of 5 km in the window, the rest missing; one old day outside the window.
        var days = (21...30).map { DayTotals(day: date(2024, 1, $0), distance: 5_000) }
        days.append(DayTotals(day: date(2023, 11, 1), distance: 90_000))

        #expect(estimator.dailyPace(for: .distance, days: days, includingWorkouts: false, today: today) == 5_000)
        #expect(estimator.dailyPace(for: .distance, days: Array(days.prefix(3)), includingWorkouts: false, today: today) == nil)
    }

    @Test func arrivalDates() {
        let estimator = ArrivalEstimator(calendar: utc)
        let today = date(2024, 1, 10, 18)

        #expect(estimator.arrival(remaining: 50_000, pace: 5_000, today: today) == date(2024, 1, 20))
        #expect(estimator.arrival(remaining: 50_001, pace: 5_000, today: today) == date(2024, 1, 21))
        #expect(estimator.arrival(remaining: 0, pace: nil, today: today) == date(2024, 1, 10))
        #expect(estimator.arrival(remaining: 50_000, pace: nil, today: today) == nil)
        #expect(estimator.arrival(remaining: 50_000, pace: 0, today: today) == nil)
    }

    @Test func arrivalPhrases() {
        let phrase = ArrivalPhrase(calendar: utc, locale: Locale(identifier: "en_US"))
        let today = date(2026, 11, 16)

        #expect(phrase.phrase(for: date(2026, 11, 17), today: today) == "tomorrow")
        #expect(phrase.phrase(for: date(2026, 11, 23), today: today) == "in about 7 days")
        #expect(phrase.phrase(for: date(2027, 3, 25), today: today) == "in late March")
        #expect(phrase.phrase(for: date(2027, 2, 3), today: today) == "in early February")
        #expect(phrase.phrase(for: date(2028, 8, 15), today: today) == "around August 2028")
        #expect(phrase.phrase(for: date(2030, 2, 1), today: today) == "in about 3 years")
    }

    @Test func snapshotRoundTrips() throws {
        let defaults = try #require(UserDefaults(suiteName: "steady-tests-\(UUID().uuidString)"))
        WidgetSnapshot.placeholder.save(to: defaults)
        #expect(WidgetSnapshot.load(from: defaults) == WidgetSnapshot.placeholder)
        #expect(WidgetSnapshot.placeholder.journey?.percent == "23%")
    }
}
