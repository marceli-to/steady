import SwiftUI
import SteadyKit

/// First open: Health access, home city, then the reveal.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    /// `-demoReveal <placeID>` jumps straight to the reveal, for screenshots and quick checks.
    @State private var step: Step = ProcessInfo.processInfo.arguments.contains("-demoReveal") ? .reveal : .welcome

    enum Step { case welcome, home, reveal }

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView {
                    await model.requestAccess()
                    model.refresh() // start reading history while they pick a city
                    withAnimation(.easeInOut(duration: 0.5)) { step = .home }
                }
                .transition(.opacity)
            case .home:
                NavigationStack {
                    HomeCityPicker(selection: model.homePlaceID) { place in
                        model.homePlaceID = place.id
                        withAnimation(.easeInOut(duration: 0.8)) { step = .reveal }
                    }
                }
                .transition(.opacity)
            case .reveal:
                RevealView {
                    model.hasOnboarded = true
                    model.presentsJourneys = true
                }
                .transition(.opacity)
            }
        }
    }
}

struct WelcomeView: View {
    var onContinue: () async -> Void
    @State private var working = false

    var body: some View {
        ScrollsWhenLarge {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("steady")
                .font(.manrope(48, .extraBold, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
            Text("steady wins the race.")
                .font(.manrope(19, .medium, relativeTo: .title3))
                .foregroundStyle(Theme.accent)
                .padding(.top, 4)
            Text("Your phone has quietly counted every step for years. steady turns them into distances you can feel.")
                .font(.manrope(19, .regular, relativeTo: .body))
                .foregroundStyle(Theme.muted)
                .padding(.top, 28)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Spacer()
            Text("Reads steps, walking distance and flights climbed. Nothing leaves your phone.")
                .font(.mono(12, relativeTo: .footnote))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 16)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                working = true
                Task {
                    await onContinue()
                    working = false
                }
            } label: {
                if working { ProgressView().tint(Theme.ground) } else { Text("Connect to Health") }
            }
            .buttonStyle(.steady)
            .disabled(working)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .background(Theme.ground.ignoresSafeArea())
    }
}

#Preview("Welcome") {
    WelcomeView {}
}
