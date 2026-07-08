import XCTest
@testable import BrickStudio

final class RequestValidatorTests: XCTestCase {
    private func makeRequest(
        title: String = "St James' Park model",
        description: String = "A display model of the ground with premium presentation.",
        deadlineType: DeadlineType = .noRush,
        deadlineDate: Date? = nil,
        email: String = "fan@example.com"
    ) -> BrickBarRequest {
        BrickBarRequest(
            id: UUID(),
            userID: UUID(),
            buildType: .footballStadium,
            title: title,
            description: description,
            referenceImageFilenames: [],
            sizePreference: .medium,
            budgetRange: .from500to1000,
            deadlineType: deadlineType,
            deadlineDate: deadlineDate,
            contactEmail: email,
            contactPhone: "",
            status: .draft,
            adminNotes: "",
            quotedPrice: nil,
            quoteStatus: .notQuoted,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func testValidRequestPassesEveryStep() {
        let request = makeRequest()
        for step in RequestStep.allCases {
            XCTAssertNil(RequestValidator.validate(step: step, request: request), "Step \(step) unexpectedly failed")
        }
        XCTAssertNil(RequestValidator.firstInvalidStep(for: request))
    }

    func testMissingTitleFailsIdeaStep() {
        let request = makeRequest(title: "   ")
        XCTAssertNotNil(RequestValidator.validate(step: .idea, request: request))
        XCTAssertEqual(RequestValidator.firstInvalidStep(for: request), .idea)
    }

    func testShortDescriptionFailsIdeaStep() {
        let request = makeRequest(description: "A stadium")
        XCTAssertNotNil(RequestValidator.validate(step: .idea, request: request))
    }

    func testSpecificDateRequiresFutureDate() {
        let missing = makeRequest(deadlineType: .specificDate, deadlineDate: nil)
        XCTAssertNotNil(RequestValidator.validate(step: .deadline, request: missing))

        let past = makeRequest(deadlineType: .specificDate, deadlineDate: Date().addingTimeInterval(-86_400))
        XCTAssertNotNil(RequestValidator.validate(step: .deadline, request: past))

        let future = makeRequest(deadlineType: .specificDate, deadlineDate: Date().addingTimeInterval(86_400))
        XCTAssertNil(RequestValidator.validate(step: .deadline, request: future))
    }

    func testInvalidEmailFailsContactStep() {
        XCTAssertNotNil(RequestValidator.validate(step: .contact, request: makeRequest(email: "not-an-email")))
        XCTAssertNotNil(RequestValidator.validate(step: .contact, request: makeRequest(email: "a@b")))
        XCTAssertNil(RequestValidator.validate(step: .contact, request: makeRequest(email: "a@b.co")))
    }

    func testEmailValidation() {
        XCTAssertTrue(RequestValidator.isValidEmail("pete@bricksinabag.com"))
        XCTAssertFalse(RequestValidator.isValidEmail(""))
        XCTAssertFalse(RequestValidator.isValidEmail("pete@"))
        XCTAssertFalse(RequestValidator.isValidEmail("pete@domain"))
        XCTAssertFalse(RequestValidator.isValidEmail("pete smith@domain.com"))
        XCTAssertFalse(RequestValidator.isValidEmail("pete@domain."))
    }
}
