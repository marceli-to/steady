import SwiftUI
import SteadyKit

/// The active journey, then this year and all time. Nothing else.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false
    @State private var showsPostcards = false
    @State private var sharesStory = false
    @State private var openPostcard: Postcard?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    if let progress = model.activeProgress {
                        JourneyBlock(progress: progress) { openPostcard = $0 }
                    } else {
                        NoJourneyBlock()
                    }
                    VStack(alignment: .leading, spacing: 36) {
                        TotalBlock(title: "This year", summary: model.thisYear)
                        TotalBlock(title: sinceTitle, summary: model.allTime) { sharesStory = true }
                    }
                    if case .syncing = model.syncState {
                        Caption("Reading new steps…")
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.ground.ignoresSafeArea())
            .refreshable {
                model.refresh()
                await model.waitForSync()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("steady")
                        .font(.manrope(22, .extraBold, relativeTo: .title2))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showsPostcards = true } label: {
                        Image(systemName: "envelope")
                    }
                    .accessibilityLabel("Postcards")
                    Button { model.presentsJourneys = true } label: {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .accessibilityLabel("Journeys")
                    Button { showsSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .tint(Theme.ink)
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .sheet(isPresented: $model.presentsJourneys) { JourneysView() }
            .sheet(isPresented: $showsPostcards) { PostcardsView() }
            .sheet(isPresented: $sharesStory) { StoryShareSheet() }
            .sheet(item: $openPostcard) { PostcardSheet(postcard: $0) }
        }
    }

    private var sinceTitle: String {
        guard let first = model.allTime.firstDay else { return "All time" }
        return "Since " + first.formatted(.dateTime.year())
    }
}

private struct JourneyBlock: View {
    @Environment(AppModel.self) private var model
    let progress: JourneyProgress
    var onOpenPostcard: (Postcard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress.journey.title)
                    .font(.manrope(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(Int((progress.fraction * 100).rounded(.down)))%")
                    .font(.mono(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(Theme.muted)
            }
            Text(progress.whereabouts.phrase)
                .font(.manrope(36, .extraBold, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.progressText(progress))
                .font(.manrope(19, .medium, relativeTo: .title3))
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
                .padding(.top, 2)

            RouteDrawing(journey: progress.journey, done: progress.done)
                .frame(height: progress.journey.metric == .distance ? 280 : 220)
                .padding(.top, 24)

            Text(arrivalSentence)
                .font(.manrope(17, .medium, relativeTo: .body))
                .foregroundStyle(Theme.ink)
                .padding(.top, 20)
                .fixedSize(horizontal: false, vertical: true)
            Caption(dayLine)
                .padding(.top, 8)

            if let postcard = model.unseenPostcard, let milestone = postcard.milestone {
                Button { onOpenPostcard(postcard) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .accessibilityHidden(true)
                        Text("A postcard from \(milestone.name)")
                            .font(.manrope(17, .bold, relativeTo: .body))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
            }
        }
    }

    private var arrivalSentence: String {
        if progress.isFinished { return "You made it." }
        guard let phrase = model.arrivalPhrase(for: progress) else {
            return "Walk a little and steady will estimate your arrival."
        }
        return "At this pace you'll arrive \(phrase)."
    }

    private var dayLine: String {
        let day = JourneyTracker().dayNumber(of: .now, from: progress.startedOn)
        let next = progress.next.map { " · next: \($0.name)" } ?? ""
        return "Day \(day)\(next)"
    }
}

private struct NoJourneyBlock: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Caption("Journey")
            if let last = model.finishedRuns.first, let journey = last.journey {
                Text("You arrived in \(journey.finish.name).")
                    .font(.manrope(30, .extraBold, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                Text("Finished \(last.finishedOn?.formatted(date: .long, time: .omitted) ?? ""). Where next?")
                    .font(.manrope(17, relativeTo: .body))
                    .foregroundStyle(Theme.muted)
            } else {
                Text("Point your everyday walking somewhere: Rome, Santiago, the top of Everest. It adds up slowly, over months.")
                    .font(.manrope(19, .medium, relativeTo: .title3))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Choose a journey") { model.presentsJourneys = true }
                .buttonStyle(.steady)
                .padding(.top, 8)
        }
    }
}

private struct TotalBlock: View {
    @Environment(AppModel.self) private var model
    let title: String
    let summary: MovementSummary
    var onShare: (() -> Void)?

    var body: some View {
        let formatter = model.formatter
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Caption(title)
                Spacer()
                if let onShare, summary.distance > 0 {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(minWidth: 44, minHeight: 32)
                    }
                    .accessibilityLabel("Share")
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatter.distanceNumber(summary.distance))
                    .font(.manrope(40, .extraBold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(model.unit.symbol)
                    .font(.manrope(19, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("About \(formatter.distance(summary.distance))")

            if let comparison = model.distanceComparison(for: summary.distance) {
                Text(formatter.comparison(comparison))
                    .font(.manrope(17, .bold, relativeTo: .body))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel(formatter.spokenComparison(comparison))
            }
            if summary.elevation > 0 {
                let elevation = model.elevationComparison(for: summary.elevation)
                Text("\(formatter.height(summary.elevation)) climbed" + (elevation.map { " · " + formatter.comparison($0) } ?? ""))
                    .font(.mono(12, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
        }
    }
}
