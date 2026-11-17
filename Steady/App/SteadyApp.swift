import SwiftUI
import SwiftData
import SteadyKit

@main
struct SteadyApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let args = ProcessInfo.processInfo.arguments
        let inMemory = args.contains("-resetOnLaunch")
        if inMemory, let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        do {
            container = try ModelContainer(
                for: DayRecord.self, JourneyRun.self, Postcard.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("Could not open the local store: \(error)")
        }
        if let index = args.firstIndex(of: "-demoReveal"), args.indices.contains(index + 1) {
            UserDefaults.standard.set(args[index + 1], forKey: "homePlaceID")
        }
        #if DEBUG
        // `-skipOnboarding`: straight to Home (home city Zürich unless one is set), for screenshots.
        if args.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
            if UserDefaults.standard.string(forKey: "homePlaceID") == nil {
                UserDefaults.standard.set("zurich", forKey: "homePlaceID")
            }
        }
        #endif
        let (source, isMock) = AppModel.makeSource()
        let model = AppModel(source: source, usesMockData: isMock, container: container)
        model.applyDemoArguments()
        model.startBackgroundUpdates()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(container)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && model.hasOnboarded { model.refresh() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-widgetGallery") {
                WidgetGallery()
            } else if model.hasOnboarded {
                HomeView().transition(.opacity)
            } else {
                OnboardingFlow().transition(.opacity)
            }
            #else
            if model.hasOnboarded {
                HomeView().transition(.opacity)
            } else {
                OnboardingFlow().transition(.opacity)
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.6), value: model.hasOnboarded)
    }
}
