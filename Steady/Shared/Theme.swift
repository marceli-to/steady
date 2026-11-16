import SwiftUI
import UIKit

/// Colours and type. One accent, lots of ground.
enum Theme {
    static let ink = Color(light: 0x1E2621, dark: 0xECEEE8)
    static let ground = Color(light: 0xECEEE8, dark: 0x1E2621)
    static let muted = Color(light: 0x47514A, dark: 0xA3ACA5)
    static let faint = Color(light: 0x47514A, dark: 0xA3ACA5).opacity(0.35)
    static let accent = Color(light: 0xB8502B, dark: 0xE07A50)
    /// Raised surface, e.g. the medium widget.
    static let card = Color(light: 0xF5F6F2, dark: 0x27302A)

    static let gutter: CGFloat = 28
}

extension Font {
    /// Manrope, for numbers and headlines. Scales with Dynamic Type.
    static func manrope(_ size: CGFloat, _ weight: ManropeWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    /// JetBrains Mono, for small labels and figures.
    static func mono(_ size: CGFloat, _ weight: MonoWeight = .regular, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    enum ManropeWeight: String {
        case regular = "Regular", medium = "Medium", bold = "Bold", extraBold = "ExtraBold"
        var postScriptName: String { "Manrope-\(rawValue)" }
    }

    enum MonoWeight: String {
        case regular = "Regular", medium = "Medium", bold = "Bold"
        var postScriptName: String { "JetBrainsMono-\(rawValue)" }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Small uppercase label in mono, the house style for captions.
struct Caption: View {
    let text: String
    var color: Color = Theme.muted

    init(_ text: String, color: Color = Theme.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.mono(11, .medium))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

/// Quiet full-width button: ink fill or outline.
struct SteadyButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.manrope(17, .bold, relativeTo: .body))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 20)
            .foregroundStyle(prominent ? Theme.ground : Theme.ink)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(prominent ? Theme.ink : .clear)
                    .strokeBorder(Theme.ink.opacity(prominent ? 0 : 0.25), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == SteadyButtonStyle {
    static var steady: SteadyButtonStyle { SteadyButtonStyle() }
    static var steadyQuiet: SteadyButtonStyle { SteadyButtonStyle(prominent: false) }
}
