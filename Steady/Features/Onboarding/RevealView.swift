import SwiftUI
import SteadyKit

/// The first big number. Slow, quiet, a little dramatic.
struct RevealView: View {
    @Environment(AppModel.self) private var model
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            switch model.syncState {
            case .idle, .syncing:
                ReadingView(state: model.syncState)
                    .transition(.opacity)
            case .failed(let message):
                NothingToShowView(message: message, onRetry: model.refresh, onSkip: onFinish)
            case .finished where !model.hasHistory:
                NothingToShowView(message: nil, onRetry: model.refresh, onSkip: onFinish)
            case .finished:
                RevealContent(onFinish: onFinish)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: model.syncState)
        .environment(\.colorScheme, .dark)
        .task {
            if model.syncState == .idle { model.refresh() }
        }
    }
}

/// While history loads: the years ticking by, nothing else.
private struct ReadingView: View {
    let state: AppModel.SyncState

    var body: some View {
        VStack(spacing: 14) {
            Caption("Reading your steps")
            if case let .syncing(_, year) = state {
                Text(String(year))
                    .font(.manrope(34, .bold, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(year)))
                    .animation(.easeInOut(duration: 0.4), value: year)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RevealContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onFinish: () -> Void

    @State private var shownDistance: Double = 0
    @State private var stage = 0          // 0 nothing · 1 since · 2 number · 3 route · 4 elevation · 5 actions
    @State private var routeProgress: Double = 0
    @State private var sharing = false

    var body: some View {
        let summary = model.allTime
        let formatter = model.formatter
        let comparison = model.distanceComparison(for: summary.distance)
        let elevation = model.elevationComparison(for: summary.elevation)

        ScrollsWhenLarge {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Caption(sinceLabel(summary.firstDay))
                .opacity(stage >= 1 ? 1 : 0)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                CountingText(value: shownDistance) { formatter.distanceNumber($0) }
                    .font(.manrope(84, .extraBold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(Theme.ink)
                Text(model.unit.symbol)
                    .font(.manrope(28, .bold, relativeTo: .title))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 12)
            .opacity(stage >= 2 ? 1 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("About \(formatter.distance(summary.distance))")

            Text("walked without noticing")
                .font(.manrope(19, .medium, relativeTo: .title3))
                .foregroundStyle(Theme.muted)
                .opacity(stage >= 2 ? 1 : 0)

            if let comparison {
                VStack(alignment: .leading, spacing: 14) {
                    RouteArc(from: routeLabels(comparison).from, to: routeLabels(comparison).to, progress: routeProgress)
                    Text(formatter.comparison(comparison))
                        .font(.manrope(24, .bold, relativeTo: .title2))
                        .foregroundStyle(Theme.accent)
                        .opacity(routeProgress >= 0.999 ? 1 : 0)
                        .accessibilityLabel(formatter.spokenComparison(comparison))
                }
                .padding(.top, 48)
                .opacity(stage >= 3 ? 1 : 0)
            }

            if summary.elevation > 0 {
                HStack(spacing: 8) {
                    Text("\(formatter.height(summary.elevation)) climbed")
                    if let elevation { Text("·"); Text(formatter.comparison(elevation)) }
                }
                .font(.mono(13, relativeTo: .footnote))
                .foregroundStyle(Theme.muted)
                .padding(.top, 28)
                .opacity(stage >= 4 ? 1 : 0)
                .accessibilityElement(children: .combine)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Share this") { sharing = true }
                    .buttonStyle(.steadyQuiet)
                Button("Start a journey", action: onFinish)
                    .buttonStyle(.steady)
                Text(model.includeWorkouts ? "Workouts included" : "Everyday walking only, no workouts counted")
                    .font(.mono(11, relativeTo: .caption2))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            .opacity(stage >= 5 ? 1 : 0)
            .allowsHitTesting(stage >= 5)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 20)
        }
        .task { await play(to: summary.distance) }
        .sheet(isPresented: $sharing) { StoryShareSheet() }
    }

    private func play(to distance: Double) async {
        if reduceMotion {
            shownDistance = distance
            routeProgress = 1
            withAnimation(.easeIn(duration: 0.6)) { stage = 5 }
            return
        }
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }

        await pause(0.6)
        withAnimation(.easeIn(duration: 1.2)) { stage = 1 }
        await pause(1.4)
        withAnimation(.easeIn(duration: 0.6)) { stage = 2 }
        withAnimation(.timingCurve(0.2, 0.0, 0.1, 1.0, duration: 3.6)) { shownDistance = distance }
        await pause(4.0)
        withAnimation(.easeIn(duration: 0.6)) { stage = 3 }
        withAnimation(.easeInOut(duration: 2.4).delay(0.3)) { routeProgress = 1 }
        await pause(3.2)
        withAnimation(.easeIn(duration: 1.0)) { stage = 4 }
        await pause(1.6)
        withAnimation(.easeIn(duration: 0.8)) { stage = 5 }
    }

    private func sinceLabel(_ first: Date?) -> String {
        guard let first else { return "All your steps" }
        return "Since " + first.formatted(.dateTime.month(.wide).year())
    }

    private func routeLabels(_ comparison: DistanceComparison) -> (from: String, to: String) {
        switch comparison {
        case let .route(from, to, _): (from.name, to.name)
        case .aroundTheWorld: (model.homePlace?.name ?? "Home", "around the world")
        case .towardsMoon: ("Earth", "the Moon")
        }
    }
}

/// No data, or Health said nothing. Calm, never a zero.
private struct NothingToShowView: View {
    let message: String?
    let onRetry: () -> Void
    let onSkip: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollsWhenLarge {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("No steps to show yet")
                .font(.manrope(30, .bold, relativeTo: .title))
                .foregroundStyle(Theme.ink)
            Text(message ?? "Health didn't share any walking data with steady. If you said no earlier, you can change that in Health: tap your picture, then Apps, then steady.")
                .font(.manrope(17, relativeTo: .body))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Open Health") {
                if let url = URL(string: "x-apple-health://") { openURL(url) }
            }
            .buttonStyle(.steadyQuiet)
            Button("Try again", action: onRetry)
                .buttonStyle(.steady)
            Button("Continue without data", action: onSkip)
                .font(.manrope(15, .medium))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 20)
        }
    }
}
