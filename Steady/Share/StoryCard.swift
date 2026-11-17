import SwiftUI
import SteadyKit

/// The story card: 360×640 pt, rendered at 3× for 1080×1920. Always dark, fixed type size,
/// so the shared image looks the same on every phone.
struct StoryCard: View {
    static let size = CGSize(width: 360, height: 640)
    let content: StoryCardContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("steady")
                    .font(.manrope(13.3, .extraBold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(content.since)
                    .font(.mono(9.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 40)

            if let to = content.routeTo {
                StoryArc(from: content.routeFrom, to: to)
                    .frame(height: 82)
                    .padding(.top, 122)
            } else {
                Spacer().frame(height: 204)
            }

            Text("\(content.number) \(content.unit)")
                .font(.manrope(64, .extraBold))
                .tracking(-1.5)
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 6)
            Text("walked without noticing.")
                .font(.manrope(24, .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.ink)
                .padding(.top, -6)
            if let sentence = content.sentence {
                Text(sentence)
                    .font(.manrope(15))
                    .foregroundStyle(Theme.ink.opacity(0.78))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.trailing, 40)
            }

            Spacer(minLength: 0)

            if let climbed = content.climbed {
                HStack(spacing: 12) {
                    MountainShape()
                        .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                        .frame(width: 15, height: 11)
                    (Text(climbed) + Text(content.climbedComparison.map { _ in " — " } ?? "")
                        + Text(content.climbedComparison ?? "").font(.manrope(14.6, .bold)))
                        .font(.manrope(14.6))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 15)
                .frame(height: 43)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(alignment: .firstTextBaseline) {
                Text("How far have you walked?")
                    .font(.manrope(12.5))
                    .foregroundStyle(Theme.ink.opacity(0.72))
                Spacer()
                Text("steady for iPhone")
                    .font(.mono(10.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 13)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Theme.ground)
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(.large)
        .accessibilityElement(children: .combine)
    }
}

/// From home (or nowhere in particular) to the comparison place, as on the mockup.
private struct StoryArc: View {
    let from: String?
    let to: String

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let start = CGPoint(x: 13, y: 58)
            let end = CGPoint(x: w - 13, y: 45)
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: start)
                    p.addQuadCurve(to: end, control: CGPoint(x: w * 0.5, y: -51))
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                Circle().fill(Theme.ink).frame(width: 11, height: 11).position(start)
                Circle().strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1.2).frame(width: 26, height: 26).position(end)
                Circle().fill(Theme.accent).frame(width: 15, height: 15).position(end)

                if let from {
                    Text(from)
                        .font(.mono(9))
                        .foregroundStyle(Theme.muted)
                        .fixedSize()
                        .offset(x: start.x, y: start.y + 9)
                }
                Text(to)
                    .font(.mono(9, .medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
                    .frame(width: w - 10, alignment: .trailing)
                    .offset(y: end.y + 9)
            }
        }
    }
}

/// A small outline of two peaks.
struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.5))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.3))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    StoryCard(content: StoryCardContent(
        since: "since March 2019", number: "11,240", unit: "km", routeFrom: "Zürich", routeTo: "Beijing",
        sentence: "That’s Zürich to Beijing — just from everyday life.",
        climbed: "Plus 41,200 m climbed", climbedComparison: "Everest 4.7×"))
}
