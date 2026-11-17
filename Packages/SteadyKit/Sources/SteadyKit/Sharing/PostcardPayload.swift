import Foundation

/// A postcard as a self-contained value: everything needed to show it again, even if the
/// journey's data changes later. Codable so it could be published one day; v1 keeps it local.
public struct PostcardPayload: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var runID: UUID
    public var journeyID: String
    public var journeyVersion: Int
    public var milestoneID: String
    /// The day the milestone was reached, from the daily history (not when the app noticed).
    public var reachedOn: Date
    /// Day N of the journey; the start day is day 1.
    public var dayNumber: Int
    /// Progress along the route at that moment, 0…1.
    public var progress: Double
    /// Whether workouts counted towards the journey when the postcard was written.
    public var includedWorkouts: Bool
    public var ownerID: String

    public init(id: UUID = UUID(), runID: UUID, journeyID: String, journeyVersion: Int, milestoneID: String,
                reachedOn: Date, dayNumber: Int, progress: Double, includedWorkouts: Bool, ownerID: String = "local") {
        self.id = id
        self.runID = runID
        self.journeyID = journeyID
        self.journeyVersion = journeyVersion
        self.milestoneID = milestoneID
        self.reachedOn = reachedOn
        self.dayNumber = dayNumber
        self.progress = progress
        self.includedWorkouts = includedWorkouts
        self.ownerID = ownerID
    }
}

public enum PostcardPlanner {
    /// Postcards still to write for a run: one per milestone reached after the start, skipping
    /// milestones that already have one. Calling it again with the result's milestones as
    /// `existing` returns nothing, so it is safe to run on every refresh.
    public static func newPostcards(for progress: JourneyProgress, runID: UUID, existing: Set<String>,
                                    includedWorkouts: Bool) -> [PostcardPayload] {
        progress.reached
            .filter { $0.milestone.id != progress.journey.start.id && !existing.contains($0.milestone.id) }
            .map {
                PostcardPayload(
                    runID: runID,
                    journeyID: progress.journey.id,
                    journeyVersion: progress.journey.version,
                    milestoneID: $0.milestone.id,
                    reachedOn: $0.date,
                    dayNumber: $0.dayNumber,
                    progress: $0.fraction,
                    includedWorkouts: includedWorkouts
                )
            }
    }
}
