import SwiftUI

/// Full-screen layouts with spacers look right at normal sizes; at accessibility sizes they
/// would clip or truncate, so there they scroll instead.
struct ScrollsWhenLarge<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: Content

    var body: some View {
        if typeSize.isAccessibilitySize {
            ScrollView { content }
        } else {
            content
        }
    }
}
