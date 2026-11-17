import Foundation
import SwiftData
import SteadyKit

/// One person's run of a bundled journey. Progress isn't stored: it's recomputed from the
/// cached daily history, so changing "include workouts" re-tells the whole story consistently.
@Model
final class JourneyRun {
    @Attribute(.unique) var id: UUID
    var journeyID: String
    var journeyVersion: Int
    /// Counting starts at the beginning of this calendar day.
    var startedOn: Date
    var finishedOn: Date?
    /// Always "local" in v1. Ready for following other people later.
    var ownerID: String
    @Relationship(deleteRule: .cascade, inverse: \Postcard.run) var postcards: [Postcard] = []

    init(journey: Journey, startedOn: Date) {
        id = UUID()
        journeyID = journey.id
        journeyVersion = journey.version
        self.startedOn = startedOn
        finishedOn = nil
        ownerID = "local"
    }

    var journey: Journey? { JourneyCatalog.journey(id: journeyID) }
}
