import SwiftUI
import WidgetKit
import SteadyKit

// Widget views, kept apart from the widget bundle so the app can show them in a debug gallery.

struct JourneyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        Group {
            if let journey = snapshot.journey {
                switch family {
                case .accessoryRectangular: LockRectangular(journey: journey)
                case .accessoryCircular: LockCircular(journey: journey)
                default: MediumJourney(journey: journey)
                }
            } else {
                NoJourney(family: family)
            }
        }
        .containerBackground(for: .widget) { Theme.card }
    }
}

struct MediumJourney: View {
    let journey: WidgetSnapshot.JourneyInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(journey.title)
                    .font(.manrope(15, .bold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(journey.percent)
                    .font(.manrope(14, .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 6)
            Text(journey.whereabouts)
                .font(.manrope(26, .extraBold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(journey.done) of \(journey.total) \(journey.unit)")
                .font(.manrope(15, .medium))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 10)
            LinearRoute(fraction: journey.fraction, stops: journey.stops, lineWidth: 2.5, positionSize: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(journey.title), \(journey.whereabouts), \(journey.done) of \(journey.total) \(journey.unit)")
    }
}

struct LockRectangular: View {
    let journey: WidgetSnapshot.JourneyInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("→ \(journey.destination) · \(journey.whereabouts)")
                .font(.manrope(15, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ProgressView(value: journey.fraction)
                .progressViewStyle(.linear)
            Text("\(journey.done) / \(journey.total) \(journey.unit)")
                .font(.mono(12))
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Towards \(journey.destination), \(journey.whereabouts), \(journey.done) of \(journey.total) \(journey.unit)")
    }
}

struct LockCircular: View {
    let journey: WidgetSnapshot.JourneyInfo

    var body: some View {
        Gauge(value: journey.fraction) {
            Text(journey.destination)
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(journey.destination)
                    .font(.manrope(12, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(journey.percent)
                    .font(.mono(10))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel("\(journey.destination), \(journey.percent) done")
    }
}

private struct NoJourney: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .accessibilityLabel("No journey yet")
        case .accessoryRectangular:
            Text("No journey yet. Open steady to choose one.")
                .font(.manrope(14, .bold))
        default:
            VStack(alignment: .leading, spacing: 6) {
                Caption("Journey")
                Spacer()
                Text("No journey yet")
                    .font(.manrope(24, .extraBold))
                    .foregroundStyle(Theme.ink)
                Text("Open steady to walk somewhere, slowly.")
                    .font(.manrope(14, .medium))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct YearWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Caption("This year", color: Theme.muted)
            Spacer(minLength: 6)
            ZStack {
                ArcShape()
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                GeometryReader { proxy in
                    Circle().fill(Theme.ink).frame(width: 9, height: 9)
                        .position(x: 8, y: proxy.size.height - 8)
                    Circle().fill(Theme.accent).frame(width: 10, height: 10)
                        .position(x: proxy.size.width - 8, y: proxy.size.height - 8)
                }
            }
            .frame(height: 30)
            .padding(.horizontal, -4)
            Spacer(minLength: 8)
            Text("\(snapshot.yearDistance) \(snapshot.unit)")
                .font(.manrope(30, .extraBold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let comparison = snapshot.yearComparison {
                Text(comparison)
                    .font(.manrope(13, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .environment(\.colorScheme, .dark)
        .containerBackground(for: .widget) { Color(red: 0x1E / 255, green: 0x26 / 255, blue: 0x21 / 255) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This year, about \(snapshot.yearDistance) \(snapshot.unit)" + (snapshot.yearComparison.map { ", \($0)" } ?? ""))
    }
}

