import XCTest
@testable import BrickStudio

final class DraftFeedTests: XCTestCase {
    /// Decodes the exact JSON shape NewsScanner/scanner.py writes.
    func testDecodesScannerFeedJSON() throws {
        let json = """
        [
          {
            "id": "6639460f-3425-5329-8097-a58f06127860",
            "title": "New modular building rumours surface",
            "summary": "Community sources point to a corner modular next year.",
            "bodyMarkdown": "## What happened\\nRumours.\\n\\n## Why it matters\\nCollectors care.",
            "category": "Rumours",
            "tags": ["rumour", "modular-buildings"],
            "sourceLinks": [
              {"id": "5f10ed2e-a531-5415-8ec7-8aba13e0ee11", "name": "Brickset", "url": "https://example.com/story"}
            ],
            "isRumour": true,
            "relevanceScore": 78,
            "riskNotes": "Unconfirmed. Suggested images were scraped from the source page - licence unknown.",
            "status": "needs_review",
            "foundAt": "2026-07-07T09:00:00Z",
            "suggestedImageURLs": ["https://example.com/a.jpg", "https://example.com/b.jpg"]
          }
        ]
        """
        let drafts = try DraftFeedService.decode(Data(json.utf8))
        XCTAssertEqual(drafts.count, 1)
        let draft = try XCTUnwrap(drafts.first)
        XCTAssertEqual(draft.category, .rumours)
        XCTAssertEqual(draft.status, .needsReview)
        XCTAssertTrue(draft.isRumour)
        XCTAssertEqual(draft.relevanceScore, 78)
        XCTAssertEqual(draft.suggestedImageURLs?.count, 2)
        XCTAssertEqual(draft.sourceLinks.first?.name, "Brickset")
    }

    /// Older/seeded drafts have no suggestedImageURLs key — must still decode.
    func testDecodesDraftWithoutImageKey() throws {
        let json = """
        [
          {
            "id": "6639460f-3425-5329-8097-a58f06127861",
            "title": "T", "summary": "S", "bodyMarkdown": "B",
            "category": "Deals", "tags": [], "sourceLinks": [],
            "isRumour": false, "relevanceScore": 65, "riskNotes": "",
            "status": "needs_review", "foundAt": "2026-07-07T09:00:00Z"
          }
        ]
        """
        let drafts = try DraftFeedService.decode(Data(json.utf8))
        XCTAssertNil(drafts.first?.suggestedImageURLs)
    }

    /// Approving with a chosen image publishes the article with that hero
    /// image; approving without keeps the branded graphic (nil URL).
    func testApprovalCarriesChosenHeroImage() {
        var editor = UserAccount.new(displayName: "Sasha", email: "sasha@example.com", passwordHash: "x", role: .editor)
        editor.createdAt = Date().addingTimeInterval(-90 * 86_400)
        let draft = AIDraft(
            id: UUID(), title: "Imaged draft", summary: "S", bodyMarkdown: "B",
            category: .newSets, tags: [], sourceLinks: [], isRumour: false,
            relevanceScore: 90, riskNotes: "", status: .needsReview, foundAt: Date(),
            suggestedImageURLs: ["https://example.com/a.jpg"]
        )
        var snapshot = AppSnapshot()
        snapshot.accounts = [editor]
        snapshot.aiDrafts = [draft]
        let model = AppModel(snapshot: snapshot)
        model.currentUserID = editor.id

        model.approveAIDraft(draft.id, heroImageURL: "https://example.com/a.jpg")
        let published = model.publishedArticles.first { $0.title == "Imaged draft" }
        XCTAssertEqual(published?.heroImageURL, "https://example.com/a.jpg")
    }

    func testApprovalWithoutImageLeavesBrandedGraphic() {
        var editor = UserAccount.new(displayName: "Sasha", email: "sasha2@example.com", passwordHash: "x", role: .editor)
        editor.createdAt = Date().addingTimeInterval(-90 * 86_400)
        let draft = AIDraft(
            id: UUID(), title: "Plain draft", summary: "S", bodyMarkdown: "B",
            category: .newSets, tags: [], sourceLinks: [], isRumour: false,
            relevanceScore: 90, riskNotes: "", status: .needsReview, foundAt: Date()
        )
        var snapshot = AppSnapshot()
        snapshot.accounts = [editor]
        snapshot.aiDrafts = [draft]
        let model = AppModel(snapshot: snapshot)
        model.currentUserID = editor.id

        model.approveAIDraft(draft.id)
        let published = model.publishedArticles.first { $0.title == "Plain draft" }
        XCTAssertNotNil(published)
        XCTAssertNil(published?.heroImageURL)
    }
}
