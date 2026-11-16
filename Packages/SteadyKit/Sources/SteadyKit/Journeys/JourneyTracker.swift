import Foundation

/// A milestone and the day it was reached.
public struct ReachedMilestone: Sendable, Hashable {
    public var milestone: Milestone
    public var date: Date
    /// Day N of the journey; the start day is day 1.
    public var dayNumber: Int
    /// Progress through the whole journey when it was reached, 0…1.
    public var fraction: Double
}

/// Where along the route someone is, in words.
public enum Whereabouts: Sendable, Hashable {
    case near(Milestone)
    case between(Milestone, Milestone)
    case arrived(Milestone, JourneyMetric)

    /// "near Bellinzona", "between Milano and Bologna", "arrived in Roma", "reached Summit"
    public var phrase: String {
        switch self {
        case .near(let m): "near \(m.name)"
        case let .between(a, b): "between \(a.name) and \(b.name)"
        case let .arrived(m, metric): metric == .distance ? "arrived in \(m.name)" : "reached \(m.name)"
        }
    }

    /// For tight spaces like widgets: "near Bellinzona", "past Gotthard".
    public var shortPhrase: String {
        if case let .between(a, _) = self { return "past \(a.name)" }
        return phrase
    }
}

public struct JourneyProgress: Sendable, Hashable {
    public var journey: Journey
    public var startedOn: Date
    /// Metres walked or climbed since the start, capped at the journey's total.
    public var done: Double
    public var reached: [ReachedMilestone]
    public var whereabouts: Whereabouts
    /// The day the finish was reached, if it has been.
    public var finishedOn: Date?

    public var fraction: Double { journey.total > 0 ? min(1, done / journey.total) : 0 }
    public var remaining: Double { max(0, journey.total - done) }
    public var isFinished: Bool { finishedOn != nil }
    public var lastReached: Milestone { reached.last?.milestone ?? journey.start }
    public var next: Milestone? { journey.milestones.first { $0.at > done } }
}

public struct JourneyTracker: Sendable {
    public var calendar: Calendar
    /// Within this share of a segment's length from a milestone, you're "near" it.
    public var nearShare = 0.1

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Walks the daily history from the start day, so milestones get the day they were really
    /// reached, even if the app wasn't opened then.
    public func progress(of journey: Journey, startedOn: Date, days: [DayTotals], includingWorkouts: Bool) -> JourneyProgress {
        let start = calendar.startOfDay(for: startedOn)
        var done = 0.0
        var reached: [ReachedMilestone] = [
            ReachedMilestone(milestone: journey.start, date: start, dayNumber: 1, fraction: 0)
        ]
        var nextIndex = 1
        var finishedOn: Date?

        for day in days.sorted(by: { $0.day < $1.day }) where day.day >= start {
            done += value(of: day, for: journey.metric, includingWorkouts: includingWorkouts)
            while nextIndex < journey.milestones.count, journey.milestones[nextIndex].at <= done {
                let milestone = journey.milestones[nextIndex]
                reached.append(ReachedMilestone(
                    milestone: milestone,
                    date: day.day,
                    dayNumber: dayNumber(of: day.day, from: start),
                    fraction: milestone.at / journey.total
                ))
                nextIndex += 1
            }
            if done >= journey.total {
                finishedOn = day.day
                break
            }
        }

        let capped = min(done, journey.total)
        return JourneyProgress(
            journey: journey,
            startedOn: start,
            done: capped,
            reached: reached,
            whereabouts: whereabouts(in: journey, at: capped),
            finishedOn: finishedOn
        )
    }

    public func whereabouts(in journey: Journey, at done: Double) -> Whereabouts {
        let stops = journey.milestones
        if done >= journey.total { return .arrived(journey.finish, journey.metric) }
        guard let nextIndex = stops.firstIndex(where: { $0.at > done }), nextIndex > 0 else {
            return .near(journey.start)
        }
        let previous = stops[nextIndex - 1], next = stops[nextIndex]
        let segment = next.at - previous.at
        if done - previous.at <= segment * nearShare { return .near(previous) }
        if next.at - done <= segment * nearShare { return .near(next) }
        return .between(previous, next)
    }

    public func dayNumber(of day: Date, from start: Date) -> Int {
        (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: day)).day ?? 0) + 1
    }

    func value(of day: DayTotals, for metric: JourneyMetric, includingWorkouts: Bool) -> Double {
        switch metric {
        case .distance: day.distance(includingWorkouts: includingWorkouts)
        case .elevation: day.elevation(includingWorkouts: includingWorkouts)
        }
    }
}

/// Estimated arrival from the recent pace.
public struct ArrivalEstimator: Sendable {
    public var calendar: Calendar
    public var window = 30
    /// Fewer days with data than this in the window, and we don't guess.
    public var minimumDaysWithData = 5

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Mean per day over the last `window` days. Days without any data (phone left at home,
    /// before the first sample) are skipped rather than counted as zero.
    public func dailyPace(for metric: JourneyMetric, days: [DayTotals], includingWorkouts: Bool, today: Date) -> Double? {
        let end = calendar.startOfDay(for: today)
        guard let start = calendar.date(byAdding: .day, value: -window, to: end) else { return nil }
        let recent = days.filter { $0.day > start && $0.day <= end && $0.hasData }
        guard recent.count >= minimumDaysWithData else { return nil }
        let tracker = JourneyTracker(calendar: calendar)
        let sum = recent.reduce(0) { $0 + tracker.value(of: $1, for: metric, includingWorkouts: includingWorkouts) }
        return sum / Double(recent.count)
    }

    /// The day of arrival, or nil when there's no pace to go by.
    public func arrival(remaining: Double, pace: Double?, today: Date) -> Date? {
        guard remaining > 0 else { return calendar.startOfDay(for: today) }
        guard let pace, pace > 0.0001 else { return nil }
        let days = Int((remaining / pace).rounded(.up))
        guard days < 365 * 200 else { return nil }
        return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: today))
    }
}

/// "in late March", "around August 2028", "in about 3 years".
public struct ArrivalPhrase: Sendable {
    public var calendar: Calendar
    public var locale: Locale

    public init(calendar: Calendar = .current, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    /// Completes "At this pace you'll arrive …".
    public func phrase(for arrival: Date, today: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: arrival)).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "tomorrow"
        case ..<14: return "in about \(days) days"
        case ..<270:
            let day = calendar.component(.day, from: arrival)
            let part = day <= 10 ? "early" : (day <= 20 ? "mid" : "late")
            return "in \(part) \(monthName(arrival))"
        case ..<730:
            return "around \(monthName(arrival)) \(calendar.component(.year, from: arrival))"
        default:
            let years = Int((Double(days) / 365.25).rounded())
            return "in about \(years) years"
        }
    }

    private func monthName(_ date: Date) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar).month(.wide)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
