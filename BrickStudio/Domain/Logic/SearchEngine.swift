import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case news = "News"
    case reviews = "Reviews"
    case shop = "Builds"
    case lessons = "Lessons"

    var id: String { rawValue }

    var contentTypes: [ContentType] {
        switch self {
        case .all: return [.article, .review, .product, .lesson]
        case .news: return [.article]
        case .reviews: return [.review]
        case .shop: return [.product]
        case .lessons: return [.lesson]
        }
    }
}

struct SearchDocument: Identifiable, Hashable {
    var id: UUID
    var contentType: ContentType
    var title: String
    var summary: String
    var tags: [String]
}

struct SearchResult: Identifiable, Hashable {
    var document: SearchDocument
    var score: Int

    var id: UUID { document.id }
}

enum SearchEngine {
    static let minimumQueryLength = 2

    static func search(_ rawQuery: String, in documents: [SearchDocument], scope: SearchScope = .all) -> [SearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= minimumQueryLength else { return [] }
        let terms = query.split(separator: " ").map(String.init)

        return documents
            .filter { scope.contentTypes.contains($0.contentType) }
            .compactMap { document -> SearchResult? in
                let score = score(document: document, terms: terms)
                return score > 0 ? SearchResult(document: document, score: score) : nil
            }
            .sorted { lhs, rhs in
                lhs.score != rhs.score ? lhs.score > rhs.score : lhs.document.title < rhs.document.title
            }
    }

    private static func score(document: SearchDocument, terms: [String]) -> Int {
        let title = document.title.lowercased()
        let summary = document.summary.lowercased()
        let tags = document.tags.map { $0.lowercased() }
        var total = 0
        for term in terms {
            var termScore = 0
            if title.hasPrefix(term) { termScore += 6 }
            if title.contains(term) { termScore += 4 }
            if tags.contains(where: { $0.contains(term) }) { termScore += 3 }
            if summary.contains(term) { termScore += 1 }
            // Every term must match somewhere, otherwise the document is out.
            if termScore == 0 { return 0 }
            total += termScore
        }
        return total
    }
}
