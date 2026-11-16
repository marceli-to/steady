import Foundation

public enum GreatCircle {
    public static let earthRadius: Double = 6_371_000 // metres
    public static let earthCircumference: Double = 40_075_000
    public static let moonDistance: Double = 384_400_000

    /// Haversine distance in metres.
    public static func distance(_ a: Place, _ b: Place) -> Double {
        distance(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
    }

    public static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180, φ2 = lat2 * .pi / 180
        let dφ = (lat2 - lat1) * .pi / 180
        let dλ = (lon2 - lon1) * .pi / 180
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}

public enum DistanceComparison: Sendable, Hashable {
    /// "≈ Zürich → Beijing"
    case route(from: Place, to: Place, distance: Double)
    /// "≈ 1.4× around the world"
    case aroundTheWorld(times: Double)
    /// "≈ ⅓ of the way to the Moon"
    case towardsMoon(fraction: Double)
}

public struct ElevationComparison: Sendable, Hashable {
    public var landmark: Landmark
    /// How many times the landmark's height. Below 1 when the user hasn't climbed even the smallest one yet.
    public var times: Double
}

public struct ComparisonPicker: Sendable {
    public var places: [Place]
    public var landmarks: [Landmark]
    /// Places closer than this to home are never a comparison ("Zürich → Zürich").
    public var minimumRoute: Double = 5_000
    /// Totals within this fraction of the best match count as a tie; the better-known place wins.
    public var tieTolerance: Double = 0.02
    /// From this total on, the Moon is the more honest yardstick.
    public var moonThreshold: Double = 100_000_000

    public init(places: [Place] = Atlas.places, landmarks: [Landmark] = Atlas.landmarks) {
        self.places = places
        self.landmarks = landmarks.sorted { $0.metres < $1.metres }
    }

    /// The place whose great-circle distance from `home` is closest to `total` metres.
    public func distance(_ total: Double, from home: Place) -> DistanceComparison? {
        guard total >= minimumRoute else { return nil }
        if total >= moonThreshold {
            return .towardsMoon(fraction: total / GreatCircle.moonDistance)
        }

        let candidates = places
            .filter { $0.id != home.id }
            .map { (place: $0, distance: GreatCircle.distance(home, $0)) }
            .filter { $0.distance >= minimumRoute }
        guard let farthest = candidates.map(\.distance).max() else { return nil }

        // Further than any place on Earth can be from home: switch to laps of the planet.
        if total > farthest * 1.05 {
            return .aroundTheWorld(times: total / GreatCircle.earthCircumference)
        }

        let bestError = candidates.map { abs($0.distance - total) }.min() ?? .infinity
        let slack = bestError + total * tieTolerance
        let pick = candidates
            .filter { abs($0.distance - total) <= slack }
            .min { a, b in
                if a.place.rank != b.place.rank { return a.place.rank < b.place.rank }
                return abs(a.distance - total) < abs(b.distance - total)
            }
        return pick.map { .route(from: home, to: $0.place, distance: $0.distance) }
    }

    /// The tallest landmark climbed at least once, as a multiple ("Everest 4.7×").
    public func elevation(_ metres: Double) -> ElevationComparison? {
        guard metres > 0, let smallest = landmarks.first else { return nil }
        let landmark = landmarks.last { $0.metres <= metres } ?? smallest
        return ElevationComparison(landmark: landmark, times: metres / landmark.metres)
    }
}
