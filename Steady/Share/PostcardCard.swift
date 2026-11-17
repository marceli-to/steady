import SwiftUI
import SteadyKit

/// The postcard: 360×360 pt, rendered at 3× for 1080×1080. Always light, fixed type size.
struct PostcardCard: View {
    static let size = CGSize(width: 360, height: 360)
    let content: PostcardContent

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(content.header.uppercased())
                    .font(.mono(10, .medium))
                    .tracking(0.3)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 29)
                Text(content.title)
                    .font(.manrope(10.3))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 5)

                Spacer(minLength: 12)

                Text(content.headline)
                    .font(.manrope(34, .extraBold))
                    .tracking(-0.8)
                    .lineSpacing(-11)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Text(content.body)
                    .font(.manrope(11.5))
                    .lineSpacing(1)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                Spacer(minLength: 12)

                Rectangle().fill(Theme.faint.opacity(0.7)).frame(height: 0.7)
                HStack(alignment: .firstTextBaseline) {
                    Text("steady")
                        .font(.manrope(11, .extraBold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(content.footnote)
                        .font(.mono(7.5))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .frame(width: 180)
            .padding(.leading, 29)

            PostcardRoute(stops: content.stops, climbs: content.climbs)
                .padding(.leading, 30)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Theme.ground)
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.headline) \(content.body) \(content.header), \(content.title).")
    }
}

/// The route as a vertical line: solid accent up to the milestone, dotted ahead.
private struct PostcardRoute: View {
    let stops: [PostcardContent.Stop]
    let climbs: Bool

    private let top: CGFloat = 42
    private let bottom: CGFloat = 317
    private let x: CGFloat = 5

    private func y(_ stop: PostcardContent.Stop) -> CGFloat {
        let t = climbs ? 1 - stop.position : stop.position
        return top + (bottom - top) * t
    }

    var body: some View {
        let current = stops.first { $0.state == .current }
        ZStack(alignment: .topLeading) {
            if let first = stops.first, let last = stops.last, let current {
                Path { p in
                    p.move(to: CGPoint(x: x, y: y(current)))
                    p.addLine(to: CGPoint(x: x, y: y(last)))
                }
                .stroke(Theme.muted.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 6]))
                Path { p in
                    p.move(to: CGPoint(x: x, y: y(first)))
                    p.addLine(to: CGPoint(x: x, y: y(current)))
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            }

            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                marker(stop, isFirst: index == 0)
                    .position(x: x, y: y(stop))
                Text(stop.name)
                    .font(.manrope(stop.state == .current ? 11 : (stop.isEnd ? 10 : 9.5), stop.isEnd || stop.state == .current ? .bold : .regular))
                    .foregroundStyle(stop.isEnd || stop.state == .current ? Theme.ink : Theme.muted)
                    .lineLimit(1)
                    .fixedSize()
                    .alignmentGuide(.top) { d in d[VerticalAlignment.center] - y(stop) }
                    .alignmentGuide(.leading) { _ in -(x + (stop.state == .current ? 16 : 12)) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func marker(_ stop: PostcardContent.Stop, isFirst: Bool) -> some View {
        switch stop.state {
        case .current:
            ZStack {
                Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1).frame(width: 23, height: 23)
                Circle().fill(Theme.accent).frame(width: 13, height: 13)
            }
        case .passed:
            Circle().fill(isFirst ? Theme.ink : Theme.accent)
                .frame(width: isFirst ? 8 : 6, height: isFirst ? 8 : 6)
        case .ahead:
            if stop.isEnd {
                Circle().strokeBorder(Theme.ink, lineWidth: 1.4).frame(width: 8.5, height: 8.5)
                    .background(Circle().fill(Theme.ground))
            } else {
                Circle().strokeBorder(Theme.muted.opacity(0.6), lineWidth: 1.2).frame(width: 6.5, height: 6.5)
                    .background(Circle().fill(Theme.ground))
            }
        }
    }
}

#Preview {
    let journey = JourneyCatalog.journey(id: "zurich-rome")!
    let payload = PostcardPayload(runID: UUID(), journeyID: journey.id, journeyVersion: 1, milestoneID: "bellinzona",
                                  reachedOn: .now, dayNumber: 63, progress: 0.2, includedWorkouts: false)
    PostcardCard(content: ShareCards.postcard(payload, journey: journey, home: nil, showsHomeCity: true, formatter: HonestFormatter())!)
}
