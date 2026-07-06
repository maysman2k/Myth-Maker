import XCTest
@testable import BrickStudio

final class SearchEngineTests: XCTestCase {
    private let documents = [
        SearchDocument(id: UUID(), contentType: .article, title: "Stadium build diary", summary: "Behind the scenes of a stadium commission", tags: ["stadium", "moc"]),
        SearchDocument(id: UUID(), contentType: .review, title: "Grand Arena Stadium Kit review", summary: "A big compatible-brand stadium", tags: ["CaDA"]),
        SearchDocument(id: UUID(), contentType: .product, title: "Photo Mosaic — Framed", summary: "Your photo in bricks", tags: ["mosaic", "gift"]),
        SearchDocument(id: UUID(), contentType: .lesson, title: "Mosaic colour mapping", summary: "Why photos look wrong in bricks", tags: ["mosaic"])
    ]

    func testQueryTooShortReturnsNothing() {
        XCTAssertTrue(SearchEngine.search("s", in: documents).isEmpty)
        XCTAssertTrue(SearchEngine.search("  ", in: documents).isEmpty)
    }

    func testTitleMatchOutranksSummaryMatch() {
        let results = SearchEngine.search("stadium", in: documents)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.document.title, "Stadium build diary")
    }

    func testScopeFiltersByContentType() {
        let results = SearchEngine.search("mosaic", in: documents, scope: .lessons)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.document.contentType, .lesson)
    }

    func testAllTermsMustMatch() {
        let results = SearchEngine.search("mosaic stadium", in: documents)
        XCTAssertTrue(results.isEmpty)
    }

    func testCaseInsensitive() {
        let results = SearchEngine.search("MOSAIC", in: documents)
        XCTAssertEqual(results.count, 2)
    }

    func testTagMatching() {
        let results = SearchEngine.search("gift", in: documents)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.document.contentType, .product)
    }
}
