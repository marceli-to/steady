import SwiftUI
import WidgetKit
import SteadyKit

@main
struct SteadyWidgets: WidgetBundle {
    var body: some Widget {
        JourneyWidget()
        YearWidget()
    }
}

// MARK: Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Widgets show the last snapshot the app wrote. The app refreshes it on open and when Health
/// wakes it with new steps; the timeline just asks again a few times a day.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? .placeholder
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder)
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: Journey: medium, lock screen rectangular and circular

struct JourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "journey", provider: SnapshotProvider()) { entry in
            JourneyWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Journey")
        .description("Where your everyday walking has taken you.")
        .supportedFamilies([.systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: This year: small

struct YearWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "year", provider: SnapshotProvider()) { entry in
            YearWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("This year")
        .description("How far everyday life has carried you this year.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: Previews

#Preview("Medium", as: .systemMedium) { JourneyWidget() } timeline: {
    SnapshotEntry(date: .now, snapshot: .placeholder)
}

#Preview("Small", as: .systemSmall) { YearWidget() } timeline: {
    SnapshotEntry(date: .now, snapshot: .placeholder)
}

#Preview("Lock rectangular", as: .accessoryRectangular) { JourneyWidget() } timeline: {
    SnapshotEntry(date: .now, snapshot: .placeholder)
}

#Preview("Lock circular", as: .accessoryCircular) { JourneyWidget() } timeline: {
    SnapshotEntry(date: .now, snapshot: .placeholder)
}
