import SwiftUI
import SteadyKit

/// Minimal settings for the prototype. Phase 4 adds "How we count" and polish.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        HomeCityPicker(selection: model.homePlaceID) { place in
                            model.homePlaceID = place.id
                        }
                    } label: {
                        LabeledContent("Home city", value: model.homePlace?.name ?? "Not set")
                    }
                    Picker("Units", selection: $model.unit) {
                        Text("Kilometres").tag(DistanceUnit.kilometres)
                        Text("Miles").tag(DistanceUnit.miles)
                    }
                }
                Section {
                    Toggle("Include workouts", isOn: $model.includeWorkouts)
                } footer: {
                    Text("steady counts everyday walking. Runs, hikes and other recorded workouts are left out unless you include them here.")
                }
                Section {
                    Button("Read all steps again") {
                        model.readEverythingAgain()
                        dismiss()
                    }
                } footer: {
                    if model.usesMockData {
                        Text("Showing made-up history (simulator or -mockHealth).")
                    }
                }
            }
            .font(.manrope(17, relativeTo: .body))
            .tint(Theme.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
