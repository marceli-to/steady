import Foundation
import SwiftData
import SteadyKit

/// One cached day of Health data. Health stays the source of truth; this only saves re-reading years.
@Model
final class DayRecord {
    @Attribute(.unique) var day: Date
    var distance: Double
    var distanceInWorkouts: Double
    var flights: Double
    var flightsInWorkouts: Double
    var steps: Double
    var syncedAt: Date

    init(_ totals: DayTotals, syncedAt: Date) {
        day = totals.day
        distance = totals.distance
        distanceInWorkouts = totals.distanceInWorkouts
        flights = totals.flights
        flightsInWorkouts = totals.flightsInWorkouts
        steps = totals.steps
        self.syncedAt = syncedAt
    }

    func update(from totals: DayTotals, syncedAt: Date) {
        distance = totals.distance
        distanceInWorkouts = totals.distanceInWorkouts
        flights = totals.flights
        flightsInWorkouts = totals.flightsInWorkouts
        steps = totals.steps
        self.syncedAt = syncedAt
    }

    var totals: DayTotals {
        DayTotals(day: day, distance: distance, distanceInWorkouts: distanceInWorkouts,
                  flights: flights, flightsInWorkouts: flightsInWorkouts, steps: steps)
    }
}

/// Keeps the SwiftData cache in step with Health.
///
/// First sync reads everything, one calendar year at a time. Later syncs re-read the last
/// `overlapDays` days, because Apple Watch data can arrive late.
@MainActor
final class HistoryStore {
    /// Held so the context never outlives its container.
    let container: ModelContainer
    let loader: HistoryLoader
    var overlapDays = 10
    var context: ModelContext { container.mainContext }

    init(container: ModelContainer, loader: HistoryLoader) {
        self.container = container
        self.loader = loader
    }

    func cachedDays() throws -> [DayTotals] {
        try context.fetch(FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.day)])).map(\.totals)
    }

    /// - Parameter progress: called with values from 0 to 1 and the year being read.
    @discardableResult
    func sync(now: Date = .now, progress: (Double, Int) -> Void = { _, _ in }) async throws -> [DayTotals] {
        let calendar = loader.calendar
        let latest = try context.fetch(latestDescriptor).first?.day

        let start: Date
        if let latest {
            start = calendar.date(byAdding: .day, value: -overlapDays, to: latest) ?? latest
        } else if let first = try await loader.source.firstSampleDate() {
            start = calendar.startOfDay(for: first)
        } else {
            return []
        }
        guard start < now else { return try cachedDays() }

        let chunks = loader.yearlyChunks(of: DateInterval(start: start, end: now))
        for (index, chunk) in chunks.enumerated() {
            progress(Double(index) / Double(chunks.count), calendar.component(.year, from: chunk.start))
            let days = try await loader.loadDays(in: chunk)
            try upsert(days, replacing: chunk, syncedAt: now)
        }
        progress(1, calendar.component(.year, from: now))
        return try cachedDays()
    }

    /// Wipes the cache, for "read everything again".
    func reset() throws {
        try context.delete(model: DayRecord.self)
        try context.save()
    }

    private var latestDescriptor: FetchDescriptor<DayRecord> {
        var descriptor = FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.day, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    private func upsert(_ days: [DayTotals], replacing range: DateInterval, syncedAt: Date) throws {
        let start = loader.calendar.startOfDay(for: range.start)
        let end = range.end
        let existing = try context.fetch(FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.day >= start && $0.day < end }
        ))
        var byDay = Dictionary(existing.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })

        for totals in days {
            if let record = byDay.removeValue(forKey: totals.day) {
                record.update(from: totals, syncedAt: syncedAt)
            } else {
                context.insert(DayRecord(totals, syncedAt: syncedAt))
            }
        }
        // Days that disappeared from Health (deleted data) go from the cache too.
        for record in byDay.values { context.delete(record) }
        try context.save()
    }
}
