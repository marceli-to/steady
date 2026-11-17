import Foundation

/// The words and numbers on the story card (1080×1920, dark). The views only lay them out.
public struct StoryCardContent: Sendable, Hashable {
    /// "since March 2019"
    public var since: String
    /// "11,240"
    public var number: String
    public var unit: String
    /// Label at the start of the arc; nil when the home city stays private.
    public var routeFrom: String?
    /// Label at the end of the arc; nil when there's no comparison (and so no arc).
    public var routeTo: String?
    /// "That's Zürich to Beijing — just from everyday life."
    public var sentence: String?
    /// "Plus 41,200 m climbed"
    public var climbed: String?
    /// "Everest 4.7×"
    public var climbedComparison: String?

    public init(since: String, number: String, unit: String, routeFrom: String?, routeTo: String?,
                sentence: String?, climbed: String?, climbedComparison: String?) {
        self.since = since
        self.number = number
        self.unit = unit
        self.routeFrom = routeFrom
        self.routeTo = routeTo
        self.sentence = sentence
        self.climbed = climbed
        self.climbedComparison = climbedComparison
    }
}

/// The words on a postcard (1080×1080, light).
public struct PostcardContent: Sendable, Hashable {
    public struct Stop: Sendable, Hashable, Identifiable {
        public enum State: Sendable, Hashable { case passed, current, ahead }
        public var id: String
        public var name: String
        /// 0 at the top of the route line, 1 at the bottom.
        public var position: Double
        public var state: State
        public var isEnd: Bool
    }

    /// "Postcard · Day 63"
    public var header: String
    /// "Zürich → Rome", or "To Rome" when the start stays private.
    public var title: String
    /// "Arrived in Bellinzona."
    public var headline: String
    /// "214 km of about 900 — walked to work, to the shop, up the stairs."
    public var body: String
    /// "no workouts counted"
    public var footnote: String
    /// From the first milestone shown to the finish.
    public var stops: [Stop]
    /// Elevation journeys climb: the finish is drawn at the top.
    public var climbs: Bool
    /// True when the journey's start was left off because it's near home.
    public var hidesStart: Bool
}

public enum ShareCards {
    /// A journey start this close to home gives home away.
    public static let homeRadius: Double = 50_000

    public static func story(summary: MovementSummary, comparison: DistanceComparison?,
                             elevation: ElevationComparison?, home: Place?, showsHomeCity: Bool,
                             formatter: HonestFormatter, calendar: Calendar = .current) -> StoryCardContent {
        var since = "since you started"
        if let first = summary.firstDay {
            var style = Date.FormatStyle(locale: formatter.locale, calendar: calendar).month(.wide).year()
            style.timeZone = calendar.timeZone
            since = "since " + first.formatted(style)
        }

        var from: String?, to: String?, sentence: String?
        let homeName = showsHomeCity ? home?.name : nil
        switch comparison {
        case let .route(origin, destination, _)?:
            let start = showsHomeCity ? origin.name : nil
            from = start
            to = destination.name
            sentence = start.map { "That’s \($0) to \(destination.name) — just from everyday life." }
                ?? "That’s as far as from home to \(destination.name) — just from everyday life."
        case let .aroundTheWorld(times)?:
            from = homeName
            to = "around the world"
            sentence = times < 0.95
                ? "That’s \(formatter.percent(times)) of the way around the world — just from everyday life."
                : "That’s \(formatter.multiple(times)) around the world — just from everyday life."
        case let .towardsMoon(fraction)?:
            from = "Earth"
            to = "the Moon"
            sentence = "That’s \(formatter.comparisonBody(.towardsMoon(fraction: fraction))) — just from everyday life."
        case nil:
            break
        }

        return StoryCardContent(
            since: since,
            number: formatter.distanceNumber(summary.distance),
            unit: formatter.unit.symbol,
            routeFrom: from,
            routeTo: to,
            sentence: sentence,
            climbed: summary.elevation > 0 ? "Plus \(formatter.height(summary.elevation)) climbed" : nil,
            climbedComparison: elevation.map(formatter.comparisonBody)
        )
    }

    /// - Parameter home: the person's home city, used only to decide whether the journey's
    ///   start would give it away.
    public static func postcard(_ payload: PostcardPayload, journey: Journey, home: Place?, showsHomeCity: Bool,
                                formatter: HonestFormatter) -> PostcardContent? {
        guard let reachedIndex = journey.milestones.firstIndex(where: { $0.id == payload.milestoneID }) else { return nil }
        let milestone = journey.milestones[reachedIndex]
        let isFinish = reachedIndex == journey.milestones.count - 1
        let hidesStart = !showsHomeCity && startIsNearHome(journey, home: home)

        let headline: String
        let body: String
        switch journey.metric {
        case .distance:
            headline = "Arrived in \(milestone.name)."
            let done = formatter.distanceNumber(milestone.at)
            let walked = payload.includedWorkouts ? "walking, running, every step of it." : "walked to work, to the shop, up the stairs."
            body = isFinish
                ? "All \(done) \(formatter.unit.symbol) of it — \(walked)"
                : "\(done) \(formatter.unit.symbol) of about \(formatter.distanceNumber(journey.total)) — \(walked)"
        case .elevation:
            headline = "Reached \(milestone.name)."
            let climbed = payload.includedWorkouts ? "stairs, hills and hikes." : "one flight of stairs at a time."
            let done = formatter.exactHeightNumber(milestone.at)
            body = isFinish
                ? "All \(done) \(formatter.unit.heightSymbol) of it — \(climbed)"
                : "\(done) \(formatter.unit.heightSymbol) of \(formatter.exactHeightNumber(journey.total)) — \(climbed)"
        }

        let shown = Array(journey.milestones.enumerated()).dropFirst(hidesStart ? 1 : 0)
        let positions = spread(shown.map(\.element.at))
        let stops = zip(shown, positions).map { item, position in
            let (index, stop) = item
            let state: PostcardContent.Stop.State = index < reachedIndex ? .passed : (index == reachedIndex ? .current : .ahead)
            return PostcardContent.Stop(id: stop.id, name: stop.name, position: position, state: state,
                                        isEnd: index == shown.first?.offset || index == journey.milestones.count - 1)
        }

        return PostcardContent(
            header: "Postcard · Day \(payload.dayNumber)",
            title: hidesStart ? "To \(journey.destination)" : journey.title,
            headline: headline,
            body: body,
            footnote: payload.includedWorkouts ? "workouts included" : "no workouts counted",
            stops: stops,
            climbs: journey.metric == .elevation,
            hidesStart: hidesStart
        )
    }

    public static func startIsNearHome(_ journey: Journey, home: Place?) -> Bool {
        guard let home, let lat = journey.start.lat, let lon = journey.start.lon else { return false }
        return GreatCircle.distance(lat1: lat, lon1: lon, lat2: home.lat, lon2: home.lon) <= homeRadius
    }

    /// Positions 0…1 for stops at these cumulative distances: half true to scale, half evenly
    /// spaced, so close milestones don't collide and long stretches still look long.
    static func spread(_ values: [Double]) -> [Double] {
        guard let first = values.first, let last = values.last, values.count > 1, last > first else {
            return values.map { _ in 0 }
        }
        let count = Double(values.count - 1)
        return values.enumerated().map { index, value in
            0.5 * (value - first) / (last - first) + 0.5 * Double(index) / count
        }
    }
}
