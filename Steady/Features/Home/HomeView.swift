import SwiftUI
import SteadyKit

/// Phase 1 home: all time and this year, each with a comparison. Journeys arrive in phase 2.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 44) {
                    journeyPlaceholder
                    TotalBlock(title: "This year", summary: model.thisYear)
                    TotalBlock(title: sinceTitle, summary: model.allTime)
                    if case .syncing = model.syncState {
                        Caption("Reading new steps…")
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 24)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .tint(Theme.ink)
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showsSettings) { SettingsView() }
        }
    }

    private var sinceTitle: String {
        guard let first = model.allTime.firstDay else { return "All time" }
        return "Since " + first.formatted(.dateTime.year())
    }

    private var journeyPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("Journey")
            Text("Journeys arrive in the next build: walk to Rome, climb Everest, a little every day.")
                .font(.manrope(17, relativeTo: .body))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TotalBlock: View {
    @Environment(AppModel.self) private var model
    let title: String
    let summary: MovementSummary

    var body: some View {
        let formatter = model.formatter
        VStack(alignment: .leading, spacing: 6) {
            Caption(title)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatter.distanceNumber(summary.distance))
                    .font(.manrope(52, .extraBold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(model.unit.symbol)
                    .font(.manrope(22, .bold, relativeTo: .title2))
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("About \(formatter.distance(summary.distance))")

            if let comparison = model.distanceComparison(for: summary.distance) {
                Text(formatter.comparison(comparison))
                    .font(.manrope(19, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel(formatter.spokenComparison(comparison))
            }
            if summary.elevation > 0 {
                let elevation = model.elevationComparison(for: summary.elevation)
                Text("\(formatter.height(summary.elevation)) climbed" + (elevation.map { " · " + formatter.comparison($0) } ?? ""))
                    .font(.mono(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
        }
    }
}
