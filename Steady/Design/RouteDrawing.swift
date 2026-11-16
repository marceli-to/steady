import SwiftUI
import SteadyKit

/// A journey's route with your position: a map line for distance journeys,
/// a climbing profile for elevation journeys.
struct RouteDrawing: View {
    var journey: Journey
    var done: Double
    /// Label every milestone, or only start, finish and the one you're near.
    var labelsAll = false

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size).insetBy(dx: 14, dy: 18)
            let points = RouteGeometry.points(for: journey, in: rect)
            let position = RouteGeometry.position(of: done, in: journey, points: points)

            ZStack(alignment: .topLeading) {
                // Ahead: dashed.
                Path { p in
                    p.move(to: position.point)
                    for point in points[(position.segment + 1)...] { p.addLine(to: point) }
                }
                .stroke(Theme.faint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 6]))

                // Done: solid.
                Path { p in
                    p.move(to: points[0])
                    for point in points[1..<(position.segment + 1)] { p.addLine(to: point) }
                    p.addLine(to: position.point)
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(journey.milestones.enumerated()), id: \.element.id) { index, milestone in
                    let passed = milestone.at <= done
                    let isEnd = index == 0 || index == journey.milestones.count - 1
                    Group {
                        if isEnd && !passed {
                            Circle().strokeBorder(Theme.ink, lineWidth: 2).frame(width: 12, height: 12)
                        } else {
                            Circle().fill(index == 0 ? Theme.ink : (passed ? Theme.accent : Theme.ground))
                                .overlay(Circle().strokeBorder(passed ? .clear : Theme.muted.opacity(0.6), lineWidth: 1.5))
                                .frame(width: isEnd ? 12 : 9, height: isEnd ? 12 : 9)
                        }
                    }
                    .position(points[index])

                    if labelsAll || isEnd || isNearest(milestone) {
                        let flip = points[index].x > rect.midX
                        Text(milestone.name)
                            .font(.mono(11, passed ? .medium : .regular))
                            .foregroundStyle(passed ? Theme.ink : Theme.muted)
                            .padding(.horizontal, 3)
                            .background(Theme.ground.opacity(0.85))
                            .fixedSize()
                            .alignmentGuide(.leading) { d in flip ? d.width + 12 - points[index].x : -12 - points[index].x }
                            .alignmentGuide(.top) { d in d.height / 2 - points[index].y }
                    }
                }

                Circle().fill(Theme.accent.opacity(0.2)).frame(width: 30, height: 30).position(position.point)
                Circle().fill(Theme.accent).frame(width: 16, height: 16).position(position.point)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func isNearest(_ milestone: Milestone) -> Bool {
        journey.milestones.min { abs($0.at - done) < abs($1.at - done) }?.id == milestone.id
    }

    private var accessibilityText: String {
        let tracker = JourneyTracker()
        let place = tracker.whereabouts(in: journey, at: done).phrase
        let percent = Int((done / journey.total * 100).rounded(.down))
        return "\(journey.title) route, \(percent) percent done, \(place)"
    }
}

enum RouteGeometry {
    /// Milestone positions inside `rect`. Maps keep their aspect ratio; profiles stretch.
    static func points(for journey: Journey, in rect: CGRect) -> [CGPoint] {
        switch journey.metric {
        case .distance:
            let meanLat = journey.milestones.compactMap(\.lat).reduce(0, +) / Double(max(1, journey.milestones.count))
            let raw = journey.milestones.map {
                CGPoint(x: ($0.lon ?? 0) * cos(meanLat * .pi / 180), y: -($0.lat ?? 0))
            }
            let minX = raw.map(\.x).min()!, maxX = raw.map(\.x).max()!
            let minY = raw.map(\.y).min()!, maxY = raw.map(\.y).max()!
            let scale = min(rect.width / max(maxX - minX, 0.0001), rect.height / max(maxY - minY, 0.0001))
            let offsetX = rect.minX + (rect.width - (maxX - minX) * scale) / 2
            let offsetY = rect.minY + (rect.height - (maxY - minY) * scale) / 2
            return raw.map { CGPoint(x: offsetX + ($0.x - minX) * scale, y: offsetY + ($0.y - minY) * scale) }
        case .elevation:
            let top = journey.milestones.compactMap(\.altitude).max() ?? journey.total
            let count = Double(max(1, journey.milestones.count - 1))
            return journey.milestones.enumerated().map { index, m in
                CGPoint(x: rect.minX + rect.width * Double(index) / count,
                        y: rect.maxY - rect.height * (m.altitude ?? m.at) / max(top, 1))
            }
        }
    }

    /// Where `done` sits: the segment it's in and the interpolated point.
    static func position(of done: Double, in journey: Journey, points: [CGPoint]) -> (segment: Int, point: CGPoint) {
        let stops = journey.milestones
        guard let next = stops.firstIndex(where: { $0.at > done }) else {
            return (max(0, points.count - 2), points[points.count - 1]) // arrived
        }
        guard next > 0 else { return (0, points[0]) }
        let a = stops[next - 1].at, b = stops[next].at
        let t = (done - a) / (b - a)
        let p = points[next - 1], q = points[next]
        return (next - 1, CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t))
    }
}

#Preview {
    VStack(spacing: 40) {
        RouteDrawing(journey: JourneyCatalog.journey(id: "zurich-rome")!, done: 214_000)
            .frame(height: 260)
        RouteDrawing(journey: JourneyCatalog.journey(id: "everest")!, done: 4_100)
            .frame(height: 200)
    }
    .padding()
    .background(Theme.ground)
}
