import Foundation

enum AIDraftStatus: String, Codable {
    case needsReview = "needs_review"
    case approved
    case rejected
}

/// An AI-drafted article awaiting human review (§10). Drafts never publish
/// automatically — an editor or admin must approve them first.
struct AIDraft: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var summary: String
    var bodyMarkdown: String
    var category: ArticleCategory
    var tags: [String]
    var sourceLinks: [ArticleSource]
    var isRumour: Bool
    var relevanceScore: Int
    var riskNotes: String
    var status: AIDraftStatus
    var foundAt: Date
    /// Candidate images scraped from the source page by the news scanner.
    /// Licence is unknown until the editor checks it — an editor explicitly
    /// picks one (or none) at approval time (§10.8).
    var suggestedImageURLs: [String]? = nil

    /// Relevance banding from §10.4.
    var relevanceBand: String {
        switch relevanceScore {
        case ..<31: return "Ignore"
        case 31...60: return "Low priority"
        case 61...80: return "Draft-worthy"
        default: return "High priority"
        }
    }
}
