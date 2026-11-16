import Foundation

public enum JourneyMetric: String, Sendable, Codable, Hashable {
    case distance    // metres walked
    case elevation   // metres climbed
}

public struct Milestone: Sendable, Codable, Hashable, Identifiable {
    public var id: String
    public var name: String
    /// Cumulative metres (walked or climbed) at which this milestone is reached.
    public var at: Double
    public var lat: Double?
    public var lon: Double?
    /// Altitude in metres, for elevation journeys.
    public var altitude: Double?

    public init(id: String, name: String, at: Double, lat: Double? = nil, lon: Double? = nil, altitude: Double? = nil) {
        self.id = id
        self.name = name
        self.at = at
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
    }
}

/// A bundled route. See PLAN.md §3 for the JSON format.
public struct Journey: Sendable, Codable, Hashable, Identifiable {
    public var id: String
    public var version: Int
    /// "Zürich → Rome"
    public var title: String
    /// Short destination name for tight spaces: "Rome".
    public var destination: String
    public var subtitle: String
    public var metric: JourneyMetric
    /// Metres, equal to the last milestone's `at`.
    public var total: Double
    public var milestones: [Milestone]

    public init(id: String, version: Int = 1, title: String, destination: String, subtitle: String = "",
                metric: JourneyMetric, total: Double, milestones: [Milestone]) {
        self.id = id
        self.version = version
        self.title = title
        self.destination = destination
        self.subtitle = subtitle
        self.metric = metric
        self.total = total
        self.milestones = milestones
    }

    public var start: Milestone { milestones[0] }
    public var finish: Milestone { milestones[milestones.count - 1] }

    /// Problems with this journey's data; empty when it's valid.
    public func validationProblems() -> [String] {
        var problems: [String] = []
        if milestones.count < 2 { problems.append("needs at least two milestones") }
        if Set(milestones.map(\.id)).count != milestones.count { problems.append("milestone ids must be unique") }
        if let first = milestones.first, first.at < 0 { problems.append("first milestone must be at 0 or more") }
        for (a, b) in zip(milestones, milestones.dropFirst()) where b.at <= a.at {
            problems.append("\(b.id) must come after \(a.id)")
        }
        if let last = milestones.last, last.at != total { problems.append("last milestone must be at total") }
        if metric == .distance, milestones.contains(where: { $0.lat == nil || $0.lon == nil }) {
            problems.append("distance milestones need coordinates")
        }
        if metric == .elevation, milestones.contains(where: { $0.altitude == nil }) {
            problems.append("elevation milestones need an altitude")
        }
        return problems
    }
}

public enum JourneyCatalog {
    /// Bundled journeys, in the order they're offered.
    public static let bundled: [Journey] = {
        let order = ["zurich-rome", "hadrians-wall", "camino-frances", "kilimanjaro", "everest"]
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "journeys") ?? []
        let decoder = JSONDecoder()
        let journeys = urls.compactMap { try? decoder.decode(Journey.self, from: Data(contentsOf: $0)) }
        return journeys.sorted { (order.firstIndex(of: $0.id) ?? 99, $0.title) < (order.firstIndex(of: $1.id) ?? 99, $1.title) }
    }()

    public static func journey(id: String) -> Journey? { bundled.first { $0.id == id } }
}
