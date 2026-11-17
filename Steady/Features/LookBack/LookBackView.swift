import SwiftUI
import SteadyKit

/// A year looked back on: how far, how high, the best month, and every month as a quiet bar.
struct LookBackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var year: Int

    var body: some View {
        let years = model.lookBackYears
        NavigationStack {
            ScrollView {
                YearReview(review: model.review(of: year), isThisYear: year == Calendar.current.component(.year, from: .now))
                    .id(year)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(String(year))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if years.count > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Year", selection: $year) {
                                ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                            }
                        } label: {
                            Label("Other years", systemImage: "calendar")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
    }
}

private struct YearReview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let review: YearInReview
    let isThisYear: Bool
    @State private var shown = false

    var body: some View {
        let formatter = model.formatter
        let summary = review.summary
        VStack(alignment: .leading, spacing: 0) {
            Caption(isThisYear ? "\(review.year), so far" : "\(review.year), looked back")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatter.distanceNumber(summary.distance))
                    .font(.manrope(64, .extraBold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(model.unit.symbol)
                    .font(.manrope(24, .bold, relativeTo: .title2))
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .padding(.top, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("About \(formatter.distance(summary.distance))")

            Text("of everyday walking")
                .font(.manrope(19, .medium, relativeTo: .title3))
                .foregroundStyle(Theme.muted)

            if let comparison = model.distanceComparison(for: summary.distance) {
                Text(formatter.comparison(comparison))
                    .font(.manrope(22, .bold, relativeTo: .title2))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 20)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(formatter.spokenComparison(comparison))
            }

            if summary.elevation > 0 {
                let elevation = model.elevationComparison(for: summary.elevation)
                Text("\(formatter.height(summary.elevation)) climbed" + (elevation.map { " · " + formatter.comparison($0) } ?? ""))
                    .font(.mono(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MonthBars(review: review, shown: shown)
                .padding(.top, 40)

            if let best = review.bestMonth {
                Text("Your best month was \(monthName(best.month)), with \(formatter.distance(best.distance)).")
                    .font(.manrope(19, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(daysLine)
                .font(.manrope(15, relativeTo: .footnote))
                .foregroundStyle(Theme.muted)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(reduceMotion && !shown ? 0 : 1)
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.6) : .spring(duration: 1.2, bounce: 0).delay(0.2)) {
                shown = true
            }
        }
    }

    private var daysLine: String {
        let days = review.summary.daysWithData
        let counted = model.includeWorkouts ? "Workouts included." : "Everyday walking only, no workouts counted."
        return "Steps on \(days) \(days == 1 ? "day" : "days"). \(counted)"
    }

    private func monthName(_ month: Int) -> String {
        Calendar.current.monthSymbols[month - 1]
    }
}

/// Twelve bars, the best month in accent. One VoiceOver element that reads them all.
private struct MonthBars: View {
    @Environment(AppModel.self) private var model
    let review: YearInReview
    let shown: Bool

    var body: some View {
        let top = max(review.months.map(\.distance).max() ?? 0, 1)
        let best = review.bestMonth?.month
        let letters = Calendar.current.veryShortMonthSymbols
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(review.months) { month in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(month.month == best ? Theme.accent : Theme.faint)
                        .frame(height: max(month.distance > 0 ? 3 : 1, 120 * month.distance / top * (shown ? 1 : 0)))
                        .frame(height: 120, alignment: .bottom)
                    Text(letters[month.month - 1])
                        .font(.mono(11, month.month == best ? .bold : .regular))
                        .foregroundStyle(month.month == best ? Theme.ink : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Distance each month")
        .accessibilityValue(spoken)
    }

    private var spoken: String {
        let names = Calendar.current.monthSymbols
        return review.months
            .map { "\(names[$0.month - 1]), \($0.distance > 0 ? model.formatter.distance($0.distance) : "nothing")" }
            .joined(separator: "; ")
    }
}
