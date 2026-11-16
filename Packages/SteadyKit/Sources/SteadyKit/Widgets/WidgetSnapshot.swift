import Foundation

/// What the widgets show, already formatted by the app. Written to the App Group after every refresh.
/// Widgets never read Health themselves; this keeps them simple and always populated.
public struct WidgetSnapshot: Sendable, Codable, Hashable {
    public struct JourneyInfo: Sendable, Codable, Hashable {
        public var title: String          // "Zürich → Rome"
        public var destination: String    // "Rome"
        public var whereabouts: String    // "near Bellinzona"
        public var done: String           // "214"
        public var total: String          // "~900"
        public var unit: String           // "km"
        public var fraction: Double       // 0…1
        /// Fractions of the intermediate milestones, for dots on the line.
        public var stops: [Double]

        public init(title: String, destination: String, whereabouts: String, done: String, total: String,
                    unit: String, fraction: Double, stops: [Double]) {
            self.title = title
            self.destination = destination
            self.whereabouts = whereabouts
            self.done = done
            self.total = total
            self.unit = unit
            self.fraction = fraction
            self.stops = stops
        }

        public var percent: String { "\(Int((fraction * 100).rounded(.down)))%" }
    }

    public var updatedAt: Date
    public var journey: JourneyInfo?
    public var yearDistance: String       // "1,840"
    public var unit: String               // "km"
    public var yearComparison: String?    // "≈ Zürich → Lisbon"

    public init(updatedAt: Date, journey: JourneyInfo?, yearDistance: String, unit: String, yearComparison: String?) {
        self.updatedAt = updatedAt
        self.journey = journey
        self.yearDistance = yearDistance
        self.unit = unit
        self.yearComparison = yearComparison
    }

    public static let placeholder = WidgetSnapshot(
        updatedAt: .now,
        journey: JourneyInfo(title: "Zürich → Rome", destination: "Rome", whereabouts: "near Bellinzona",
                             done: "214", total: "~900", unit: "km", fraction: 0.238,
                             stops: [0.128, 0.228, 0.333, 0.567, 0.683]),
        yearDistance: "1,840", unit: "km", yearComparison: "≈ Zürich → Lisbon"
    )

    // MARK: Storage

    public static let appGroup = "group.to.marceli.steady.dev"
    private static let key = "widgetSnapshot"

    public static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public func save(to defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }
}
