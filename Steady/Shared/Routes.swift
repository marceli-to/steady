import SwiftUI

// Route graphics shared by the app and the widgets.
// Road done: solid accent. Road ahead: dashed or dotted.

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

/// A straight route: start dot, solid accent to the current position, dotted ahead with
/// milestone dots, ring at the finish. As in the medium widget mockup.
struct LinearRoute: View {
    var fraction: Double
    /// Fractions of the intermediate milestones.
    var stops: [Double]
    var lineWidth: CGFloat = 3
    var positionSize: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let inset = positionSize / 2
            let width = proxy.size.width - inset * 2
            let y = proxy.size.height / 2
            let x = { (f: Double) in inset + width * CGFloat(min(1, max(0, f))) }

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: x(fraction), y: y))
                    p.addLine(to: CGPoint(x: x(1), y: y))
                }
                .stroke(Theme.faint, style: StrokeStyle(lineWidth: lineWidth * 0.8, lineCap: .round, dash: [0.1, lineWidth * 2.6]))

                Path { p in
                    p.move(to: CGPoint(x: x(0), y: y))
                    p.addLine(to: CGPoint(x: x(fraction), y: y))
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                ForEach(stops.filter { $0 > fraction }, id: \.self) { stop in
                    Circle().fill(Theme.muted.opacity(0.55))
                        .frame(width: lineWidth * 2.4, height: lineWidth * 2.4)
                        .position(x: x(stop), y: y)
                }
                Circle().fill(Theme.ink)
                    .frame(width: lineWidth * 3, height: lineWidth * 3)
                    .position(x: x(0), y: y)
                Circle().strokeBorder(Theme.ink, lineWidth: lineWidth * 0.9)
                    .frame(width: positionSize * 0.85, height: positionSize * 0.85)
                    .position(x: x(1), y: y)
                Circle().fill(Theme.accent)
                    .frame(width: positionSize, height: positionSize)
                    .position(x: x(fraction), y: y)
            }
        }
        .frame(height: positionSize + 4)
        .accessibilityHidden(true)
    }
}
