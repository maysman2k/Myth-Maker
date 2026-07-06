import SwiftUI

struct LessonsView: View {
    @Environment(AppModel.self) private var model
    @State private var difficultyFilter: LessonDifficulty?

    private var filtered: [Lesson] {
        guard let difficultyFilter else { return model.publishedLessons }
        return model.publishedLessons.filter { $0.difficulty == difficultyFilter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                Text("Design, scale, colour and technique — short lessons from the Bricks in a Bag workshop.")
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)

                HStack(spacing: BrickSpacing.s) {
                    FilterChip(title: "All", isSelected: difficultyFilter == nil) { difficultyFilter = nil }
                    ForEach(LessonDifficulty.allCases, id: \.self) { difficulty in
                        FilterChip(title: difficulty.rawValue, isSelected: difficultyFilter == difficulty) {
                            difficultyFilter = difficultyFilter == difficulty ? nil : difficulty
                        }
                    }
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "graduationcap",
                        message: "No lessons at this level yet — more are on the way.",
                        actionTitle: "Show all lessons",
                        action: { difficultyFilter = nil }
                    )
                } else {
                    ForEach(filtered) { lesson in
                        NavigationLink(value: ContentRoute.lesson(lesson.id)) {
                            LessonCard(lesson: lesson)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Studio Lessons")
    }
}

struct LessonCard: View {
    @Environment(AppModel.self) private var model
    var lesson: Lesson

    private var isCompleted: Bool {
        model.currentUser?.completedLessonIDs.contains(lesson.id) == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            HStack {
                TagBadge(text: lesson.category.rawValue, tint: BrickColor.stadiumGreen)
                TagBadge(text: lesson.difficulty.rawValue)
                Spacer()
                if isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(BrickColor.stadiumGreen)
                        .accessibilityLabel("Completed")
                }
            }
            Text(lesson.title)
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
                .multilineTextAlignment(.leading)
            Text(lesson.summary)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            MetaLabel(symbol: "clock", text: "\(lesson.readTimeMinutes) min read")
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}

struct LessonDetailView: View {
    @Environment(AppModel.self) private var model
    var lessonID: UUID

    private var lesson: Lesson? {
        model.lessons.first { $0.id == lessonID }
    }

    var body: some View {
        Group {
            if let lesson {
                content(for: lesson)
            } else {
                EmptyStateView(symbol: "graduationcap", message: "Something went wrong loading this lesson. Try again in a moment.")
            }
        }
        .background(BrickColor.background)
        .onAppear { model.incrementView(.lesson, lessonID) }
    }

    private func content(for lesson: Lesson) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                BrickArtView(seed: lesson.id.artSeed, tint: BrickColor.stadiumGreen, symbol: "graduationcap")
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack {
                    TagBadge(text: lesson.category.rawValue, tint: BrickColor.stadiumGreen)
                    TagBadge(text: lesson.difficulty.rawValue)
                    Spacer()
                    MetaLabel(symbol: "clock", text: "\(lesson.readTimeMinutes) min")
                }

                Text(lesson.title)
                    .font(BrickFont.pageTitle)
                    .foregroundStyle(BrickColor.primaryText)

                Text(lesson.summary)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BrickColor.secondaryText)

                MarkdownBody(markdown: lesson.bodyMarkdown)

                EngagementBar(
                    contentType: .lesson,
                    contentID: lesson.id,
                    likeCount: lesson.likeCount,
                    shareText: "Check this Studio Lesson on Bricks in a Bag: \(lesson.title) — https://bricksinabag.com/lessons/\(lesson.slug)"
                )

                Button {
                    model.toggleLessonCompleted(lesson.id)
                } label: {
                    Label(
                        model.currentUser?.completedLessonIDs.contains(lesson.id) == true ? "Completed" : "Mark as completed",
                        systemImage: model.currentUser?.completedLessonIDs.contains(lesson.id) == true ? "checkmark.seal.fill" : "checkmark.seal"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen, prominent: model.currentUser?.completedLessonIDs.contains(lesson.id) != true))

                NavigationLink {
                    RequestFlowView()
                } label: {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                        Text("Want it built for you? Visit The Brick Bar")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                    .padding(BrickSpacing.l)
                    .brickCard()
                }
                .buttonStyle(.plain)

                if lesson.commentsEnabled {
                    Divider()
                    CommentsSectionView(contentType: .lesson, contentID: lesson.id, prompt: nil)
                }
                LegalDisclaimerFooter()
            }
            .padding(.horizontal, BrickSpacing.l)
            .padding(.top, BrickSpacing.m)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
