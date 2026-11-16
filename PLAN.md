# steady — plan

*steady wins the race.* A quiet iOS app that turns years of everyday step data into distances you can feel, and lets that movement carry you slowly along a journey.

This document covers architecture, data model, the journey JSON format, and the four phases with acceptance criteria. Nothing is built yet.

---

## 1. Architecture

### Toolchain
- Xcode 27.2 / Swift 6.4, deployment target **iOS 17.0**, Swift 6 language mode (strict concurrency).
- Project generated with **XcodeGen** from a checked-in `project.yml` (no hand-edited `.pbxproj`). Needs `brew install xcodegen`.
- No third-party runtime dependencies. Fonts (Manrope, JetBrains Mono, both SIL OFL) are bundled with their licence files.

### Layout
```
steady/
├─ project.yml                     XcodeGen spec: app, widget extension, test targets
├─ PLAN.md
├─ Packages/SteadyKit/             Swift package, pure logic, no HealthKit, no UI
│  ├─ Sources/SteadyKit/
│  │  ├─ Model/                    DayTotals, Metric, Units, Place, Landmark, Journey…
│  │  ├─ Counting/                 DailyLifeCalculator, workout overlap, aggregation
│  │  ├─ Comparisons/              GreatCircle, ComparisonPicker
│  │  ├─ Journeys/                 JourneyLoader, ProgressEngine, MilestoneDetector, ArrivalEstimator
│  │  ├─ Formatting/               HonestFormatter (rounding, ≈, km/mi), ArrivalPhrase
│  │  ├─ Source/                   HealthDataSource protocol + MockHealthDataSource
│  │  └─ Resources/                places.json, landmarks.json, journeys/*.json
│  └─ Tests/SteadyKitTests/        unit tests, run with `swift test` (macOS host, fast)
├─ Steady/                         iOS app target
│  ├─ App/                         SteadyApp, AppModel (@Observable), dependency setup
│  ├─ Health/                      HealthKitDataSource (the only file importing HealthKit queries)
│  ├─ Store/                       SwiftData models, HistoryStore (sync + cache)
│  ├─ Features/                    Onboarding, Reveal, Home, Journeys, Postcards, LookBack, Settings, HowWeCount
│  ├─ Design/                      Theme (colours, fonts), RouteLine, ElevationProfile, shared components
│  ├─ Share/                       StoryCard, PostcardCard, ShareRenderer (ImageRenderer)
│  ├─ Widgets/Shared/              WidgetSnapshot (also compiled into the extension)
│  └─ Resources/                   Fonts, Assets, Info.plist strings, PrivacyInfo.xcprivacy
├─ SteadyWidgets/                  WidgetKit extension: medium, small, lock rectangular, lock circular
└─ SteadyTests/                    app-level tests (store sync, snapshot writing) on simulator
```

Why the split: every rule that the prompt asks to be tested (counting, workout exclusion, comparison picking, milestone detection) lives in `SteadyKit`, which has no HealthKit or UIKit dependency. Tests run in seconds with `swift test`, and the same code is shared by app and widget.

### Data flow
```
HealthDataSource (HealthKit | Mock)
        │  daily deduplicated totals + workout intervals
        ▼
HistoryStore (SwiftData DayRecord cache, incremental sync)
        │  [DayTotals] with daily-life and workout parts kept separate
        ▼
AppModel (@Observable, @MainActor)
  ├─ totals (all time, this year)  → ComparisonPicker → HonestFormatter
  ├─ active journey                 → ProgressEngine / MilestoneDetector / ArrivalEstimator
  └─ after each refresh             → writes WidgetSnapshot to App Group, reloads widget timelines
```

### HealthDataSource protocol
```swift
public protocol HealthDataSource: Sendable {
    func requestAuthorization() async throws
    /// Earliest sample date across walking distance / steps, or nil if no data.
    func firstSampleDate() async throws -> Date?
    /// Deduplicated (across iPhone + Watch) totals per calendar day.
    func dailyTotals(_ metric: HealthMetric, in range: DateInterval) async throws -> [Date: Double]
    /// Deduplicated total for an arbitrary interval (used to measure what happened inside a workout).
    func total(_ metric: HealthMetric, in interval: DateInterval) async throws -> Double
    func workoutIntervals(in range: DateInterval) async throws -> [DateInterval]
}
enum HealthMetric { case walkingDistance, steps, flightsClimbed }
```
- `HealthKitDataSource` uses `HKStatisticsCollectionQuery` (daily, `.cumulativeSum`) which deduplicates overlapping sources, which raw sample summing would not.
- `MockHealthDataSource` generates deterministic, seeded history: ~6 years, weekday/weekend rhythm, seasonal swing, holiday spikes, gaps (forgotten phone days, a missing 5-week block, a phone-less first months), ~2 workouts a week (runs and hikes). Used by previews, tests and the simulator (selected automatically when HealthKit is unavailable, or via a launch argument `-mockHealth`).

