import Foundation
import Observation
import SwiftData
import WidgetKit
import UserNotifications
import SteadyKit

/// App-wide state: settings, the cached history, journeys and the numbers derived from them.
@Observable
@MainActor
final class AppModel {
    enum SyncState: Equatable {
        case idle
        case syncing(progress: Double, year: Int)
        case finished
        case failed(String)
    }

    // MARK: Settings (persisted in UserDefaults)

    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) } }
    var homePlaceID: String? { didSet { defaults.set(homePlaceID, forKey: Keys.home); publishWidgets() } }
    var includeWorkouts: Bool { didSet { defaults.set(includeWorkouts, forKey: Keys.workouts); journeysChanged() } }
    var unit: DistanceUnit { didSet { defaults.set(unit.rawValue, forKey: Keys.unit); publishWidgets() } }
    /// Off by default: share cards leave out the home city, and a journey start near it.
    var showsHomeCityOnCards: Bool { didSet { defaults.set(showsHomeCityOnCards, forKey: Keys.homeOnCards) } }
    /// Off by default: one quiet notification when a new postcard arrives.
    private(set) var postcardNotifications: Bool { didSet { defaults.set(postcardNotifications, forKey: Keys.notifications) } }

    /// Set to open the journeys sheet from elsewhere (the reveal's "Start a journey").
    var presentsJourneys = false

    // MARK: Data

    private(set) var days: [DayTotals] = []
    private(set) var runs: [JourneyRun] = []
    /// Newest first.
    private(set) var postcards: [Postcard] = []
    private(set) var syncState: SyncState = .idle
    let usesMockData: Bool

    private let source: any HealthDataSource
    private let store: HistoryStore
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let picker = ComparisonPicker()
    private var syncTask: Task<Void, Never>?

    init(source: any HealthDataSource, usesMockData: Bool, container: ModelContainer,
         defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.source = source
        self.usesMockData = usesMockData
        self.defaults = defaults
        self.calendar = calendar
        self.store = HistoryStore(container: container,
                                  loader: HistoryLoader(source: source, calendar: calendar))
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        homePlaceID = defaults.string(forKey: Keys.home)
        includeWorkouts = defaults.bool(forKey: Keys.workouts)
        unit = defaults.string(forKey: Keys.unit).flatMap(DistanceUnit.init(rawValue:)) ?? .localeDefault
        showsHomeCityOnCards = defaults.bool(forKey: Keys.homeOnCards)
        postcardNotifications = defaults.bool(forKey: Keys.notifications)
        days = (try? store.cachedDays()) ?? []
        runs = fetchRuns()
        postcards = fetchPostcards()
    }

    private var context: ModelContext { store.context }

    // MARK: Totals and comparisons

    var homePlace: Place? { homePlaceID.flatMap(Atlas.place(id:)) }
    var formatter: HonestFormatter { HonestFormatter(unit: unit) }
    var allTime: MovementSummary { MovementSummary(days: days, includingWorkouts: includeWorkouts) }
    var thisYear: MovementSummary { MovementSummary.year(containing: .now, days: days, includingWorkouts: includeWorkouts, calendar: calendar) }
    var hasHistory: Bool { allTime.daysWithData > 0 }

    func distanceComparison(for metres: Double) -> DistanceComparison? {
        homePlace.flatMap { picker.distance(metres, from: $0) }
    }

    func elevationComparison(for metres: Double) -> ElevationComparison? {
        picker.elevation(metres)
    }

    // MARK: Journeys

    var activeRun: JourneyRun? { runs.first { $0.finishedOn == nil && $0.journey != nil } }
    var finishedRuns: [JourneyRun] {
        runs.filter { $0.finishedOn != nil }.sorted { ($0.finishedOn ?? .distantPast) > ($1.finishedOn ?? .distantPast) }
    }

    func progress(of run: JourneyRun) -> JourneyProgress? {
        guard let journey = run.journey else { return nil }
        return JourneyTracker(calendar: calendar)
            .progress(of: journey, startedOn: run.startedOn, days: days, includingWorkouts: includeWorkouts)
    }

    var activeProgress: JourneyProgress? { activeRun.flatMap(progress(of:)) }

    /// Completes "At this pace you'll arrive …", or nil when there's no recent pace to go by.
    func arrivalPhrase(for progress: JourneyProgress, today: Date = .now) -> String? {
        let estimator = ArrivalEstimator(calendar: calendar)
        let pace = estimator.dailyPace(for: progress.journey.metric, days: days, includingWorkouts: includeWorkouts, today: today)
        guard let arrival = estimator.arrival(remaining: progress.remaining, pace: pace, today: today) else { return nil }
        return ArrivalPhrase(calendar: calendar).phrase(for: arrival, today: today)
    }

    /// "214 of ~900 km" / "6,210 of 8,849 m"
    func progressText(_ progress: JourneyProgress, separator: String = " of ") -> String {
        let parts = amounts(progress)
        return "\(parts.done)\(separator)\(parts.total) \(parts.unit)"
    }

    func amounts(_ progress: JourneyProgress) -> (done: String, total: String, unit: String) {
        let f = formatter
        switch progress.journey.metric {
        case .distance:
            return (f.distanceNumber(progress.done), "~" + f.distanceNumber(progress.journey.total), unit.symbol)
        case .elevation:
            return (f.heightNumber(progress.done), f.exactHeightNumber(progress.journey.total), unit.heightSymbol)
        }
    }

    /// Starts a journey today. Only one runs at a time; an unfinished one is let go.
    func start(_ journey: Journey, on date: Date = .now) {
        if let current = activeRun { context.delete(current) }
        context.insert(JourneyRun(journey: journey, startedOn: calendar.startOfDay(for: date)))
        try? context.save()
        runs = fetchRuns()
        journeysChanged()
    }

    private func fetchRuns() -> [JourneyRun] {
        (try? context.fetch(FetchDescriptor<JourneyRun>(sortBy: [SortDescriptor(\.startedOn)]))) ?? []
    }

    /// Writes postcards, marks arrivals and refreshes widgets after history or settings change.
    private func journeysChanged() {
        if let run = activeRun, let progress = progress(of: run) {
            let written = writePostcards(for: run, progress: progress)
            if let finished = progress.finishedOn { run.finishedOn = finished }
            try? context.save()
            runs = fetchRuns()
            postcards = fetchPostcards()
            notify(about: written)
        }
        publishWidgets()
    }

    // MARK: Postcards

    /// The newest postcard not opened yet, for the quiet line on Home.
    var unseenPostcard: Postcard? { postcards.first { !$0.seen } }

    func markSeen(_ postcard: Postcard) {
        guard !postcard.seen else { return }
        postcard.seen = true
        try? context.save()
    }

    /// One postcard per milestone reached, dated by the history. Safe to call on every refresh.
    private func writePostcards(for run: JourneyRun, progress: JourneyProgress) -> [Postcard] {
        let existing = Set(run.postcards.map(\.milestoneID))
        return PostcardPlanner.newPostcards(for: progress, runID: run.id, existing: existing, includedWorkouts: includeWorkouts)
            .map { payload in
                let postcard = Postcard(payload)
                context.insert(postcard)
                postcard.run = run
                return postcard
            }
    }

    private func fetchPostcards() -> [Postcard] {
        let descriptor = FetchDescriptor<Postcard>(sortBy: [SortDescriptor(\.reachedOn, order: .reverse),
                                                            SortDescriptor(\.progress, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func postcardContent(_ postcard: Postcard) -> PostcardContent? {
        guard let journey = postcard.journey else { return nil }
        return ShareCards.postcard(postcard.payload, journey: journey, home: homePlace,
                                   showsHomeCity: showsHomeCityOnCards, formatter: formatter)
    }

    var storyContent: StoryCardContent {
        let summary = allTime
        return ShareCards.story(summary: summary, comparison: distanceComparison(for: summary.distance),
                                elevation: elevationComparison(for: summary.elevation), home: homePlace,
                                showsHomeCity: showsHomeCityOnCards, formatter: formatter, calendar: calendar)
    }

    /// Turns postcard notifications on (asking permission first) or off.
    func setPostcardNotifications(_ on: Bool) async {
        guard on else { postcardNotifications = false; return }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        postcardNotifications = granted
    }

    /// At most one notification per refresh, and only for something recent: a journey started
    /// in the past, or a long time away, shouldn't bring a pile of old news.
    private func notify(about written: [Postcard], now: Date = .now) {
        guard postcardNotifications,
              let latest = written.max(by: { $0.progress < $1.progress }),
              let milestone = latest.milestone, let journey = latest.journey,
              let cutoff = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now)),
              latest.reachedOn >= cutoff else { return }
        let content = UNMutableNotificationContent()
        content.title = journey.metric == .distance ? "A postcard from \(milestone.name)" : "You reached \(milestone.name)"
        content.body = "Day \(latest.dayNumber) of \(journey.title)."
        let request = UNNotificationRequest(identifier: latest.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Sync

    func requestAccess() async {
        do {
            try await source.requestAuthorization()
        } catch {
            syncState = .failed("Health isn't available on this device.")
        }
    }

    /// Starts a sync unless one is already running. Safe to call on every foreground.
    func refresh() {
        guard syncTask == nil else { return }
        syncTask = Task {
            defer { syncTask = nil }
            syncState = .syncing(progress: 0, year: calendar.component(.year, from: .now))
            do {
                days = try await store.sync { [weak self] progress, year in
                    self?.syncState = .syncing(progress: progress, year: year)
                }
                syncState = .finished
                journeysChanged()
            } catch {
                syncState = .failed(error.localizedDescription)
            }
        }
    }

    /// Waits for a running sync, if any.
    func waitForSync() async {
        await syncTask?.value
    }

    func readEverythingAgain() {
        try? store.reset()
        days = []
        refresh()
    }

    /// Hourly at best, Health wakes the app when new steps arrive; widgets follow.
    func startBackgroundUpdates() {
        guard let health = source as? HealthKitDataSource else { return }
        health.observeNewSteps { [weak self] in
            await MainActor.run { self?.refresh() }
            await self?.waitForSync()
        }
    }

    // MARK: Widgets

    func publishWidgets() {
        widgetSnapshot().save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func widgetSnapshot(now: Date = .now) -> WidgetSnapshot {
        let year = thisYear
        let journey = activeProgress.map { progress in
            let parts = amounts(progress)
            return WidgetSnapshot.JourneyInfo(
                title: progress.journey.title,
                destination: progress.journey.destination,
                whereabouts: progress.whereabouts.shortPhrase,
                done: parts.done,
                total: parts.total,
                unit: parts.unit,
                fraction: progress.fraction,
                stops: progress.journey.milestones.dropFirst().dropLast().map { $0.at / progress.journey.total }
            )
        }
        return WidgetSnapshot(
            updatedAt: now,
            journey: journey,
            yearDistance: formatter.distanceNumber(year.distance),
            unit: unit.symbol,
            yearComparison: distanceComparison(for: year.distance).map(formatter.comparison)
        )
    }

    private enum Keys {
        static let onboarded = "hasOnboarded"
        static let home = "homePlaceID"
        static let workouts = "includeWorkouts"
        static let unit = "unit"
        static let homeOnCards = "showsHomeCityOnCards"
        static let notifications = "postcardNotifications"
    }
}

extension AppModel {
    /// The right data source for where we're running. The simulator has no step history,
    /// so it gets mock data; on a device `-mockHealth` forces mock data too.
    static func makeSource() -> (any HealthDataSource, isMock: Bool) {
        let args = ProcessInfo.processInfo.arguments
        #if targetEnvironment(simulator)
        let wantsMock = !args.contains("-realHealth")
        #else
        let wantsMock = args.contains("-mockHealth")
        #endif
        if wantsMock || !HealthKitDataSource.isAvailable {
            var mock = MockHistory.make()
            mock.latency = .milliseconds(250)
            return (mock, true)
        }
        return (HealthKitDataSource(), false)
    }

    /// `-demoJourney <id>:<days ago>` starts a journey in the past, for screenshots.
    func applyDemoArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-demoJourney"), args.indices.contains(index + 1) else { return }
        let parts = args[index + 1].split(separator: ":")
        guard let journey = JourneyCatalog.journey(id: String(parts[0])) else { return }
        let daysAgo = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        start(journey, on: calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now)
    }
}
