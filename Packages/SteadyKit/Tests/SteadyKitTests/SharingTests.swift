import Foundation
import Testing
@testable import SteadyKit

private let rome = Journey(
    id: "test-rome", title: "Zürich → Rome", destination: "Rome", metric: .distance, total: 900_000,
    milestones: [
        Milestone(id: "zurich", name: "Zürich", at: 0, lat: 47.3769, lon: 8.5417),
        Milestone(id: "gotthard", name: "Gotthard", at: 105_000, lat: 46.5585, lon: 8.5617),
        Milestone(id: "bellinzona", name: "Bellinzona", at: 175_000, lat: 46.1955, lon: 9.0237),
        Milestone(id: "roma", name: "Roma", at: 900_000, lat: 41.9028, lon: 12.4964),
    ]
)

private let zurich = Place(id: "zurich", name: "Zürich", country: "CH", lat: 47.3769, lon: 8.5417, rank: 1)
private let lisbon = Place(id: "lisbon", name: "Lisbon", country: "PT", lat: 38.7223, lon: -9.1393, rank: 1)
private let beijing = Place(id: "beijing", name: "Beijing", country: "CN", lat: 39.9042, lon: 116.4074, rank: 1)

private func walks(_ perDay: [Int: Double]) -> [DayTotals] {
    perDay.map { DayTotals(day: date(2024, 1, $0.key), distance: $0.value, distanceInWorkouts: 0, flights: 0) }
}

@Suite("Postcards and share cards")
struct SharingTests {
    let tracker = JourneyTracker(calendar: utc)
    let run = UUID()

    @Test func onePostcardPerMilestoneWithItsRealDay() {
        // Started on the 1st, app not opened until the 20th: Gotthard on the 3rd, Bellinzona on the 9th.
        let days = walks([1: 40_000, 3: 70_000, 5: 30_000, 9: 50_000, 20: 1_000])
        let progress = tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days, includingWorkouts: false)

        let cards = PostcardPlanner.newPostcards(for: progress, runID: run, existing: [], includedWorkouts: false)

        #expect(cards.map(\.milestoneID) == ["gotthard", "bellinzona"])
        #expect(cards.map(\.reachedOn) == [date(2024, 1, 3), date(2024, 1, 9)])
        #expect(cards.map(\.dayNumber) == [3, 9])
        #expect(cards[1].progress == 175_000.0 / 900_000)
        #expect(cards.allSatisfy { $0.runID == run && !$0.includedWorkouts })
    }

    @Test func writingPostcardsTwiceWritesThemOnce() {
        let days = walks([1: 120_000])
        var progress = tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days, includingWorkouts: false)
        let first = PostcardPlanner.newPostcards(for: progress, runID: run, existing: [], includedWorkouts: false)
        #expect(first.map(\.milestoneID) == ["gotthard"])

        let again = PostcardPlanner.newPostcards(for: progress, runID: run, existing: Set(first.map(\.milestoneID)), includedWorkouts: false)
        #expect(again.isEmpty)

        // More walking: only the new milestone gets a postcard.
        progress = tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: days + walks([2: 60_000]), includingWorkouts: false)
        let later = PostcardPlanner.newPostcards(for: progress, runID: run, existing: Set(first.map(\.milestoneID)), includedWorkouts: false)
        #expect(later.map(\.milestoneID) == ["bellinzona"])
        #expect(later.first?.dayNumber == 2)
    }

    @Test func theStartNeverGetsAPostcard() {
        let progress = tracker.progress(of: rome, startedOn: date(2024, 1, 1), days: [], includingWorkouts: false)
        #expect(PostcardPlanner.newPostcards(for: progress, runID: run, existing: [], includedWorkouts: false).isEmpty)
    }

    @Test func storyCardHidesHomeUnlessAllowed() {
        let summary = MovementSummary(distance: 11_240_000, elevation: 41_200, steps: 0,
                                      firstDay: date(2019, 3, 4), lastDay: nil, daysWithData: 2_000)
        let comparison = DistanceComparison.route(from: zurich, to: beijing, distance: 7_900_000)
        let formatter = HonestFormatter(unit: .kilometres, locale: Locale(identifier: "en_US"))

        let hidden = ShareCards.story(summary: summary, comparison: comparison, elevation: nil, home: zurich,
                                      showsHomeCity: false, formatter: formatter, calendar: utc)
        let everything = [hidden.since, hidden.number, hidden.routeFrom, hidden.routeTo, hidden.sentence, hidden.climbed]
            .compactMap { $0 }.joined(separator: " ")
        #expect(!everything.contains("Zürich"))
        #expect(hidden.routeFrom == nil)
        #expect(hidden.routeTo == "Beijing")

        let shown = ShareCards.story(summary: summary, comparison: comparison, elevation: nil, home: zurich,
                                     showsHomeCity: true, formatter: formatter, calendar: utc)
        #expect(shown.routeFrom == "Zürich")
        #expect(shown.sentence == "That’s Zürich to Beijing — just from everyday life.")
        #expect(shown.since == "since March 2019")
        #expect(shown.number == "11,240")
        #expect(shown.climbed == "Plus 41,200 m climbed")

        let world = ShareCards.story(summary: summary, comparison: .aroundTheWorld(times: 1.4), elevation: nil,
                                     home: zurich, showsHomeCity: false, formatter: formatter, calendar: utc)
        #expect(world.routeFrom == nil)
    }

    @Test func postcardHidesAStartNearHome() throws {
        let payload = PostcardPayload(runID: run, journeyID: rome.id, journeyVersion: 1, milestoneID: "bellinzona",
                                      reachedOn: date(2024, 3, 3), dayNumber: 63, progress: 175_000.0 / 900_000,
                                      includedWorkouts: false)
        let formatter = HonestFormatter(unit: .kilometres, locale: Locale(identifier: "en_US"))

        let private_ = try #require(ShareCards.postcard(payload, journey: rome, home: zurich, showsHomeCity: false, formatter: formatter))
        #expect(private_.hidesStart)
        #expect(private_.title == "To Rome")
        #expect(private_.stops.map(\.id) == ["gotthard", "bellinzona", "roma"])
        #expect(private_.stops.first?.position == 0)
        #expect(private_.stops.first?.isEnd == true)

        // Living far from the start, or allowing the home city, shows the whole route.
        let far = try #require(ShareCards.postcard(payload, journey: rome, home: lisbon, showsHomeCity: false, formatter: formatter))
        #expect(!far.hidesStart)
        #expect(far.title == "Zürich → Rome")
        let allowed = try #require(ShareCards.postcard(payload, journey: rome, home: zurich, showsHomeCity: true, formatter: formatter))
        #expect(allowed.stops.map(\.id) == ["zurich", "gotthard", "bellinzona", "roma"])

        #expect(allowed.header == "Postcard · Day 63")
        #expect(allowed.headline == "Arrived in Bellinzona.")
        #expect(allowed.body == "175 km of about 900 — walked to work, to the shop, up the stairs.")
        #expect(allowed.footnote == "no workouts counted")
        #expect(allowed.stops.map(\.state) == [.passed, .passed, .current, .ahead])
        #expect(allowed.stops.map(\.position).first == 0 && allowed.stops.map(\.position).last == 1)
    }
}
