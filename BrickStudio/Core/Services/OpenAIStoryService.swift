import Foundation

enum OpenAIStoryService {
    static let apiKeychainKey = "openai-api-key"

    struct Draft: Codable, Equatable {
        var title: String
        var summary: String
        var bodyMarkdown: String
        var tags: [String]
        var category: ArticleCategory
        var isRumour: Bool
    }

    enum ServiceError: LocalizedError {
        case missingKey
        case invalidResponse
        case rejected(Int, String)

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "OpenAI is not configured. Add an API key in Admin first."
            case .invalidResponse:
                return "OpenAI returned a draft the app could not read. Try again with a clearer brief."
            case .rejected(let code, let message):
                return "OpenAI request failed (\(code)): \(message)"
            }
        }
    }

    static func generateStory(from brief: String, apiKey: String? = nil) async throws -> Draft {
        let key = apiKey ?? KeychainStore.load(apiKeychainKey) ?? ""
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingKey
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload(for: brief))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data).error.message) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ServiceError.rejected(http.statusCode, message)
        }

        let envelope = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)
        guard let text = envelope.outputText, let jsonData = extractJSON(from: text).data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }
        return try JSONDecoder().decode(Draft.self, from: jsonData)
    }

    private static func payload(for brief: String) -> [String: Any] {
        let categories = ArticleCategory.allCases.map(\.rawValue).joined(separator: ", ")
        return [
            "model": "gpt-4.1-mini",
            "instructions": """
            You write polished Bricks in a Bag app news stories for LEGO and compatible-brick fans.
            Return JSON only. Use Markdown for bodyMarkdown: ## subheadings, paragraphs, bullet points, **bold**, _italic_, and <u>underline</u> only where useful.
            Keep it friendly, factual, concise, and clearly original. Do not invent exact prices, dates, quotes, or claims unless supplied in the brief.
            category must be one of: \(categories).
            tags should be 3 to 6 short strings.
            """,
            "input": "Write a publish-ready story from this brief:\n\n\(brief)",
            "temperature": 0.7
        ]
    }

    private static func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            return trimmed
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            return trimmed
        }
        return String(trimmed[start...end])
    }
}

private struct OpenAIResponseEnvelope: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            var text: String?
        }

        var content: [ContentItem]?
    }

    var output: [OutputItem]?
    var outputTextDirect: String?

    var outputText: String? {
        outputTextDirect ?? output?.compactMap { item in
            item.content?.compactMap(\.text).joined(separator: "\n")
        }.joined(separator: "\n")
    }

    enum CodingKeys: String, CodingKey {
        case output
        case outputTextDirect = "output_text"
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        var message: String
    }

    var error: APIError
}
