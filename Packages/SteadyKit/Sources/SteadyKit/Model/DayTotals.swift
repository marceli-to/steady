import Foundation

/// The quantities steady reads from Health.
public enum HealthMetric: String, Sendable, CaseIterable, Codable {
    case walkingDistance   // metres
    case steps             // count
    case flightsClimbed    // count
}

/// One calendar day of movement, with the part that happened during workouts kept separate,
/// so the "include workouts" setting can flip without re-reading Health.
public struct DayTotals: Sendable, Hashable, Codable {
    public var day: Date                    // start of the day in the user's calendar
    public var distance: Double             // metres, all walking + running that day
    public var distanceInWorkouts: Double   // metres of that which fell inside workouts
    public var flights: Double
    public var flightsInWorkouts: Double
    public var steps: Double

    public init(day: Date, distance: Double = 0, distanceInWorkouts: Double = 0,
                flights: Double = 0, flightsInWorkouts: Double = 0, steps: Double = 0) {
        self.day = day
        self.distance = distance
        self.distanceInWorkouts = distanceInWorkouts
        self.flights = flights
        self.flightsInWorkouts = flightsInWorkouts
        self.steps = steps
    }

    public func distance(includingWorkouts: Bool) -> Double {
        includingWorkouts ? distance : max(0, distance - min(distanceInWorkouts, distance))
    }

    public func flights(includingWorkouts: Bool) -> Double {
        includingWorkouts ? flights : max(0, flights - min(flightsInWorkouts, flights))
    }

    /// Metres climbed. Apple counts a flight as roughly 3 m (10 ft) of ascent.
    public func elevation(includingWorkouts: Bool) -> Double {
        flights(includingWorkouts: includingWorkouts) * Elevation.metresPerFlight
    }

    public var hasData: Bool { distance > 0 || steps > 0 || flights > 0 }
}

public enum Elevation {
    public static let metresPerFlight: Double = 3
}
