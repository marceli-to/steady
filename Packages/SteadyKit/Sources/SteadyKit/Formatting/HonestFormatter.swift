import Foundation

public enum DistanceUnit: String, Sendable, Codable, CaseIterable {
    case kilometres, miles

    public var metresPerUnit: Double { self == .kilometres ? 1_000 : 1_609.344 }
    public var symbol: String { self == .kilometres ? "km" : "mi" }
    public var heightSymbol: String { self == .kilometres ? "m" : "ft" }
    public var metresPerHeightUnit: Double { self == .kilometres ? 1 : 0.3048 }

    public static var localeDefault: DistanceUnit {
        Locale.current.measurementSystem == .us || Locale.current.measurementSystem == .uk ? .miles : .kilometres
    }
}

/// Turns approximate measurements into numbers that don't pretend to be precise.
///
/// - Distance: under 10 → one decimal, under 1,000 → whole units, otherwise nearest 10.
/// - Height: under 100 → whole units, otherwise nearest 10.
/// - Multiples: under 10 → one decimal, otherwise whole.
public struct HonestFormatter: Sendable {
    public var unit: DistanceUnit
    public var locale: Locale

    public init(unit: DistanceUnit = .kilometres, locale: Locale = .current) {
        self.unit = unit
        self.locale = locale
    }

    // MARK: Distance

    /// The rounded value in the current unit, e.g. 11240 for 11,238,400 m.
    public func roundedDistance(_ metres: Double) -> Double {
        let value = max(0, metres) / unit.metresPerUnit
        switch value {
        case ..<10: return (value * 10).rounded() / 10
        case ..<1_000: return value.rounded()
        default: return (value / 10).rounded() * 10
        }
    }

    /// "11,240"
    public func distanceNumber(_ metres: Double) -> String {
        let value = roundedDistance(metres)
        return number(value, fractionDigits: value < 10 && value != value.rounded() ? 1 : 0)
    }

    /// "11,240 km"
    public func distance(_ metres: Double) -> String {
        "\(distanceNumber(metres)) \(unit.symbol)"
    }

    // MARK: Height

    public func roundedHeight(_ metres: Double) -> Double {
        let value = max(0, metres) / unit.metresPerHeightUnit
        return value < 100 ? value.rounded() : (value / 10).rounded() * 10
    }

    /// "4,560"
    public func heightNumber(_ metres: Double) -> String {
        number(roundedHeight(metres), fractionDigits: 0)
    }

    /// Unrounded, for heights that are facts rather than measurements (Everest is 8,849 m).
    public func exactHeightNumber(_ metres: Double) -> String {
        number((max(0, metres) / unit.metresPerHeightUnit).rounded(), fractionDigits: 0)
    }

    /// "4,560 m"
    public func height(_ metres: Double) -> String {
        "\(heightNumber(metres)) \(unit.heightSymbol)"
    }

    // MARK: Multiples and comparisons

    /// "4.7×", "12×"
    public func multiple(_ times: Double) -> String {
        let rounded = times < 10 ? (times * 10).rounded() / 10 : times.rounded()
        return number(rounded, fractionDigits: rounded < 10 && rounded != rounded.rounded() ? 1 : 0) + "×"
    }

    /// "≈ Zürich → Beijing"
    public func comparison(_ comparison: DistanceComparison) -> String {
        "≈ " + comparisonBody(comparison)
    }

    public func comparisonBody(_ comparison: DistanceComparison) -> String {
        switch comparison {
        case let .route(from, to, _):
            return "\(from.name) → \(to.name)"
        case let .aroundTheWorld(times):
            if times < 0.95 { return "\(percent(times)) of the way around the world" }
            return "\(multiple(times)) around the world"
        case let .towardsMoon(fraction):
            if fraction >= 0.95 { return "\(multiple(fraction)) the way to the Moon" }
            return "\(friendlyFraction(fraction)) of the way to the Moon"
        }
    }

    /// "≈ Everest 4.7×", or "≈ 40% of the Eiffel Tower" before the first landmark is reached.
    public func comparison(_ comparison: ElevationComparison) -> String {
        "≈ " + comparisonBody(comparison)
    }

    public func comparisonBody(_ comparison: ElevationComparison) -> String {
        if comparison.times < 0.95 {
            return "\(percent(comparison.times)) of \(comparison.landmark.name)"
        }
        return "\(comparison.landmark.short) \(multiple(comparison.times))"
    }

    /// VoiceOver-friendly sentence for a distance comparison.
    public func spokenComparison(_ comparison: DistanceComparison) -> String {
        switch comparison {
        case let .route(from, to, _): return "about as far as from \(from.name) to \(to.name)"
        default: return "about " + comparisonBody(comparison)
        }
    }

    // MARK: Helpers

    func percent(_ fraction: Double) -> String {
        let pct = max(1, (fraction * 100 / 5).rounded() * 5)
        return "\(Int(pct))%"
    }

    func friendlyFraction(_ value: Double) -> String {
        let candidates: [(Double, String)] = [(0.1, "a tenth"), (0.2, "a fifth"), (0.25, "a quarter"),
                                              (1.0 / 3, "a third"), (0.5, "half"), (2.0 / 3, "two thirds"), (0.75, "three quarters")]
        if let match = candidates.first(where: { abs($0.0 - value) < 0.03 }) { return match.1 }
        return percent(value)
    }

    func number(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).grouping(.automatic).locale(locale))
    }
}
