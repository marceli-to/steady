#if DEBUG
import SwiftUI
import SteadyKit

/// `-widgetGallery`: the widget views at their real sizes, fed by the live snapshot.
/// For checking them against the mockups without adding widgets to a home screen.
struct WidgetGallery: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snapshot = model.widgetSnapshot()
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Caption("Home screen · medium + small")
                JourneyWidgetView(snapshot: snapshot)
                    .padding(16)
                    .frame(width: 338, height: 158)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                YearWidgetView(snapshot: snapshot)
                    .padding(16)
                    .frame(width: 158, height: 158)
                    .background(Color(red: 0x1E / 255, green: 0x26 / 255, blue: 0x21 / 255),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Caption("Lock screen · rectangular + circular")
                HStack(spacing: 16) {
                    if let journey = snapshot.journey {
                        LockRectangular(journey: journey)
                            .frame(width: 170, height: 72)
                        LockCircular(journey: journey)
                            .frame(width: 72, height: 72)
                    }
                }
                .padding(16)
                .foregroundStyle(.white)
                .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, .dark)
            }
            .padding(24)
        }
        .background(Theme.ground)
        .task { model.refresh() }
    }
}
#endif
