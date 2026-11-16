import SwiftUI
import SteadyKit

/// Pick a journey, look at its route, and keep finished ones as a small collection.
struct JourneysView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(JourneyCatalog.bundled) { journey in
                        NavigationLink(value: journey) { JourneyRow(journey: journey) }
                            .listRowBackground(Theme.ground)
                    }
                }
                if !model.finishedRuns.isEmpty {
                    Section {
                        ForEach(model.finishedRuns) { run in
                            FinishedRow(run: run).listRowBackground(Theme.ground)
                        }
                    } header: {
                        Caption("Finished")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("Journeys")
            .navigationDestination(for: Journey.self) { JourneyDetailView(journey: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
    }
}

private struct JourneyRow: View {
    @Environment(AppModel.self) private var model
    let journey: Journey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(journey.title)
                    .font(.manrope(19, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if model.activeRun?.journeyID == journey.id {
                    Caption("Current", color: Theme.accent)
                }
            }
            Text(journey.subtitle)
                .font(.manrope(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.muted)
            Text(totalText(journey, formatter: model.formatter))
                .font(.mono(12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }
}

private struct FinishedRow: View {
    @Environment(AppModel.self) private var model
    let run: JourneyRun

    var body: some View {
        if let journey = run.journey, let finished = run.finishedOn {
            let days = JourneyTracker().dayNumber(of: finished, from: run.startedOn)
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(journey.title)
                        .font(.manrope(17, .bold, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                    Text("Arrived \(finished.formatted(date: .abbreviated, time: .omitted)) · \(days) days")
                        .font(.mono(12))
                        .foregroundStyle(Theme.muted)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct JourneyDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let journey: Journey
    @State private var confirmsSwitch = false

    private var isCurrent: Bool { model.activeRun?.journeyID == journey.id }
    private var done: Double { isCurrent ? model.activeProgress?.done ?? 0 : 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(journey.subtitle)
                    .font(.manrope(17, relativeTo: .body))
                    .foregroundStyle(Theme.muted)
                Text(totalText(journey, formatter: model.formatter))
                    .font(.mono(13))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)

                RouteDrawing(journey: journey, done: done, labelsAll: journey.metric == .elevation)
                    .frame(height: journey.metric == .distance ? 300 : 240)
                    .padding(.vertical, 28)

                Caption("Milestones")
                    .padding(.bottom, 8)
                ForEach(journey.milestones) { milestone in
                    HStack {
                        Circle()
                            .fill(milestone.at <= done && isCurrent ? Theme.accent : Theme.faint)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(milestone.name)
                            .font(.manrope(17, .medium, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(amount(milestone.at))
                            .font(.mono(13))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }

                Text(howItCounts)
                    .font(.manrope(15, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(journey.title)
        .safeAreaInset(edge: .bottom) {
            Button(isCurrent ? "Your current journey" : "Start this journey") {
                if model.activeRun != nil { confirmsSwitch = true } else { startAndClose() }
            }
            .buttonStyle(.steady)
            .disabled(isCurrent)
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 8)
            .background(Theme.ground)
        }
        .confirmationDialog("Start \(journey.title)?", isPresented: $confirmsSwitch, titleVisibility: .visible) {
            Button("Start \(journey.title)") { startAndClose() }
        } message: {
            Text("Only one journey runs at a time. You'll leave \(model.activeRun?.journey?.title ?? "your current journey"), and its progress isn't kept.")
        }
    }

    private func startAndClose() {
        model.start(journey)
        model.presentsJourneys = false
        dismiss()
    }

    private func amount(_ metres: Double) -> String {
        journey.metric == .distance ? model.formatter.distance(metres) : "\(model.formatter.exactHeightNumber(metres)) \(model.unit.heightSymbol)"
    }

    private var howItCounts: String {
        journey.metric == .distance
            ? "Counts your everyday walking from the day you start. Earlier steps don't count; this one is about the months ahead."
            : "Counts flights of stairs climbed from the day you start, about 3 m each."
    }
}

private func totalText(_ journey: Journey, formatter: HonestFormatter) -> String {
    journey.metric == .distance ? "about \(formatter.distance(journey.total))" : "\(formatter.exactHeightNumber(journey.total)) \(formatter.unit.heightSymbol) up"
}
