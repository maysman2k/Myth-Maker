import SwiftUI

struct ReviewDetailView: View {
    @Environment(AppModel.self) private var model
    var reviewID: UUID
    @State private var isRating = false

    private var review: Review? {
        model.reviews.first { $0.id == reviewID }
    }

    var body: some View {
        Group {
            if let review {
                content(for: review)
            } else {
                EmptyStateView(symbol: "star.bubble", message: "Something went wrong loading this review. Try again in a moment.")
            }
        }
        .background { BrickScreenBackground() }
        .onAppear { model.incrementView(.review, reviewID) }
    }

    private func content(for review: Review) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                BrickArtView(seed: review.id.artSeed, tint: BrickColor.gold, symbol: "shippingbox")
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack {
                    TagBadge(text: review.brand, tint: BrickColor.stadiumGreen)
                    TagBadge(text: review.category.rawValue)
                    Spacer()
                }

                Text(review.setName)
                    .font(BrickFont.pageTitle)
                    .foregroundStyle(BrickColor.primaryText)

                HStack(spacing: BrickSpacing.m) {
                    StarRatingView(rating: review.ratingOverall, size: 18)
                    Text(review.ratingOverall.formatted(.number.precision(.fractionLength(1))) + " / 5")
                        .font(BrickFont.cardTitle)
                        .foregroundStyle(BrickColor.primaryText)
                    TagBadge(text: review.verdict.rawValue, tint: review.verdict.isPositive ? BrickColor.gold : BrickColor.brickRed)
                }

                Text(review.summary)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BrickColor.secondaryText)

                factsCard(for: review)
                breakdownCard(for: review)
                prosConsCard(for: review)

                MarkdownBody(markdown: review.bodyMarkdown)

                EngagementBar(
                    contentType: .review,
                    contentID: review.id,
                    likeCount: review.likeCount,
                    shareText: "Check this review on Bricks in a Bag: \(review.setName) — https://bricksinabag.com/reviews/\(review.slug)"
                )

                communityRatingCard(for: review)

                Divider()

                if review.commentsEnabled {
                    CommentsSectionView(
                        contentType: .review,
                        contentID: review.id,
                        prompt: "Built this set? Leave your rating."
                    )
                }
                LegalDisclaimerFooter()
            }
            .padding(.horizontal, BrickSpacing.l)
            .padding(.top, BrickSpacing.m)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isRating) {
            RateReviewSheet(review: review)
                .presentationDetents([.medium, .large])
        }
    }

    private func factsCard(for review: Review) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            factRow("Set number", review.setNumber ?? "—")
            factRow("Pieces", review.pieceCount.map { "\($0)" } ?? "—")
            factRow("Retail price", review.priceLabel)
            factRow("Release year", review.releaseYear.map { "\($0)" } ?? "—")
            factRow("Age range", review.ageRange ?? "—")
            factRow("Availability", review.availability)
            factRow("Build difficulty", review.buildDifficulty)
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }

    private func factRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrickColor.primaryText)
        }
    }

    private func breakdownCard(for review: Review) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            Text("Rating breakdown")
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
            ForEach(review.breakdown.categories, id: \.name) { category in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(category.name)
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                        Spacer()
                        Text(category.score.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BrickColor.primaryText)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(BrickColor.border)
                            Capsule()
                                .fill(BrickColor.gold)
                                .frame(width: proxy.size.width * category.score / 5)
                        }
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)
                }
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private func prosConsCard(for review: Review) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                Text("Pros")
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.stadiumGreen)
                ForEach(review.pros, id: \.self) { pro in
                    Label(pro, systemImage: "plus.circle.fill")
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.primaryText)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                Text("Cons")
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.brickRed)
                ForEach(review.cons, id: \.self) { con in
                    Label(con, systemImage: "minus.circle.fill")
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.primaryText)
                }
            }
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }

    private func communityRatingCard(for review: Review) -> some View {
        let ratings = model.communityRatings(for: review.id)
        let average = ratings.isEmpty ? nil : ratings.map(\.rating).reduce(0, +) / Double(ratings.count)
        return VStack(alignment: .leading, spacing: BrickSpacing.m) {
            Text("Builder ratings")
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
            if let average {
                HStack(spacing: BrickSpacing.m) {
                    StarRatingView(rating: average)
                    Text("\(average.formatted(.number.precision(.fractionLength(1)))) from \(ratings.count) builder\(ratings.count == 1 ? "" : "s")")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                }
            } else {
                Text("Built this set? Add your rating and help other builders decide.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            Button(model.myRating(for: review.id) == nil ? "Add your rating" : "Update your rating") {
                if model.requireAccount() { isRating = true }
            }
            .buttonStyle(StudButtonStyle())
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}

private struct RateReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var review: Review

    @State private var rating: Double = 4
    @State private var comment = ""
    @State private var ownsSet = false
    @State private var builtSet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Your rating") {
                    HStack {
                        StarRatingView(rating: rating, size: 24)
                        Spacer()
                        Stepper(
                            rating.formatted(.number.precision(.fractionLength(0...1))),
                            value: $rating,
                            in: 0.5...5,
                            step: 0.5
                        )
                    }
                }
                Section("About your build") {
                    Toggle("I own this set", isOn: $ownsSet)
                    Toggle("I built this set", isOn: $builtSet)
                }
                Section("Short comment (optional)") {
                    TextField("What stood out?", text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(review.setName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        model.submitRating(reviewID: review.id, rating: rating, comment: comment, ownsSet: ownsSet, builtSet: builtSet)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let existing = model.myRating(for: review.id) {
                    rating = existing.rating
                    comment = existing.comment
                    ownsSet = existing.ownsSet
                    builtSet = existing.builtSet
                }
            }
        }
    }
}
