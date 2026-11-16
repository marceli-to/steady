import Foundation

public struct Place: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var name: String
    public var country: String
    public var lat: Double
    public var lon: Double
    /// 1 = known everywhere, 3 = known locally. Used to break near-ties.
    public var rank: Int
    /// False for places nobody lives in (the South Pole, Uluru). They can be comparisons, not homes.
    public var home: Bool

    public init(id: String, name: String, country: String, lat: Double, lon: Double, rank: Int = 2, home: Bool = true) {
        self.id = id
        self.name = name
        self.country = country
        self.lat = lat
        self.lon = lon
        self.rank = rank
        self.home = home
    }

    enum CodingKeys: String, CodingKey { case id, name, country, lat, lon, rank, home }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        country = try c.decode(String.self, forKey: .country)
        lat = try c.decode(Double.self, forKey: .lat)
        lon = try c.decode(Double.self, forKey: .lon)
        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 2
        home = try c.decodeIfPresent(Bool.self, forKey: .home) ?? true
    }
}

public struct Landmark: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    /// For sentences: "the Matterhorn".
    public var name: String
    /// For compact labels: "Matterhorn 2.3×".
    public var short: String
    public var metres: Double

    public init(id: String, name: String, short: String, metres: Double) {
        self.id = id
        self.name = name
        self.short = short
        self.metres = metres
    }
}

/// The places and landmarks bundled with the app.
public enum Atlas {
    public static let places: [Place] = load("places")
    public static let landmarks: [Landmark] = load("landmarks").sorted { $0.metres < $1.metres }
    public static var homePlaces: [Place] { places.filter(\.home) }

    public static func place(id: String) -> Place? { places.first { $0.id == id } }

    private static func load<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([T].self, from: data) else {
            assertionFailure("Missing or invalid bundled \(name).json")
            return []
        }
        return decoded
    }
}