### Daily-life counting (workout exclusion)
1. Fetch daily deduplicated totals for walking distance and flights.
2. Fetch all `HKWorkout` intervals. Merge overlapping intervals, split any that cross midnight.
3. For each workout interval, query the deduplicated total *inside* it, and attribute it to that day as `workoutPart`.
4. `dailyLife = max(0, dayTotal − workoutPart)`.

Both parts are cached per day, so the "include workouts" setting flips instantly without re-querying. This is robust against partially overlapping samples, because HealthKit prorates samples in statistics queries.

Steps are read and cached too (used in "How we count" and look back), but **distance is the primary number**: it uses Apple's per-person step-length calibration, which beats any step × constant guess.

**Elevation** = flights climbed × 3 m (Apple counts a flight as roughly 3 m / 10 ft of ascent). Stated in "How we count".

### Caching and sync
- First run: fetch full history in yearly chunks (progress drives the reveal animation, so slow is fine and honest).
- Subsequent runs: re-fetch the last 10 days (late Watch syncs) plus anything newer than the last sync. Pull-to-refresh not needed; refresh on foreground.
- Background: `HKObserverQuery` with background delivery for step count (hourly at best) to refresh the widget snapshot. No location, no live tracking.

### Honest formatting
- Distance: < 10 km → one decimal; < 1,000 km → whole km; ≥ 1,000 km → nearest 10 km. Miles the same thresholds.
- Elevation: nearest 10 m; multiples to one decimal ("Everest 4.7×").
- Comparisons always carry "≈". Big totals carry "about" in prose.
- Arrival: "late March", "early next summer" beyond 9 months, "in about 3 years" beyond 2 years, "whenever you're ready" when the 30-day pace is ~0.

### Comparisons
- `places.json`: ~250 cities and notable places, `{id, name, country, lat, lon}`. The home-city picker uses the same list (city level only; no GPS, no address).
- `landmarks.json`: heights, `{id, name, metres}` (Eiffel Tower, Burj Khalifa, Ben Nevis, Matterhorn, Mont Blanc, Kilimanjaro, Everest…).
- **Distance**: great-circle (haversine, R = 6,371 km) from home to every place; pick the place minimising `|distance − total|`, ignoring places < 5 km from home. Ties break toward the better-known place (`rank` field). Beyond the farthest reachable point (~20,000 km) fall back to "around the world 1.4×", and beyond that "≈ ⅓ of the way to the Moon".
- **Elevation**: pick the tallest landmark the user has climbed at least once; if they're past Everest, keep Everest and show the multiple.

### Widgets
- The app writes a small `WidgetSnapshot` (Codable JSON) into the App Group container after each refresh and calls `WidgetCenter.shared.reloadAllTimelines()`.
- Timeline provider: entries every ~6 hours. When the device is unlocked it also re-runs the shared counting code against HealthKit for "today" and updates the snapshot; otherwise it shows the last snapshot (never blank).
- Every route graphic has an accessibility label ("Zürich to Rome, 412 of 900 kilometres, near Bellinzona").

### Privacy
- Read-only HealthKit types: `stepCount`, `distanceWalkingRunning`, `flightsClimbed`, `workoutType`. No write access requested.
- `NSHealthShareUsageDescription`: "steady reads your steps, walking distance and flights climbed to show how far everyday life has carried you. Nothing leaves your phone."
- No network code at all in v1, no analytics, no crash reporters. `PrivacyInfo.xcprivacy` declares no tracking and no collected data; App Store label: **Data Not Collected**.
- Share cards hide the home city unless the user turns it on (see share cards).

---

## 2. Data model

### Bundled (immutable, in `SteadyKit`)
| Type | Fields |
|---|---|
| `Place` | `id`, `name`, `country`, `lat`, `lon`, `rank` |
| `Landmark` | `id`, `name`, `metres` |
| `Journey` | from JSON, see §3 |

### SwiftData (app, local only)
```swift
@Model DayRecord        // cache, one per calendar day
  day: Date (unique, start of day)
  distanceTotal, distanceInWorkouts: Double   // metres
  flightsTotal, flightsInWorkouts: Double
  steps: Double
  syncedAt: Date

@Model JourneyRun       // a user's run of a bundled journey
  id: UUID
  journeyID: String, journeyVersion: Int
  startedOn: Date       // counting starts at the start of this calendar day
  finishedOn: Date?
  // progress follows the global "include workouts" setting; postcards record it at creation time
  ownerID: String = "local"         // follow-ready
  postcards: [Postcard]

@Model Postcard
  id: UUID
  run: JourneyRun
  milestoneID: String
  reachedOn: Date       // computed from daily history, not "when the app noticed"
  dayNumber: Int        // day N of the journey
  progress: Double      // 0…1 along the route at that moment
  includedWorkouts: Bool // drives the "no workouts counted" line on the card
  seen: Bool
  ownerID: String = "local"
```
Settings live in `@AppStorage` (home place id, units, include workouts, show home city on cards, postcard notifications) and are mirrored into the App Group defaults for the widget.

