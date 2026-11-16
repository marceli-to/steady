import SwiftUI
import SteadyKit

/// City-level home picker. No location permission, no address: a name from a list.
struct HomeCityPicker: View {
    var selection: String?
    var onPick: (Place) -> Void
    @State private var query = ""

    private let regionCode = Locale.current.region?.identifier

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    Text("Just the city. It's where your comparisons start, like Zürich → Lisbon. It stays on this phone.")
                        .font(.manrope(16, relativeTo: .body))
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                }
                if !nearby.isEmpty {
                    Section { rows(nearby) } header: { Caption("In your region") }
                }
                Section { rows(all) } header: { Caption("Everywhere") }
            } else {
                rows(matches)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Where is home?")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City")
    }

    private func rows(_ places: [Place]) -> some View {
        ForEach(places) { place in
            Button { onPick(place) } label: {
                HStack {
                    Text(place.name)
                        .font(.manrope(17, .medium, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if place.id == selection {
                        Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            .accessibilityLabel("Selected")
                    }
                    Text(place.country)
                        .font(.mono(12))
                        .foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .listRowBackground(Theme.ground)
        }
    }

    private var all: [Place] {
        Atlas.homePlaces.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var nearby: [Place] {
        guard let regionCode else { return [] }
        return all.filter { $0.country == regionCode }
    }

    private var matches: [Place] {
        all.filter {
            $0.name.localizedStandardContains(query) || $0.country.localizedCaseInsensitiveCompare(query) == .orderedSame
        }
    }
}

#Preview {
    NavigationStack { HomeCityPicker(selection: "zurich") { _ in } }
}
