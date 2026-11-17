import SwiftUI
import SteadyKit

/// Every setting takes effect straight away, in the app and on the widgets.
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
                } footer: {
                    Text("Comparisons start from your home city. It stays on this phone.")
                }

                Section {
                    Toggle("Include workouts", isOn: $model.includeWorkouts)
                } footer: {
                    Text("steady counts everyday walking. Runs, hikes and other recorded workouts are left out unless you include them here.")
                }

                Section {
                    Toggle("Show home city on cards", isOn: $model.showsHomeCityOnCards)
                } footer: {
                    Text("Off: share cards leave out your home city, and the start of a journey that begins near it.")
                }

                Section {
                    Toggle("Postcard notifications", isOn: Binding(
                        get: { model.postcardNotifications },
                        set: { on in Task { await model.setPostcardNotifications(on) } }
                    ))
                } footer: {
                    Text("One quiet notification when you reach a milestone. Postcards wait for you in the app either way.")
                }

                Section {
                    NavigationLink("How we count") { HowWeCountView() }
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
