import Foundation

enum ImageModerationDecision: Equatable {
    case notChecked
    case checking
    case approved(String)
    case blocked(String)
    case unavailable(String)

    var canGenerate: Bool {
        if case .approved = self {
            return true
        }
        return false
    }

    var message: String? {
        switch self {
        case .notChecked, .checking:
            return nil
        case .approved(let message),
             .blocked(let message),
             .unavailable(let message):
            return message
        }
    }
}

struct ImageModerationService {
    private static let moderationEndpoint: URL? = URL(string: "https://biab-mosaic-maker-api-549164471999.europe-west2.run.app/api/moderate")

    static func check(imageData: Data) async -> ImageModerationDecision {
        guard let moderationEndpoint else {
            return .unavailable("Image safety check is not connected yet.")
        }

        var request = URLRequest(url: moderationEndpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(imageData: imageData, boundary: boundary)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .blocked("We could not complete the image safety check. Please try again.")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let responseMessage = String(data: data, encoding: .utf8) ?? "No response body."
                return .blocked("We could not complete the image safety check. Please try again. \(responseMessage)")
            }

            let payload = try JSONDecoder().decode(ModerationResponse.self, from: data)
            switch payload.status {
            case "approved":
                return .approved(payload.message)
            case "blocked":
                return .blocked(payload.message)
            case "manual_review":
                return .blocked(payload.message.replacingOccurrences(of: "manual review", with: "another photo"))
            default:
                return payload.allowed
                    ? .approved(payload.message)
                    : .blocked("This image cannot be used. Please choose another photo.")
            }
        } catch {
            return .blocked("We could not complete the image safety check. Please try again.")
        }
    }

    private static func multipartBody(imageData: Data, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.png\"\r\n")
        body.append("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }
}

private struct ModerationResponse: Decodable {
    let status: String
    let allowed: Bool
    let message: String
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
