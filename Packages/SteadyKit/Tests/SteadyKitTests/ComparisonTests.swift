import Foundation
import Testing
@testable import SteadyKit

private let zurich = Place(id: "zurich", name: "Zürich", country: "CH", lat: 47.3769, lon: 8.5417, rank: 1)
private let winterthur = Place(id: "winterthur", name: "Winterthur", country: "CH", lat: 47.4988, lon: 8.7237, rank: 3)
private let kloten = Place(id: "kloten", name: "Kloten", country: "CH", lat: 47.4515, lon: 8.5849, rank: 3) // ~9 km
private let paris = Place(id: "paris", name: "Paris", country: "FR", lat: 48.8566, lon: 2.3522, rank: 1)
private let london = Place(id: "london", name: "London", country: "GB", lat: 51.5074, lon: -0.1278, rank: 1)
private let newYork = Place(id: "new-york", name: "New York", country: "US", lat: 40.7128, lon: -74.0060, rank: 1)
private let beijing = Place(id: "beijing", name: "Beijing", country: "CN", lat: 39.9042, lon: 116.4074, rank: 1)
private let auckland = Place(id: "auckland", name: "Auckland", country: "NZ", lat: -36.8485, lon: 174.7633, rank: 1)

private let landmarks = [
    Landmark(id: "eiffel", name: "the Eiffel Tower", short: "Eiffel Tower", metres: 330),
    Landmark(id: "matterhorn", name: "the Matterhorn", short: "Matterhorn", metres: 4478),
    Landmark(id: "everest", name: "Everest", short: "Everest", metres: 8849),
]

private func picker(_ places: [Place]) -> ComparisonPicker {
    ComparisonPicker(places: places, landmarks: landmarks)
}

@Suite("Comparisons")
struct ComparisonTests {
    @Test func greatCircleMatchesKnownDistances() {
        // Reference values, ±1 %.
        #expect(abs(GreatCircle.distance(london, paris) / 1000 - 344) < 4)
        #expect(abs(GreatCircle.distance(zurich, newYork) / 1000 - 6_320) < 63)
        #expect(abs(GreatCircle.distance(zurich, beijing) / 1000 - 7_990) < 80)
        #expect(GreatCircle.distance(zurich, zurich) == 0)
    }

    @Test func picksPlaceClosestToTotal() {
        let p = picker([zurich, paris, london, newYork, beijing])

        #expect(p.distance(7_900_000, from: zurich) == .route(from: zurich, to: beijing, distance: GreatCircle.distance(zurich, beijing)))
        #expect(p.distance(500_000, from: zurich).map(destination) == "paris")
        #expect(p.distance(700_000, from: zurich).map(destination) == "london")
    }

    @Test func nearTieGoesToBetterKnownPlace() {
        // Winterthur (rank 3) vs a made-up famous place due east of Zürich, 5 % further away.
        let total = GreatCircle.distance(zurich, winterthur)
        let dλ = total * 1.05 / (GreatCircle.earthRadius * cos(zurich.lat * .pi / 180)) * 180 / .pi
        let famous = Place(id: "famous", name: "Famous", country: "CH", lat: zurich.lat, lon: zurich.lon + dλ, rank: 1)
        let p = picker([zurich, winterthur, famous])

        #expect(abs(GreatCircle.distance(zurich, famous) / total - 1.05) < 0.001)
        #expect(p.distance(total, from: zurich).map(destination) == "winterthur") // outside 2 % slack

        var loose = p
        loose.tieTolerance = 0.2
        #expect(loose.distance(total, from: zurich).map(destination) == "famous")
    }

    @Test func ignoresHomeAndPlacesTooClose() {
        let p = picker([zurich, kloten, paris])

        #expect(p.distance(3_000, from: zurich) == nil)                    // below 5 km: nothing honest to say
        #expect(p.distance(9_000, from: zurich).map(destination) == "kloten")
        var strict = p
        strict.minimumRoute = 10_000
        #expect(strict.distance(12_000, from: zurich).map(destination) == "paris")
    }

    @Test func beyondTheFarthestPlaceCountsLapsOfTheWorld() {
        let p = picker([zurich, paris, auckland])
        let farthest = GreatCircle.distance(zurich, auckland) // ~18,300 km

        #expect(p.distance(farthest, from: zurich).map(destination) == "auckland")
        guard case let .aroundTheWorld(times) = p.distance(56_000_000, from: zurich) else {
            Issue.record("expected around the world"); return
        }
        #expect(abs(times - 56_000_000 / GreatCircle.earthCircumference) < 0.0001)
        guard case let .towardsMoon(fraction) = p.distance(130_000_000, from: zurich) else {
            Issue.record("expected the Moon"); return
        }
        #expect(abs(fraction - 130_000_000 / GreatCircle.moonDistance) < 0.0001)
    }

    @Test func bundledAtlasLoadsAndIsSane() {
        #expect(Atlas.places.count > 200)
        #expect(Set(Atlas.places.map(\.id)).count == Atlas.places.count)
        #expect(Atlas.places.allSatisfy { (-90...90).contains($0.lat) && (-180...180).contains($0.lon) })
        #expect(Atlas.homePlaces.contains { $0.id == "zurich" })
        #expect(!Atlas.homePlaces.contains { $0.id == "south-pole" })
        #expect(Atlas.landmarks.last?.id == "everest")
    }

    @Test func picksTallestLandmarkClimbed() {
        let p = picker([])

        #expect(p.elevation(0) == nil)
        #expect(p.elevation(5_000)?.landmark.id == "matterhorn")
        let pastEverest = p.elevation(41_590)
        #expect(pastEverest?.landmark.id == "everest")
        #expect(abs((pastEverest?.times ?? 0) - 4.7) < 0.01)
        let small = p.elevation(132)
        #expect(small?.landmark.id == "eiffel")
        #expect(abs((small?.times ?? 0) - 0.4) < 0.001)
    }

    private func destination(_ c: DistanceComparison) -> String? {
        if case let .route(_, to, _) = c { return to.id }
        return nil
    }
}
