import SwiftUI
import SteadyKit

/// Every postcard, newest first. Tapping one opens it with the share action.
struct PostcardsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.postcards.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No postcards yet")
                            .font(.manrope(24, .bold, relativeTo: .title2))
                            .foregroundStyle(Theme.ink)
                        Text("Each milestone on a journey sends one: Gotthard, Bellinzona, Camp 2. They arrive on their own, whenever you get there.")
                            .font(.manrope(17, relativeTo: .body))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List(model.postcards) { postcard in
                        NavigationLink(value: postcard.id) { PostcardRow(postcard: postcard) }
                            .listRowBackground(Theme.ground)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("Postcards")
            .navigationDestination(for: UUID.self) { id in
                if let postcard = model.postcards.first(where: { $0.id == id }) {
                    PostcardDetailView(postcard: postcard)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
    }
}

private struct PostcardRow: View {
    let postcard: Postcard

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(postcard.milestone?.name ?? "A milestone")
                .font(.manrope(19, postcard.seen ? .medium : .bold, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
            Text("\(postcard.journey?.title ?? "") · Day \(postcard.dayNumber) · \(postcard.reachedOn.formatted(date: .abbreviated, time: .omitted))")
                .font(.mono(12))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// One postcard, as it will be shared.
struct PostcardDetailView: View {
    @Environment(AppModel.self) private var model
    let postcard: Postcard

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let content = model.postcardContent(postcard) {
                    ScaledCard(size: PostcardCard.size) { PostcardCard(content: content) }
                        .accessibilityElement(children: .combine)

                    Caption("Reached \(postcard.reachedOn.formatted(date: .long, time: .omitted))")

                    if let journey = postcard.journey, ShareCards.startIsNearHome(journey, home: model.homePlace) {
                        Toggle(isOn: $model.showsHomeCityOnCards) {
                            Text("Show where you started")
                                .font(.manrope(17, relativeTo: .body))
                                .foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.accent)
                        Text("\(journey.start.name) is close to home, so it's left off the postcard unless you turn this on.")
                            .font(.manrope(15, relativeTo: .footnote))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ShareCardButton(title: content.headline, key: content) {
                        ShareRenderer.postcard(content)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 16)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(postcard.milestone?.name ?? "Postcard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.markSeen(postcard) }
    }
}

/// A postcard on its own sheet, opened from Home.
struct PostcardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let postcard: Postcard

    var body: some View {
        NavigationStack {
            PostcardDetailView(postcard: postcard)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .tint(Theme.ink)
    }
}

/// The all-time story card with its share action.
struct StoryShareSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        let content = model.storyContent
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScaledCard(size: StoryCard.size) { StoryCard(content: content) }
                        .frame(maxHeight: 520)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)

                    if let home = model.homePlace {
                        Toggle(isOn: $model.showsHomeCityOnCards) {
                            Text("Show \(home.name) on the card")
                                .font(.manrope(17, relativeTo: .body))
                                .foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.accent)
                    }

                    ShareCardButton(title: "\(content.number) \(content.unit) walked without noticing", key: content) {
                        ShareRenderer.story(content)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
    }
}
