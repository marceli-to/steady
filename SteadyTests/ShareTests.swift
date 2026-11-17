import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Steady
import SteadyKit

@MainActor
@Suite("Postcards and share cards")
struct ShareTests {
    let calendar = Calendar.current

    func makeModel(_ source: some HealthDataSource) throws -> AppModel {
        let container = try ModelContainer(for: DayRecord.self, JourneyRun.self, Postcard.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let defaults = UserDefaults(suiteName: "share-tests-\(UUID().uuidString)")!
        return AppModel(source: source, usesMockData: true, container: container, defaults: defaults, calendar: calendar)
    }

    /// 20 km of walking on each of the last `days` days.
    func walking(days: Int) -> MockHealthDataSource {
        let today = calendar.startOfDay(for: .now)
        let samples = (1...days).map { ago -> MockSample in
            let day = calendar.date(byAdding: .day, value: -ago, to: today)!
            let start = calendar.date(byAdding: .hour, value: 10, to: day)!
            return MockSample(.walkingDistance, start: start, end: start.addingTimeInterval(3_600), value: 20_000)
        }
        return MockHealthDataSource(samples: samples, workouts: [])
    }

    @Test func milestonesReachedWhileAwayGetOnePostcardEach() async throws {
        let model = try makeModel(walking(days: 12))
        model.refresh()
        await model.waitForSync()

        // Started 12 days ago: 240 km walked, past Gotthard (115 km, day 6) and Bellinzona (205 km, day 11).
        let rome = try #require(JourneyCatalog.journey(id: "zurich-rome"))
        model.start(rome, on: calendar.date(byAdding: .day, value: -12, to: .now)!)

        #expect(model.postcards.map(\.milestoneID) == ["bellinzona", "gotthard"])
        #expect(model.postcards.map(\.dayNumber) == [11, 6])
        #expect(model.postcards.allSatisfy { !$0.seen && !$0.includedWorkouts })

        // Refreshing again, or flipping settings, writes nothing twice.
        model.refresh()
        await model.waitForSync()
        model.includeWorkouts = true
        model.includeWorkouts = false
        #expect(model.postcards.count == 2)
        #expect(model.unseenPostcard?.milestoneID == "bellinzona")
    }

    @Test func cardsRenderAtExactPixelSizes() throws {
        let journey = try #require(JourneyCatalog.journey(id: "zurich-rome"))
        let payload = PostcardPayload(runID: UUID(), journeyID: journey.id, journeyVersion: 1, milestoneID: "bellinzona",
                                      reachedOn: .now, dayNumber: 63, progress: 0.2, includedWorkouts: false)
        let postcard = try #require(ShareCards.postcard(payload, journey: journey, home: nil, showsHomeCity: true,
                                                        formatter: HonestFormatter()))
        let story = StoryCardContent(
            since: "since March 2019", number: "11,240", unit: "km", routeFrom: "Zürich", routeTo: "Beijing",
            sentence: "That’s Zürich to Beijing — just from everyday life.",
            climbed: "Plus 41,200 m climbed", climbedComparison: "Everest 4.7×")

        let storyPNG = try #require(ShareRenderer.story(story))
        let postcardPNG = try #require(ShareRenderer.postcard(postcard))
        let storyImage = try #require(UIImage(data: storyPNG))
        let postcardImage = try #require(UIImage(data: postcardPNG))

        #expect(storyImage.size.width * storyImage.scale == 1080)
        #expect(storyImage.size.height * storyImage.scale == 1920)
        #expect(postcardImage.size.width * postcardImage.scale == 1080)
        #expect(postcardImage.size.height * postcardImage.scale == 1080)

        // Handy for comparing with the mockups in design/.
        if let folder = ProcessInfo.processInfo.environment["SHARE_CARD_OUTPUT"] {
            try storyPNG.write(to: URL(fileURLWithPath: folder).appendingPathComponent("story.png"))
            try postcardPNG.write(to: URL(fileURLWithPath: folder).appendingPathComponent("postcard.png"))
        }
    }
}
