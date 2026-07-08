import SwiftUI

// MARK: - Section header

struct SectionHeader: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(BrickFont.sectionTitle)
                .foregroundStyle(BrickColor.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrickColor.gold)
            }
        }
    }
}

// MARK: - Empty state (§6.2)

struct EmptyStateView: View {
    var symbol: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: BrickSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(BrickColor.secondaryText)
            Text(message)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(StudButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(BrickSpacing.xl)
    }
}

// MARK: - Toast (§6.5)

struct ToastView: View {
    var toast: Toast

    var body: some View {
        HStack(spacing: BrickSpacing.s) {
            Image(systemName: toast.symbol)
                .foregroundStyle(BrickColor.gold)
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrickColor.primaryText)
                .lineLimit(2)
        }
        .padding(.horizontal, BrickSpacing.l)
        .padding(.vertical, BrickSpacing.m)
        .background(BrickColor.card)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(BrickColor.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

// MARK: - Star rating

struct StarRatingView: View {
    var rating: Double
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: symbolName(for: star))
                    .font(.system(size: size))
                    .foregroundStyle(BrickColor.gold)
            }
        }
        .accessibilityLabel("Rated \(rating.formatted(.number.precision(.fractionLength(0...1)))) out of 5")
    }

    private func symbolName(for star: Int) -> String {
        let value = Double(star)
        if rating >= value - 0.25 { return "star.fill" }
        if rating >= value - 0.75 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - Badges & chips

struct TagBadge: View {
    var text: String
    var tint: Color = BrickColor.gold

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

struct RumourBadge: View {
    var body: some View {
        TagBadge(text: "Rumour", tint: BrickColor.brickRed)
    }
}

struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(isSelected ? BrickColor.primaryText : BrickColor.card)
                .foregroundStyle(isSelected ? BrickColor.background : BrickColor.primaryText)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(BrickColor.border, lineWidth: isSelected ? 0 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Meta label

struct MetaLabel: View {
    var symbol: String
    var text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(BrickFont.meta)
            .foregroundStyle(BrickColor.secondaryText)
    }
}

// MARK: - Avatar

struct AvatarView: View {
    var name: String
    var size: CGFloat = 36

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(BrickColor.gold))
            .accessibilityLabel(name)
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

// MARK: - Engagement bar (like / bookmark / share)

struct EngagementBar: View {
    @Environment(AppModel.self) private var model
    var contentType: ContentType
    var contentID: UUID
    var likeCount: Int
    var shareText: String

    var body: some View {
        HStack(spacing: BrickSpacing.xl) {
            Button {
                model.toggleLike(contentType, contentID)
            } label: {
                Label("\(likeCount)", systemImage: model.isLiked(contentType, contentID) ? "heart.fill" : "heart")
            }
            .foregroundStyle(model.isLiked(contentType, contentID) ? BrickColor.brickRed : BrickColor.secondaryText)
            .accessibilityLabel(model.isLiked(contentType, contentID) ? "Unlike" : "Like")

            Button {
                model.toggleBookmark(contentType, contentID)
            } label: {
                Image(systemName: model.isBookmarked(contentType, contentID) ? "bookmark.fill" : "bookmark")
            }
            .foregroundStyle(model.isBookmarked(contentType, contentID) ? BrickColor.gold : BrickColor.secondaryText)
            .accessibilityLabel(model.isBookmarked(contentType, contentID) ? "Remove bookmark" : "Bookmark")

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
            }
            .foregroundStyle(BrickColor.secondaryText)

            Spacer()
        }
        .font(.system(size: 17))
        .frame(minHeight: 44)
    }
}

// MARK: - Markdown body renderer

/// Lightweight renderer for the article/lesson markdown used in this app:
/// `##` section headings, `-` bullets, and paragraphs with inline styling.
struct MarkdownBody: View {
    var markdown: String

    private struct Block: Identifiable {
        enum Kind { case heading, bullet, paragraph }
        let id: Int
        let kind: Kind
        let text: String
    }

    private var blocks: [Block] {
        var result: [Block] = []
        for (index, rawLine) in markdown.components(separatedBy: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("## ") {
                result.append(Block(id: index, kind: .heading, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("- ") {
                result.append(Block(id: index, kind: .bullet, text: String(line.dropFirst(2))))
            } else {
                result.append(Block(id: index, kind: .paragraph, text: line))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading:
                    Text(block.text)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(BrickColor.primaryText)
                        .padding(.top, BrickSpacing.s)
                case .bullet:
                    HStack(alignment: .top, spacing: BrickSpacing.s) {
                        Circle()
                            .fill(BrickColor.gold)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        inlineText(block.text)
                    }
                case .paragraph:
                    inlineText(block.text)
                }
            }
        }
    }

    private func inlineText(_ text: String) -> some View {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return Text(attributed)
            .font(BrickFont.body)
            .foregroundStyle(BrickColor.primaryText)
            .lineSpacing(4)
    }
}

// MARK: - Legal footer (§30.1)

struct LegalDisclaimerFooter: View {
    var body: some View {
        Text("LEGO® is a trademark of the LEGO Group, which does not sponsor, authorise or endorse this app.")
            .font(.system(size: 11))
            .foregroundStyle(BrickColor.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BrickSpacing.l)
    }
}
