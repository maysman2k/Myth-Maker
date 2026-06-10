import SwiftUI

/// One chat per event. Banter lives here; decisions show up as system
/// moments so nothing important gets buried.
struct ChatView: View {
    @Environment(AppModel.self) private var model
    let eventID: String

    @State private var draft = ""
    private let quickReactions = ["❤️", "😂", "🔥", "👍"]

    var body: some View {
        let messages = model.messages(for: eventID)

        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: PlanrSpacing.md) {
                    if messages.isEmpty {
                        EmptyStateView(symbol: "bubble.left.and.bubble.right",
                                       title: "Quiet in here",
                                       message: "Say something. Set the tone. No pressure.")
                    }
                    ForEach(messages) { message in
                        messageRow(message)
                    }
                }
                .padding(.horizontal, PlanrSpacing.screenMargin)
                .padding(.vertical, PlanrSpacing.lg)
            }
            .defaultScrollAnchor(.bottom)

            inputBar
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        if message.kind == .system {
            Text(message.text)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, PlanrSpacing.lg)
                .padding(.vertical, PlanrSpacing.sm)
                .background(Capsule().fill(PlanrColor.statusLocked.opacity(0.12)))
                .foregroundStyle(PlanrColor.statusLocked)
                .frame(maxWidth: .infinity)
        } else {
            let isMine = message.senderID == model.currentUser?.id
            HStack(alignment: .bottom, spacing: PlanrSpacing.sm) {
                if isMine { Spacer(minLength: 40) }
                if !isMine {
                    AvatarView(profile: message.senderID.flatMap { model.user(withID: $0) }, size: 28)
                }
                VStack(alignment: isMine ? .trailing : .leading, spacing: PlanrSpacing.xs) {
                    if !isMine {
                        Text(model.displayName(for: message.senderID))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(message.text)
                        .font(PlanrFont.body)
                        .padding(.horizontal, PlanrSpacing.md)
                        .padding(.vertical, PlanrSpacing.sm + 2)
                        .background(
                            RoundedRectangle(cornerRadius: PlanrRadius.card, style: .continuous)
                                .fill(isMine ? AnyShapeStyle(PlanrColor.ember.gradient)
                                             : AnyShapeStyle(PlanrColor.surfacePrimary))
                        )
                        .foregroundStyle(isMine ? .white : .primary)
                        .contextMenu {
                            ForEach(quickReactions, id: \.self) { emoji in
                                Button {
                                    model.toggleReaction(emoji, on: message)
                                } label: {
                                    Text(emoji)
                                }
                            }
                        }
                    if !message.reactions.isEmpty {
                        reactionChips(for: message)
                    }
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if !isMine { Spacer(minLength: 40) }
            }
        }
    }

    private func reactionChips(for message: ChatMessage) -> some View {
        HStack(spacing: PlanrSpacing.xs) {
            ForEach(message.reactions.sorted(by: { $0.key < $1.key }), id: \.key) { emoji, userIDs in
                Button {
                    model.toggleReaction(emoji, on: message)
                } label: {
                    Text("\(emoji) \(userIDs.count)")
                        .font(.caption2)
                        .padding(.horizontal, PlanrSpacing.sm)
                        .padding(.vertical, PlanrSpacing.xs)
                        .background(Capsule().fill(.secondary.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: PlanrSpacing.sm) {
            TextField("Say something…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(PlanrSpacing.md)
        .background(.bar)
    }

    private func send() {
        model.sendMessage(draft, in: eventID)
        draft = ""
    }
}
