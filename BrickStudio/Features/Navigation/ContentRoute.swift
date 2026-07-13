import SwiftUI

/// Typed navigation routes for content detail screens, usable from any tab's
/// NavigationStack (Today, News, Search, Profile, Notifications…).
enum ContentRoute: Hashable {
    case article(UUID)
    case review(UUID)
    case product(UUID)
    case lesson(UUID)
    case brickBarRequest(UUID)
    case communityPost(UUID)
    case challenge(UUID)
    case builder(UUID)

    init?(type: ContentType, id: UUID) {
        switch type {
        case .article: self = .article(id)
        case .review: self = .review(id)
        case .product: self = .product(id)
        case .lesson: self = .lesson(id)
        case .brickBarRequest: self = .brickBarRequest(id)
        case .communityPost: self = .communityPost(id)
        default: return nil
        }
    }
}

struct ContentRouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: ContentRoute.self) { route in
            switch route {
            case .article(let id): ArticleDetailView(articleID: id)
            case .review(let id): ReviewDetailView(reviewID: id)
            case .product(let id): ProductDetailView(productID: id)
            case .lesson(let id): LessonDetailView(lessonID: id)
            case .brickBarRequest(let id): RequestDetailView(requestID: id)
            case .communityPost(let id): CommunityPostDetailView(postID: id)
            case .challenge(let id): ChallengeDetailView(challengeID: id)
            case .builder(let id): BuilderProfileView(userID: id)
            }
        }
    }
}

extension View {
    /// Attach inside every NavigationStack that pushes content details.
    func contentRouteDestinations() -> some View {
        modifier(ContentRouteDestinations())
    }
}
