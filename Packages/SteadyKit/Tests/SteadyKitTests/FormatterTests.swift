import Foundation
import Testing
@testable import SteadyKit

private let en = Locale(identifier: "en_US")

@Suite("Honest formatting")
struct FormatterTests {
    let km = HonestFormatter(unit: .kilometres, locale: en)
    let mi = HonestFormatter(unit: .miles, locale: en)

    @Test(arguments: [
        (0.0, "0 km"),
        (3_240.0, "3.2 km"),
        (9_960.0, "10 km"),
        (12_400.0, "12 km"),
        (999_400.0, "999 km"),
        (11_238_400.0, "11,240 km"),
        (11_234_900.0, "11,230 km"),
        (-50.0, "0 km"),
    ])
    func kilometres(metres: Double, expected: String) {
        #expect(km.distance(metres) == expected)
    }

    @Test(arguments: [
        (1_609.344, "1 mi"),
        (8_000.0, "5 mi"),
        (11_238_400.0, "6,980 mi"),
        (500_000.0, "311 mi"),
    ])
    func miles(metres: Double, expected: String) {
        #expect(mi.distance(metres) == expected)
    }

    @Test func heights() {
        #expect(km.height(42) == "42 m")
        #expect(km.height(41_587) == "41,590 m")
        #expect(mi.height(1_000) == "3,280 ft")
    }

    @Test func multiples() {
        #expect(km.multiple(4.6997) == "4.7×")
        #expect(km.multiple(2.0) == "2×")
        #expect(km.multiple(12.4) == "12×")
    }

    @Test func comparisonLabels() {
        let zurich = Place(id: "zurich", name: "Zürich", country: "CH", lat: 0, lon: 0)
        let beijing = Place(id: "beijing", name: "Beijing", country: "CN", lat: 0, lon: 0)
        let everest = Landmark(id: "everest", name: "Everest", short: "Everest", metres: 8849)
        let eiffel = Landmark(id: "eiffel", name: "the Eiffel Tower", short: "Eiffel Tower", metres: 330)

        #expect(km.comparison(.route(from: zurich, to: beijing, distance: 0)) == "≈ Zürich → Beijing")
        #expect(km.comparison(.aroundTheWorld(times: 1.38)) == "≈ 1.4× around the world")
        #expect(km.comparison(.aroundTheWorld(times: 0.62)) == "≈ 60% of the way around the world")
        #expect(km.comparison(.towardsMoon(fraction: 0.34)) == "≈ a third of the way to the Moon")
        #expect(km.comparison(ElevationComparison(landmark: everest, times: 4.7)) == "≈ Everest 4.7×")
        #expect(km.comparison(ElevationComparison(landmark: eiffel, times: 0.4)) == "≈ 40% of the Eiffel Tower")
    }
}
