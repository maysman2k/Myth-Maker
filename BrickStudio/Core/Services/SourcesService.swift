import Foundation

/// One approved news source (§10.3). Mirrors NewsScanner/sources.json —
/// the single source of truth the scanner reads on every run.
struct NewsSource: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssUrl: String
    var enabled: Bool
    var sourceType: String
    var notes: String

    init(id: UUID = UUID(), name: String = "", rssUrl: String = "", enabled: Bool = true, sourceType: String = "RSS", notes: String = "") {
        self.id = id
        self.name = name
        self.rssUrl = rssUrl
        self.enabled = enabled
        self.sourceType = sourceType
        self.notes = notes
    }

    var host: String {
        URL(string: rssUrl)?.host ?? rssUrl
    }
}

extension NewsSource: Codable {
    // `id` is app-local only — the JSON file carries just these keys.
    enum CodingKeys: String, CodingKey {
        case name, rssUrl, enabled, sourceType, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try container.decode(String.self, forKey: .name)
        rssUrl = try container.decode(String.self, forKey: .rssUrl)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? "RSS"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(rssUrl, forKey: .rssUrl)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(notes, forKey: .notes)
    }
}

/// Reads and writes the scanner's source list in the GitHub repo. Writes go
/// through the GitHub Contents API, so the admin token needs
/// Contents: Read and write as well as Actions: Read and write.
enum SourcesService {
    static let filePath = "NewsScanner/sources.json"

    enum SourcesError: LocalizedError {
        case unreachable
        case badToken
        case conflict
        case failed(Int)

        var errorDescription: String? {
            switch self {
            case .unreachable:
                return "Couldn't reach the source list on GitHub. Try again in a moment."
            case .badToken:
                return "GitHub rejected the token for editing files. It needs Contents: Read and write on \(GitHubWorkflowService.owner)/\(GitHubWorkflowService.repo)."
            case .conflict:
                return "The source list changed elsewhere while you were editing. Pull to refresh and try again."
            case .failed(let code):
                return "GitHub returned an unexpected response (\(code)). Try again in a moment."
            }
        }
    }

    static var rawURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(GitHubWorkflowService.owner)/\(GitHubWorkflowService.repo)/\(GitHubWorkflowService.ref)/\(filePath)")!
    }

    static var contentsURL: URL {
        URL(string: "https://api.github.com/repos/\(GitHubWorkflowService.owner)/\(GitHubWorkflowService.repo)/contents/\(filePath)")!
    }

    static func fetch() async throws -> [NewsSource] {
        var request = URLRequest(url: rawURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SourcesError.unreachable
        }
        return try JSONDecoder().decode([NewsSource].self, from: data)
    }

    static func save(_ sources: [NewsSource], token: String) async throws {
        // 1. Fetch the current file's SHA (required by the Contents API).
        var shaRequest = URLRequest(url: contentsURL.appending(queryItems: [URLQueryItem(name: "ref", value: GitHubWorkflowService.ref)]))
        applyHeaders(to: &shaRequest, token: token)
        let (shaData, shaResponse) = try await URLSession.shared.data(for: shaRequest)
        guard let shaHTTP = shaResponse as? HTTPURLResponse else { throw SourcesError.unreachable }
        switch shaHTTP.statusCode {
        case 200: break
        case 401, 403, 404: throw SourcesError.badToken
        default: throw SourcesError.failed(shaHTTP.statusCode)
        }
        guard let object = try JSONSerialization.jsonObject(with: shaData) as? [String: Any],
              let sha = object["sha"] as? String else {
            throw SourcesError.unreachable
        }

        // 2. Encode the updated list the same way the repo stores it.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var body = try encoder.encode(sources)
        body.append(Data("\n".utf8))

        // 3. Commit via the Contents API.
        var putRequest = URLRequest(url: contentsURL)
        putRequest.httpMethod = "PUT"
        applyHeaders(to: &putRequest, token: token)
        putRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "message": "Update news sources from Bricks in a Bag Studio",
            "content": body.base64EncodedString(),
            "sha": sha,
            "branch": GitHubWorkflowService.ref
        ])
        let (_, putResponse) = try await URLSession.shared.data(for: putRequest)
        guard let putHTTP = putResponse as? HTTPURLResponse else { throw SourcesError.unreachable }
        switch putHTTP.statusCode {
        case 200, 201: return
        case 401, 403, 404: throw SourcesError.badToken
        case 409, 422: throw SourcesError.conflict
        default: throw SourcesError.failed(putHTTP.statusCode)
        }
    }

    private static func applyHeaders(to request: inout URLRequest, token: String) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    }
}
