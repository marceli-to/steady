import SwiftUI
import UniformTypeIdentifiers
import SteadyKit

/// Renders the same card views that are shown on screen into PNGs at exact pixel sizes.
@MainActor
enum ShareRenderer {
    /// Cards are laid out in points at a third of their pixel size and rendered at 3×.
    static let scale: CGFloat = 3

    static func png(_ view: some View, size: CGSize) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage?.pngData()
    }

    static func story(_ content: StoryCardContent) -> Data? {
        png(StoryCard(content: content), size: StoryCard.size)
    }

    static func postcard(_ content: PostcardContent) -> Data? {
        png(PostcardCard(content: content), size: PostcardCard.size)
    }
}

/// A rendered card, ready for the share sheet.
struct RenderedCard: Transferable, Sendable {
    let png: Data

    var image: Image {
        UIImage(data: png).map { Image(uiImage: $0) } ?? Image(systemName: "photo")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
            .suggestedFileName("steady.png")
    }
}

/// Shows a card at whatever size fits, keeping its proportions.
struct ScaledCard<Card: View>: View {
    let size: CGSize
    @ViewBuilder var card: Card

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
            card
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.faint.opacity(0.5), lineWidth: 0.5))
    }
}

/// "Share" that renders the card when it appears and again whenever its content changes.
struct ShareCardButton<Key: Hashable>: View {
    let title: String
    let key: Key
    let render: @MainActor () -> Data?
    @State private var card: RenderedCard?

    var body: some View {
        Group {
            if let card {
                ShareLink(item: card, preview: SharePreview(title, image: card.image)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {} label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .disabled(true)
            }
        }
        .buttonStyle(.steady)
        .task(id: key) {
            card = render().map(RenderedCard.init(png:))
        }
    }
}