**Follow-ready, without building it:** stable UUIDs, an `ownerID` on runs and postcards, postcards as self-contained value snapshots (a `PostcardPayload` Codable that could be published later), and a `routeVisibleFromFirstMilestone` rule implemented in the route renderer (a `hidesStart` flag) even though only the local user sees it.

---

## 3. Journey JSON format

One file per journey in `Resources/journeys/`. All values are metres, all coordinates WGS84.

```json
{
  "id": "zurich-rome",
  "version": 1,
  "title": "Zürich → Rome",
  "subtitle": "Over the Gotthard and down through Italy",
  "metric": "distance",
  "total": 900000,
  "milestones": [
    { "id": "zurich",     "name": "Zürich",     "at": 0,      "lat": 47.3769, "lon": 8.5417 },
    { "id": "gotthard",   "name": "Gotthard",   "at": 105000, "lat": 46.5585, "lon": 8.5617 },
    { "id": "bellinzona", "name": "Bellinzona", "at": 175000, "lat": 46.1955, "lon": 9.0237 },
    { "id": "milano",     "name": "Milano",     "at": 290000, "lat": 45.4642, "lon": 9.1900 },
    { "id": "bologna",    "name": "Bologna",    "at": 500000, "lat": 44.4949, "lon": 11.3426 },
    { "id": "firenze",    "name": "Firenze",    "at": 610000, "lat": 43.7696, "lon": 11.2558 },
    { "id": "roma",       "name": "Roma",       "at": 900000, "lat": 41.9028, "lon": 12.4964 }
  ],
  "path": [[47.3769, 8.5417], [47.05, 8.31], [46.5585, 8.5617], "…"]
}
```
Elevation journeys use `"metric": "elevation"`, `at` in metres climbed, and an `altitude` per milestone instead of (or alongside) coordinates; they render as a vertical profile, not a map line:
```json
{ "id": "everest", "version": 1, "title": "Climb Everest", "metric": "elevation", "total": 8849,
  "milestones": [
    { "id": "base",   "name": "Base Camp", "at": 5364, "altitude": 5364 },
    { "id": "camp1",  "name": "Camp 1",    "at": 6065, "altitude": 6065 },
    { "id": "camp2",  "name": "Camp 2",    "at": 6400, "altitude": 6400 },
    { "id": "camp3",  "name": "Camp 3",    "at": 7200, "altitude": 7200 },
    { "id": "camp4",  "name": "Camp 4",    "at": 7950, "altitude": 7950 },
    { "id": "summit", "name": "Summit",    "at": 8849, "altitude": 8849 } ] }
```
Rules (validated by a unit test over every bundled file): `at` strictly increasing, first milestone `at` ≥ 0, last `at` == `total`, ids unique, `path` optional (falls back to straight segments between milestones).

Note: Everest counts from sea level, so Base Camp is a real early milestone (~5.4 km of climbing). Honest, and a nice long first stretch.

Bundled journeys: **Zürich → Rome** (≈900 km), **Climb Everest** (8,849 m), **Camino Francés** (Saint-Jean-Pied-de-Port → Santiago, ≈780 km), **Kilimanjaro** (5,895 m), **Hadrian's Wall** (≈135 km, a short first journey for people who want to finish something in a season).

### Progress semantics
- Progress = sum of daily-life (or total, per setting) values from `startedOn` to today, capped at `total`.
- Current place: within 10 % of a segment from a milestone → "near *X*"; otherwise "between *A* and *B*". At the end → "arrived in *X*".
- Milestone detection walks the cached daily series, so a milestone reached while the app was closed gets its real date and day number.
- Estimated arrival: remaining ÷ mean of the last 30 days (days with no data count as zero only if they are inside the user's normal data range, so a forgotten phone doesn't wreck the estimate).

---

## 4. Phases

After every phase: `xcodegen`, build for device and simulator, `swift test` + `xcodebuild test`, and a short summary of what changed and what's next.

### Phase 1 — Prototype: real number on your phone
Build: XcodeGen project, SteadyKit package, `HealthDataSource` + HealthKit and mock implementations, daily-life counting, `HistoryStore` with SwiftData cache, `ComparisonPicker`, `HonestFormatter`, theme + bundled fonts, onboarding (permission → home city → reveal).

