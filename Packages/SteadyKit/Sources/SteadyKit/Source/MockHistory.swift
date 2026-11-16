import Foundation

/// Deterministic, believable fake history: weekday rhythm, seasons, holidays, forgotten-phone days,
/// a long gap, and a couple of workouts a week.
public enum MockHistory {
    public static func make(
        endingAt now: Date = .now,
        years: Int = 6,
        seed: UInt64 = 2019,
        calendar: Calendar = .current
    ) -> MockHealthDataSource {
        var rng = SplitMix64(seed: seed)
        var samples: [MockSample] = []
        var workouts: [DateInterval] = []

        let today = calendar.startOfDay(for: now)
        guard let first = calendar.date(byAdding: .day, value: -(years * 365 + 40), to: today) else {
            return MockHealthDataSource(samples: [], workouts: [])
        }
        // A five-week stretch with no phone at all, a bit more than two years in.
        let gapStart = calendar.date(byAdding: .day, value: 800, to: first)!
        let gapEnd = calendar.date(byAdding: .day, value: 835, to: first)!
        let stride = 0.74 // metres per step

        // Waking-hour weights for spreading a day's steps.
        let hourWeights: [Double] = [0, 0, 0, 0, 0, 0, 0.2, 0.8, 1.4, 0.7, 0.6, 0.8, 1.5, 0.9, 0.6, 0.6, 0.8, 1.4, 1.2, 0.8, 0.6, 0.4, 0.2, 0]
        let weightSum = hourWeights.reduce(0, +)

        var day = first
        while day <= today {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day)! }
            if day >= gapStart && day < gapEnd { continue }
            if rng.unit() < 0.03 { continue } // phone left at home

            let weekday = calendar.component(.weekday, from: day) // 1 = Sunday
            let month = calendar.component(.month, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            var steps = isWeekend ? 5_000 + rng.unit() * 8_000 : 6_000 + rng.unit() * 4_500
            steps *= 1 + 0.15 * sin(Double(month - 4) / 12 * 2 * .pi) // more in summer
            if month == 8 && calendar.component(.day, from: day) <= 14 { steps *= 1.7 } // holiday
            if month == 12 && calendar.component(.day, from: day) >= 24 { steps *= 0.55 } // sofa season
            let flights = (isWeekend ? 4 : 7) + rng.unit() * 8

            for hour in 0..<24 where hourWeights[hour] > 0 {
                let share = hourWeights[hour] / weightSum * (0.8 + rng.unit() * 0.4)
                let start = calendar.date(byAdding: .hour, value: hour, to: day)!
                let end = calendar.date(byAdding: .hour, value: 1, to: start)!
                let s = steps * share
                samples.append(MockSample(.steps, start: start, end: end, value: s.rounded()))
                samples.append(MockSample(.walkingDistance, start: start, end: end, value: s * stride))
                samples.append(MockSample(.flightsClimbed, start: start, end: end, value: (flights * share).rounded()))
            }

            // Workouts: a run on Tuesdays and Saturdays most weeks, a long hike some Sundays.
            if (weekday == 3 || weekday == 7) && rng.unit() < 0.75 {
                let start = calendar.date(byAdding: .minute, value: 7 * 60 + Int(rng.unit() * 40), to: day)!
                let minutes = 35 + rng.unit() * 30
                let end = start.addingTimeInterval(minutes * 60)
                let km = minutes / 60 * (9.5 + rng.unit() * 2)
                workouts.append(DateInterval(start: start, end: end))
                samples.append(MockSample(.walkingDistance, start: start, end: end, value: km * 1_000))
                samples.append(MockSample(.steps, start: start, end: end, value: (km * 1_000 / 1.1).rounded()))
                samples.append(MockSample(.flightsClimbed, start: start, end: end, value: 1))
            } else if weekday == 1 && rng.unit() < 0.12 {
                let start = calendar.date(byAdding: .hour, value: 10, to: day)!
                let end = start.addingTimeInterval((3 + rng.unit() * 2) * 3600)
                let km = 10 + rng.unit() * 8
                workouts.append(DateInterval(start: start, end: end))
                samples.append(MockSample(.walkingDistance, start: start, end: end, value: km * 1_000))
                samples.append(MockSample(.steps, start: start, end: end, value: (km * 1_000 / stride).rounded()))
                samples.append(MockSample(.flightsClimbed, start: start, end: end, value: (40 + rng.unit() * 60).rounded()))
            }
        }
        return MockHealthDataSource(samples: samples, workouts: workouts)
    }
}

/// Small deterministic generator, so mock history is the same on every run.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
