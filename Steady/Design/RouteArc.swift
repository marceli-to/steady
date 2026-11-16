import SwiftUI

/// An arc from home to a comparison place: the road done in solid accent, the rest dashed.
/// `progress` animates from 0 to 1 to draw the line in.
struct RouteArc: View {
    var from: String
    var to: String
    var progress: Double
    var showsLabels = true

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let size = proxy.size
                let start = CGPoint(x: 8, y: size.height - 8)
                let end = CGPoint(x: size.width - 8, y: size.height - 8)
                let path = ArcShape()

                ZStack {
                    path
                        .stroke(Theme.faint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 6]))
                    path
                        .trim(from: 0, to: progress)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 10, height: 10)
                        .position(start)
                    Circle()
                        .fill(progress >= 0.999 ? Theme.accent : Theme.faint)
                        .frame(width: 12, height: 12)
                        .position(end)
                        .scaleEffect(progress >= 0.999 ? 1 : 0.8)
                }
            }
            .frame(height: 96)

            if showsLabels {
                HStack(alignment: .firstTextBaseline) {
                    Caption(from)
                    Spacer(minLength: 16)
                    Caption(to, color: progress >= 0.999 ? Theme.accent : Theme.muted)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A line from \(from) to \(to)")
    }
}

/// A low arc between the bottom corners of its rect, like a great-circle route on a flat map.
struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 8
        let start = CGPoint(x: rect.minX + inset, y: rect.maxY - inset)
        let end = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        let control = CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.55)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

/// Text that counts smoothly between values when its value is animated.
struct CountingText: View, @preconcurrency Animatable {
    var value: Double
    var format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

#Preview {
    RouteArc(from: "Zürich", to: "Beijing", progress: 0.6)
        .padding(32)
        .background(Theme.ground)
}
