import Foundation
import SwiftData
import SteadyKit

/// A postcard from a milestone. Written once, when the milestone is first seen in the history,
/// and never recomputed: it keeps the day, progress and workout setting it was written with.
@Model
final class Postcard {
    @Attribute(.unique) var id: UUID
    var run: JourneyRun?
    var journeyID: String
    var journeyVersion: Int
    var milestoneID: String
    var reachedOn: Date
    var dayNumber: Int
    var progress: Double
    var includedWorkouts: Bool
    var seen: Bool
    var ownerID: String

    init(_ payload: PostcardPayload) {
        id = payload.id
        journeyID = payload.journeyID
        journeyVersion = payload.journeyVersion
        milestoneID = payload.milestoneID
        reachedOn = payload.reachedOn
        dayNumber = payload.dayNumber
        progress = payload.progress
        includedWorkouts = payload.includedWorkouts
        seen = false
        ownerID = payload.ownerID
    }

    var payload: PostcardPayload {
        PostcardPayload(id: id, runID: run?.id ?? id, journeyID: journeyID, journeyVersion: journeyVersion,
                        milestoneID: milestoneID, reachedOn: reachedOn, dayNumber: dayNumber, progress: progress,
                        includedWorkouts: includedWorkouts, ownerID: ownerID)
    }

    var journey: Journey? { JourneyCatalog.journey(id: journeyID) }
    var milestone: Milestone? { journey?.milestones.first { $0.id == milestoneID } }
}
