import Foundation

/// Step-by-step validation for the Brick Bar request flow (§27.14 — each
/// step must validate before continuing).
enum RequestStep: Int, CaseIterable {
    case buildType
    case idea
    case sizeAndBudget
    case deadline
    case contact
    case review

    var title: String {
        switch self {
        case .buildType: return "What should we build?"
        case .idea: return "Tell us the idea"
        case .sizeAndBudget: return "Size and budget"
        case .deadline: return "When do you need it?"
        case .contact: return "Contact details"
        case .review: return "Review your request"
        }
    }
}

enum RequestValidator {
    static let minimumDescriptionLength = 20

    static func validate(step: RequestStep, request: BrickBarRequest) -> String? {
        switch step {
        case .buildType:
            return nil // A build type is always selected.
        case .idea:
            if request.title.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Give your build a short title."
            }
            if request.description.trimmingCharacters(in: .whitespacesAndNewlines).count < minimumDescriptionLength {
                return "Tell us a little more — at least \(minimumDescriptionLength) characters helps us quote accurately."
            }
            return nil
        case .sizeAndBudget:
            return nil // Ranges are always selected.
        case .deadline:
            if request.deadlineType == .specificDate {
                guard let date = request.deadlineDate else {
                    return "Pick the date you need the build by."
                }
                if date < Date() {
                    return "The deadline needs to be in the future."
                }
            }
            return nil
        case .contact:
            if !isValidEmail(request.contactEmail) {
                return "Enter a valid email so we can reply with next steps."
            }
            return nil
        case .review:
            return nil
        }
    }

    static func firstInvalidStep(for request: BrickBarRequest) -> RequestStep? {
        RequestStep.allCases.first { validate(step: $0, request: request) != nil }
    }

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 5, trimmed.contains("@"), !trimmed.contains(" ") else { return false }
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2, let domain = parts.last, domain.contains(".") else { return false }
        return !(domain.hasPrefix(".") || domain.hasSuffix("."))
    }
}
