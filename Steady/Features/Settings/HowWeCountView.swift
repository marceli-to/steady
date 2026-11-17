import SwiftUI
import SteadyKit

/// How the numbers are made, in plain words.
struct HowWeCountView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("steady only reads what your phone and watch already recorded. Here's what happens to it.")
                    .font(.manrope(19, .medium, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Topic(title: "Distance", text: """
                Your iPhone and Apple Watch estimate how far you walk from your steps and stride, and store it in Health as walking and running distance. steady adds that up day by day. When both devices counted the same walk, Health keeps one of them, so nothing is counted twice.
                """)

                Topic(title: "Workouts", text: """
                steady is about everyday life: walking to work, to the shop, around the house. So by default it leaves out anything you walked or ran during a recorded workout. Distance from before and after a workout still counts. You can include workouts in Settings; every number, journey and widget follows straight away.
                """)

                Topic(title: "Climbing", text: """
                Your iPhone counts flights of stairs from the change in air pressure. One flight is about 3 metres (10 feet) up, so 10 flights are about 30 metres. A steep street counts too. Going down doesn't count, and the same workout rule applies.
                """)

                Topic(title: "Rounding", text: """
                Short distances get one decimal, longer ones whole \(model.unit == .miles ? "miles" : "kilometres"), and anything over 1,000 is rounded to the nearest 10. Big heights are rounded to the nearest 10 \(model.unit == .miles ? "feet" : "metres"). Comparisons carry a ≈, because Zürich → Lisbon is a straight line over the map, not a road.
                """)

                Topic(title: "Why it's approximate", text: """
                Phones estimate distance from steps, and a step is not always the same length. A phone left on the desk counts nothing; a day with phone and watch counts a bit more carefully. Over months and years the errors mostly even out, but treat every number here as a good guess, not a measurement.
                """)

                Topic(title: "Journeys", text: """
                A journey counts from the start of the day you begin it. Earlier steps don't count. Milestones are dated by the day you really reached them, even if you didn't open the app then.
                """)

                Topic(title: "What stays on your phone", text: """
                Everything. steady has no account, no servers and no analytics. Your home city is only used for comparisons and stays off share cards unless you choose otherwise.
                """)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 16)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("How we count")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Topic: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(title)
            Text(text)
                .font(.manrope(17, relativeTo: .body))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