Acceptance:
- [ ] App installs on a physical iPhone (signed build verified, not yet run on your phone), asks for read-only HealthKit access with the one-line reason, then shows the home-city picker (searchable list, no location permission ever requested).
- [x] Reveal shows total daily-life distance since the first sample, counting up slowly, with the comparison ("≈ Zürich → Beijing") and a route line that draws in from home to that city; elevation total as a secondary line ("≈ Everest 4.7×").
- [x] Numbers are rounded per the honest rules; turning on "include workouts" (temporary debug toggle in phase 1) changes the number.
- [x] Simulator runs on mock data with 5+ years of history with gaps; SwiftUI previews work without HealthKit.
- [x] If permission is denied or there is no data, a calm explanation appears instead of a zero.
- [x] Unit tests pass: daily aggregation, workout overlap (inside, partial, spanning midnight, overlapping workouts, workout larger than day total), include-workouts toggle, haversine, comparison picking (nearest, tie-break, too-near exclusion, beyond-the-world fallback), elevation landmark picking, formatter rounding in km and mi.

### Phase 2 — Journeys, home, arrival, widgets
Build: journey loader + validation, `JourneyRun`, progress engine, arrival estimator, Home, Journeys list/detail, collection of finished journeys, App Group snapshot, 4 widgets.

Acceptance:
- [ ] All 5 bundled journeys load and pass validation tests.
- [ ] Starting a journey counts from the start of that day; only one active run; finished runs appear in a small collection.
- [ ] Home shows route line with position, "near Bellinzona", km done / total, estimated arrival ("at this pace you'll arrive in late March"), then this year and all time with comparisons. Nothing else.
- [ ] Elevation journeys render as a vertical profile with the same visual language (solid accent done, dashed ahead).
- [ ] Widgets (medium, small, lock rectangular, lock circular) match the mockups, update when the app refreshes, and show the last snapshot when locked. All have VoiceOver labels.
- [ ] Unit tests: milestone detection (dates, multiple in one day, backfill after days closed, exact boundary), progress capping, current-place phrasing, arrival estimate and phrasing (zero pace, far future).

### Phase 3 — Postcards and share cards
Build: postcard creation on milestone reached, postcard list, optional local notification (off by default), `ShareRenderer`, story card 1080×1920 dark, postcard 1080×1080 light, `ShareLink`.

Acceptance:
- [ ] Reaching a milestone creates exactly one postcard with correct place, day number and route progress, even when detected days later.
- [ ] Postcards list is a simple chronological list; tapping opens the postcard and the share action.
- [ ] Story card and postcard render pixel-exact at their sizes, match the mockups, and use the same SwiftUI views as on screen.
- [ ] Home city / start point hidden on cards unless the setting is on; postcard routes start from the first milestone.
- [ ] Reveal's "Share this" now works.
- [ ] Unit tests: postcard creation idempotency, card privacy rule.

### Phase 4 — Look back, settings, polish, accessibility
Build: Look back (year in review: distance, elevation, best month, comparison) shown in December + year archive, Settings (home city, include workouts, units, show home city on cards, postcard notifications, How we count), polish, accessibility pass.

Acceptance:
- [ ] Look back available in December for the current year and any time for past years via the archive.
- [ ] Settings changes propagate to app and widgets immediately.
- [ ] "How we count" explains distance source, workout exclusion, flights → metres, rounding, and why numbers are approximate, in plain language.
- [ ] Dynamic Type up to AX5 without clipping on every screen; dark mode on every screen; VoiceOver labels on every route graphic and number; Reduce Motion replaces count-up and line-draw with a fade.
- [ ] No streaks, badges, confetti, leaderboards, or default-on notifications anywhere.
- [ ] Privacy manifest and strings final; App Store label "Data Not Collected" justified.
- [ ] Unit tests: look-back aggregation (best month, year boundaries, time zones/DST around midnight).

---

## 5. Decisions and how to run

- **Signing**: free Personal Team `3TWRBP96AK`, bundle ID `to.marceli.steady.dev` (App Group will be `group.to.marceli.steady.dev`). Free-team builds expire after 7 days; reinstall from Xcode. Switch `DEVELOPMENT_TEAM` and the IDs in `project.yml` for the studio account.
- **Project**: `xcodegen generate` after adding/removing files; `Steady.xcodeproj` is generated, `project.yml` is the source of truth.
- **Tests**: `swift test` in `Packages/SteadyKit` (fast), or the `Steady` scheme's test action (package + app tests on a simulator).
- **Data source**: the simulator always uses mock history (`-realHealth` to override); on a device `-mockHealth` forces mock data.
- **Debug launch arguments**: `-resetOnLaunch` (fresh in-memory store and settings), `-demoReveal <placeID>` (jump to the reveal).
- **Mockups**: the mockup doc isn't readable from Claude Code's session; Phase 2 needs it shared, or exported as images into `design/`.
- **Git**: one commit per phase.
