import Foundation
import Observation
import SwiftData
import SteadyKit

/// App-wide state: settings, the cached history and the numbers derived from it.
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
    var homePlaceID: String? { didSet { defaults.set(homePlaceID, forKey: Keys.home) } }
    var includeWorkouts: Bool { didSet { defaults.set(includeWorkouts, forKey: Keys.workouts) } }
    var unit: DistanceUnit { didSet { defaults.set(unit.rawValue, forKey: Keys.unit) } }

    // MARK: Data

    private(set) var days: [DayTotals] = []
    private(set) var syncState: SyncState = .idle
    let usesMockData: Bool

    private let source: any HealthDataSource
    private let store: HistoryStore
    private let defaults: UserDefaults
    private let picker = ComparisonPicker()
    private var syncTask: Task<Void, Never>?

    init(source: any HealthDataSource, usesMockData: Bool, container: ModelContainer,
         defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.source = source
        self.usesMockData = usesMockData
        self.defaults = defaults
        self.store = HistoryStore(container: container,
                                  loader: HistoryLoader(source: source, calendar: calendar))
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        homePlaceID = defaults.string(forKey: Keys.home)
        includeWorkouts = defaults.bool(forKey: Keys.workouts)
        unit = defaults.string(forKey: Keys.unit).flatMap(DistanceUnit.init(rawValue:)) ?? .localeDefault
        days = (try? store.cachedDays()) ?? []
    }

    // MARK: Derived

    var homePlace: Place? { homePlaceID.flatMap(Atlas.place(id:)) }
    var formatter: HonestFormatter { HonestFormatter(unit: unit) }
    var allTime: MovementSummary { MovementSummary(days: days, includingWorkouts: includeWorkouts) }
    var thisYear: MovementSummary { MovementSummary.year(containing: .now, days: days, includingWorkouts: includeWorkouts) }
    var hasHistory: Bool { allTime.daysWithData > 0 }

    func distanceComparison(for metres: Double) -> DistanceComparison? {
        homePlace.flatMap { picker.distance(metres, from: $0) }
    }

    func elevationComparison(for metres: Double) -> ElevationComparison? {
        picker.elevation(metres)
    }

    // MARK: Actions

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
            syncState = .syncing(progress: 0, year: Calendar.current.component(.year, from: .now))
            do {
                days = try await store.sync { [weak self] progress, year in
                    self?.syncState = .syncing(progress: progress, year: year)
                }
                syncState = .finished
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

    private enum Keys {
        static let onboarded = "hasOnboarded"
        static let home = "homePlaceID"
        static let workouts = "includeWorkouts"
        static let unit = "unit"
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
}
